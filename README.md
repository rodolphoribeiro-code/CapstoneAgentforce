# Aria Diner Agent — Capstone Agentforce

Agentforce Service Agent desenvolvido como capstone do programa **FDE "Ready in Six" (R6) Onboarding** da Salesforce. Use case: **Online Hospitality Platform** — plataforma digital de gestão de restaurantes e reservas.

---

## Sumário

1. [O que é Agent Script](#1-o-que-é-agent-script)
2. [Estrutura do arquivo `.agent`](#2-estrutura-do-arquivo-agent)
3. [Arquitetura do Aria](#3-arquitetura-do-aria)
4. [Subagents — guia detalhado](#4-subagents--guia-detalhado)
5. [Fluxo de autenticação OTP](#5-fluxo-de-autenticação-otp)
6. [Variáveis de estado](#6-variáveis-de-estado)
7. [Apex Actions](#7-apex-actions)
8. [Data model](#8-data-model)
9. [Como deployar](#9-como-deployar)
10. [Como testar](#10-como-testar)
11. [Lições aprendidas](#11-lições-aprendidas)

---

## 1. O que é Agent Script

**Agent Script** é a linguagem de scripting da Salesforce para criar agentes de IA na plataforma **Atlas Reasoning Engine** (Agentforce). É uma linguagem declarativa e de domínio específico (DSL) — não é JavaScript, Python nem AppleScript.

### Como o Agent Script executa

A execução acontece em **duas fases** por turno de conversa:

```
Turno do usuário
      ↓
┌─────────────────────────────────────┐
│  FASE 1 — Resolução Determinística  │
│  • Avalia if/else                   │
│  • Executa run @actions.X           │
│  • Seta variáveis com set           │
│  • Monta o prompt textual           │
└─────────────────────────────────────┘
      ↓
┌─────────────────────────────────────┐
│  FASE 2 — Raciocínio do LLM         │
│  • Recebe o prompt montado          │
│  • Decide quais actions chamar      │
│  • Gera a resposta ao usuário       │
└─────────────────────────────────────┘
```

**Regra fundamental:** lógica determinística controla *o que o agente sabe*; o LLM controla *o que fazer com esse conhecimento*.

---

## 2. Estrutura do arquivo `.agent`

Um arquivo `.agent` tem 8 blocos no topo, nesta ordem obrigatória:

```yaml
system:          # Instruções globais + mensagens de boas-vindas/erro
config:          # Metadados do agente (nome, tipo, usuário padrão)
variables:       # Estado da sessão (mutable e linked)
connection:      # Canal de mensagens e rota de escalation
knowledge:       # (opcional) Base de conhecimento ADL
language:        # Locale padrão
start_agent:     # Ponto de entrada obrigatório — o roteador central
subagent:        # Um ou mais subagents especializados
```

Dentro de cada `start_agent` ou `subagent`:

```yaml
subagent meu_subagent:
    description: "..."          # obrigatório — o LLM usa para roteamento
    before_reasoning:           # roda ANTES do LLM (determinístico)
        set @variables.x = True
    reasoning:                  # bloco principal
        instructions: ->        # prompt para o LLM
            | Texto aqui.
        actions:                # ferramentas disponíveis ao LLM
            minha_action: @actions.xyz
    after_reasoning:            # roda DEPOIS do LLM (determinístico)
        set @variables.y = True
    actions:                    # definições das actions (target Apex/Flow)
        xyz:
            target: "apex://MinhaClasse"
```

### Sintaxe das instructions

Há dois modos:

```yaml
# Modo estático — texto fixo, sem lógica
instructions: |
    Ajude o cliente. Use a action {!@actions.buscar}.

# Modo dinâmico (arrow) — combina lógica com texto
instructions: ->
    if @variables.autenticado == True:
        | Bem-vindo, {!@variables.nome}!
    else:
        | Por favor, verifique sua identidade primeiro.
```

O prefixo `|` inicia uma linha de texto que vai para o prompt do LLM. O `{!@variables.x}` injeta o valor de uma variável no texto.

---

## 3. Arquitetura do Aria

O Aria usa o padrão **Hub-and-Spoke + Verification Gate**:

```
                    ┌─────────────────┐
                    │   aria_router   │  ← start_agent (hub central)
                    │  (before_reason)│
                    └────────┬────────┘
           ┌─────────┬───────┼────────┬──────────┬────────────┐
           ↓         ↓       ↓        ↓          ↓            ↓
         faq    create_  auth_    post_      escalation  ambiguous/
                reserv.  gate     inter.                 off_topic
                    ↓       ↓
              (sem auth) auth_verify
                              ↓
                       reservation_hub
                        ↙         ↘
               modify_res.    cancel_res.
```

### Por que Hub-and-Spoke?

- Cada `start_agent` e `subagent` é um **escopo isolado** — o LLM foca em uma única responsabilidade
- Transições são one-way (`@utils.transition to`) — sem retorno ao subagent anterior no mesmo turno
- O `before_reasoning` do hub intercepta turnos e redireciona deterministicamente quando um fluxo multi-turno está em progresso

### Gates no `before_reasoning` do router

```yaml
start_agent aria_router:
    before_reasoning:
        # Se OTP foi enviado, força verificação do código
        if @variables.otp_sent == True and @variables.customer_authenticated == False:
            transition to @subagent.auth_verify_code
        # Se auth iniciou mas OTP ainda não foi enviado
        if @variables.auth_in_progress == True and @variables.otp_sent == False and @variables.customer_authenticated == False:
            transition to @subagent.authentication_gate
        # Se DSAT foi iniciado mas não coletado
        if @variables.dsat_started == True and @variables.dsat_collected == False:
            transition to @subagent.post_interaction
```

Este padrão garante que **fluxos multi-turno** (auth OTP, DSAT) continuem corretamente mesmo que o usuário envie uma mensagem qualquer — o roteador nunca perde o fio da conversa.

---

## 4. Subagents — guia detalhado

### `aria_router` (start_agent)

**Responsabilidade:** classificar o intent do usuário e rotear para o subagent correto.

Regra de negócio importante:
- **Nova reserva** → `create_reservation` direto, **sem autenticação**
- **Modificar/cancelar** → `authentication_gate` se não autenticado, `reservation_hub` se já autenticado

```yaml
go_to_create: @utils.transition to @subagent.create_reservation
    description: "Customer wants to make a NEW reservation — no authentication required"

go_to_auth: @utils.transition to @subagent.authentication_gate
    description: "Customer wants to MODIFY or CANCEL an existing reservation and has not yet verified identity"
    available when @variables.customer_authenticated == False
```

O `available when` remove a action do toolset do LLM quando a condição não é atendida.

---

### `faq`

**Responsabilidade:** responder perguntas sobre restaurantes sem exigir login.

Usa a action `get_restaurant_details` (Apex `GetRestaurantDetails`) e instrui o LLM a usar os valores exatos retornados — sem parafrasear. Isso evita **grounding failures** (quando o LLM inventa dados não presentes no output da action).

---

### `authentication_gate` + `auth_verify_code`

Ver seção 5 para o fluxo completo.

---

### `reservation_hub`

**Responsabilidade:** roteador pós-autenticação.

Tem um `before_reasoning` defensivo:

```yaml
before_reasoning:
    if @variables.customer_authenticated == False:
        transition to @subagent.authentication_gate
```

Isso garante que mesmo que o LLM tente acessar este subagent diretamente, o usuário não autenticado seja redirecionado.

---

### `create_reservation`

**Responsabilidade:** criar nova reserva.

Fluxo: coleta restaurante + data/hora + tamanho do grupo → verifica disponibilidade → cria booking.

O `customerName` é preenchido diretamente da variável `@variables.customer_name` (ou do que o usuário informa se não autenticado):

```yaml
create_booking: @actions.create_booking
    with restaurantName = ...
    with bookingDateTime = ...
    with partySize = ...
    with customerName = @variables.customer_name
```

---

### `post_interaction`

**Responsabilidade:** coletar rating DSAT (1–5) e registrar no Salesforce.

Usa o **Post-Action Loop pattern** — o `run @actions.log_interaction` dispara deterministicamente na Fase 1 quando `dsat_score` está preenchido:

```yaml
instructions: ->
    if @variables.dsat_score != "" and @variables.dsat_collected == False:
        run @actions.log_interaction      # ← determinístico, não depende do LLM
            with dsatScore = @variables.dsat_score
            ...
            set @variables.dsat_collected = @outputs.success
```

O `after_reasoning` seta `dsat_started = True` após o primeiro turno, o que faz o `before_reasoning` do router redirecionar turnos subsequentes de volta aqui.

---

### `escalation`

**Responsabilidade:** criar um Case no Service Cloud e transferir para humano via `@utils.escalate`.

```yaml
connect_to_human: @utils.escalate
    description: "Transfer the customer to a live human agent"
```

`@utils.escalate` é exclusivo de `AgentforceServiceAgent` com `connection messaging:` configurado.

---

## 5. Fluxo de autenticação OTP

O fluxo de verificação de identidade usa dois subagents separados:

```
Usuário quer modify/cancel
        ↓
[ authentication_gate ]
  • Pede email
  • Chama send_code (Apex SendVerificationCode)
  • Seta auth_in_progress = True (after_reasoning)
        ↓ (próximo turno — router redireciona via before_reasoning)
[ auth_verify_code ]
  • Pede o código de 6 dígitos
  • Chama verify_code (Apex VerifyOtpCode)
  • Se OK: customer_authenticated = True → vai para reservation_hub
  • Se falhou: oferece nova tentativa ou escalation
```

### Por que dois subagents?

O platform avalia `available when` **antes** do LLM rodar no turno — então uma action com `available when @variables.customer_email != ""` ficava invisível no mesmo turno em que o email era coletado. Separando em subagents distintos, cada um processa em seu próprio turno e os gates funcionam corretamente.

### Código de demonstração

Para demo, o código é fixo: **`123456`** (hardcoded no Apex `VerifyOtpCode`). Em produção, substituir pela chamada real de envio de email.

---

## 6. Variáveis de estado

| Variável | Tipo | Descrição |
|---|---|---|
| `customer_authenticated` | boolean | True após OTP verificado |
| `customer_email` | string | Email coletado na auth |
| `customer_contact_id` | string | Id do Contact Salesforce |
| `customer_name` | string | Nome do cliente verificado |
| `booking_number` | string | Número da última reserva criada/modificada |
| `auth_in_progress` | boolean | True enquanto fluxo de auth está ativo |
| `otp_sent` | boolean | True após código enviado por email |
| `otp_code` | string | Código digitado pelo usuário |
| `dsat_started` | boolean | True após survey iniciado |
| `dsat_score` | string | Rating 1–5 do usuário |
| `dsat_collected` | boolean | True após log_interaction executar |

**Mutable variables** têm valor padrão e o agente pode ler e escrever.
**Linked variables** (`EndUserId`, `ContactId`, etc.) são somente leitura, populadas pela sessão de messaging.

---

## 7. Apex Actions

Todas as classes usam `@InvocableMethod` e `Database.queryWithBinds` com `SYSTEM_MODE` para evitar problemas de sharing.

| Classe | Descrição |
|---|---|
| `GetRestaurantDetails` | Busca restaurante por nome (LIKE) ou Id |
| `CheckBookingAvailability` | Verifica disponibilidade de horário |
| `CreateBooking` | Cria `Booking__c` com status Confirmed |
| `ModifyOrCancelBooking` | Modifica ou cancela booking existente (action = MODIFY ou CANCEL) |
| `SendVerificationCode` | Verifica se Contact existe pelo email e "envia" o código (fixo 123456 em demo) |
| `VerifyOtpCode` | Valida o código e retorna o Contact autenticado |
| `VerifyCustomerIdentity` | Método legado — verifica email + booking number (não usado no Aria) |
| `LogAgentInteraction` | Cria `Agent_Interaction__c` com DSAT score |
| `CreateServiceCase` | Cria Case com Origin='Agentforce' para escalations |
| `InitDsatSurvey` | Marca a survey como iniciada (retorna `started = true`) |

### Exemplo de padrão Invocable

```java
public class GetRestaurantDetails {
    public class Request {
        @InvocableVariable(label='Restaurant Name or Id' required=true)
        public String restaurantIdOrName;
    }

    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String restaurantName;
        // ... outros campos
    }

    @InvocableMethod(label='Get Restaurant Details')
    public static List<Result> execute(List<Request> requests) {
        // implementação
    }
}
```

No Agent Script, a referência é:

```yaml
actions:
    get_details:
        target: "apex://GetRestaurantDetails"
        inputs:
            restaurantIdOrName: string   # deve bater exatamente com o nome do @InvocableVariable
                is_required: True
        outputs:
            found: boolean
            restaurantName: string
```

---

## 8. Data model

```
Restaurant__c
├── Name
├── Cuisine_Type__c
├── Location__c
├── Opening_Hours__c
├── Capacity__c
├── Dietary_Options__c
└── Phone__c

Booking__c
├── Name (AutoNumber: BKG-XXXX)
├── Restaurant__c (Lookup)
├── Booking_Date__c
├── Party_Size__c
├── Status__c (Confirmed / Cancelled / Modified)
├── Customer_Name__c
├── Customer_Email__c
├── Booking_Value__c
├── Is_VIP__c
└── Special_Requests__c

Agent_Interaction__c
├── Name (AutoNumber: INT-XXXX)
├── Contact__c (Lookup)
├── Booking__c (Lookup)
├── DSAT_Score__c
├── Interaction_Type__c
└── Notes__c
```

**5 restaurantes de seed:** La Bella Italia, Sakura Garden, El Rancho, The Brooklyn Grill, Maison Paris

**Contact de teste:** `john.smith@example.com` — use para testar o fluxo de autenticação.

---

## 9. Como deployar

### Pré-requisitos

- Salesforce CLI (`sf`) v2.x
- Org com Agentforce habilitado
- Einstein Agent User criado e licenciado

### Passo a passo

```bash
# 1. Autenticar no org
sf org login web -a DinerAgent

# 2. Deploy de toda a metadata
sf project deploy start --source-dir force-app

# 3. Atribuir a permission set ao Einstein Agent User
sf org assign permset --name DinerAgent_Access \
  --on-behalf-of <einstein-agent-username>

# 4. Atribuir também ao seu usuário (para testes)
sf org assign permset --name DinerAgent_Access

# 5. Publicar o agente
sf agent publish authoring-bundle --json --api-name Aria_Diner_Agent

# 6. Ativar
sf agent activate --json --api-name Aria_Diner_Agent
```

### Seed data

```bash
sf apex run --file scripts/apex/seed_data.apex
```

---

## 10. Como testar

### Via CLI (authoring bundle — desenvolvimento)

```bash
# Iniciar sessão
sf agent preview start --json --use-live-actions --authoring-bundle Aria_Diner_Agent

# Enviar mensagem (substituir SESSION_ID)
sf agent preview send --json --authoring-bundle Aria_Diner_Agent \
  --session-id <SESSION_ID> -u "Tell me about La Bella Italia"
```

### Via CLI (agente publicado)

```bash
sf agent preview start --json --api-name Aria_Diner_Agent
sf agent preview send --json --api-name Aria_Diner_Agent \
  --session-id <SESSION_ID> -u "I want to book a table"
```

### Roteiro de testes

| Fluxo | Mensagens |
|---|---|
| FAQ | `"Tell me about La Bella Italia"` |
| Nova reserva | `"I want to book a table"` → `"El Rancho, 2 people, July 25 at 7pm"` |
| Auth OTP | `"I want to modify my reservation"` → `"john.smith@example.com"` → `"123456"` |
| Email inválido | `"I want to cancel"` → `"nobody@fake.com"` |
| Código errado | auth com john.smith → `"000000"` |
| Escalation | `"I need to speak with a human"` |
| DSAT | `"I'm done, thanks"` → `"4"` |

### Verificar registros criados

```bash
# Bookings
sf data query --json -q "SELECT Name, Status__c, Customer_Name__c FROM Booking__c ORDER BY CreatedDate DESC LIMIT 5"

# Interações DSAT
sf data query --json -q "SELECT Name, DSAT_Score__c, CreatedDate FROM Agent_Interaction__c ORDER BY CreatedDate DESC LIMIT 5"

# Cases de escalation
sf data query --json -q "SELECT CaseNumber, Subject, Origin FROM Case ORDER BY CreatedDate DESC LIMIT 5"
```

---

## 11. Lições aprendidas

### Sobre Agent Script

1. **`run` em `after_reasoning` é instável** — use apenas `set` e `transition to` em directive blocks. Para chamar Apex deterministicamente, use `run` dentro de `instructions: ->`.

2. **`available when` não reavalia entre tool calls no mesmo turno** — se uma action seta uma variável e outra action depende dela no mesmo turno, a segunda não vai aparecer. Solução: subagents separados, um por turno.

3. **Nested `if` dentro de `if` causa `error compiling`** no `preview start` mesmo passando no `validate authoring-bundle` — o servidor tem restrições que o validador local não detecta.

4. **`available when @variables.X != ""`** quando `X` está vazio pode esconder a action mesmo sendo a única opção do subagent. Para actions críticas de entrada, remova o gate e controle via instructions.

5. **Fluxos multi-turno precisam de flags de estado + `before_reasoning` no router** — cada turno começa no `start_agent`. A transição one-way do turno anterior não persiste o controle. Solução: variável flag + gate no `before_reasoning`.

### Sobre arquitetura

6. **Separar fluxos por responsabilidade de autenticação** — nova reserva (guest) vs. modify/cancel (requer identity). Isso simplifica o roteamento e é mais realista para o negócio.

7. **Post-Action Loop para ações obrigatórias no final da sessão** — o LLM tende a dar goodbye sem chamar actions opcionais. Coloque o `run @actions.X` determinístico no topo do `instructions: ->` com guard na variável de estado.

---

## Estrutura do repositório

```
CapstoneAgentforce/
├── Aria_Diner_Agent-AgentSpec.md          # Especificação de design do agente
├── force-app/main/default/
│   ├── aiAuthoringBundles/
│   │   └── Aria_Diner_Agent/
│   │       └── Aria_Diner_Agent.agent     # Agent Script principal
│   ├── classes/                           # Apex Actions
│   │   ├── GetRestaurantDetails.cls
│   │   ├── CheckBookingAvailability.cls
│   │   ├── CreateBooking.cls
│   │   ├── ModifyOrCancelBooking.cls
│   │   ├── SendVerificationCode.cls       # OTP — envia código
│   │   ├── VerifyOtpCode.cls              # OTP — valida código
│   │   ├── LogAgentInteraction.cls        # DSAT logging
│   │   ├── CreateServiceCase.cls          # Escalation
│   │   └── InitDsatSurvey.cls             # Flag survey iniciada
│   ├── objects/                           # Custom objects
│   │   ├── Restaurant__c/
│   │   ├── Booking__c/
│   │   └── Agent_Interaction__c/
│   └── permissionsets/
│       └── DinerAgent_Access.permissionset-meta.xml
├── scripts/apex/
│   └── seed_data.apex                     # Dados de teste
└── sfdx-project.json
```

---

*Desenvolvido como capstone do programa FDE "Ready in Six" — Salesforce, 2026.*
