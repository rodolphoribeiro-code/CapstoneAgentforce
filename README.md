# Aria Diner Agent — Agentforce Capstone

Agentforce Service Agent built as the capstone project for the **Salesforce FDE "Ready in Six" (R6) Onboarding Program**. Use case: **Online Hospitality Platform** — a digital platform for restaurant discovery and reservation management.

---

## Table of Contents

1. [What is Agent Script](#1-what-is-agent-script)
2. [The `.agent` file structure](#2-the-agent-file-structure)
3. [Aria's architecture](#3-arias-architecture)
4. [Subagents — detailed guide](#4-subagents--detailed-guide)
5. [OTP authentication flow](#5-otp-authentication-flow)
6. [Session variables](#6-session-variables)
7. [Apex Actions](#7-apex-actions)
8. [Data model](#8-data-model)
9. [How to deploy](#9-how-to-deploy)
10. [How to test](#10-how-to-test)
11. [Lessons learned](#11-lessons-learned)

---

## 1. What is Agent Script

**Agent Script** is Salesforce's scripting language for building AI agents on the **Atlas Reasoning Engine** (Agentforce). It is a declarative, domain-specific language (DSL) — not JavaScript, Python, or any other general-purpose language.

### How Agent Script executes

Every conversation turn runs in **two phases**:

```
User message arrives
        ↓
┌──────────────────────────────────────┐
│  PHASE 1 — Deterministic Resolution  │
│  • Evaluates if/else conditions      │
│  • Executes run @actions.X           │
│  • Sets variables with set           │
│  • Builds the text prompt            │
└──────────────────────────────────────┘
        ↓
┌──────────────────────────────────────┐
│  PHASE 2 — LLM Reasoning             │
│  • Receives the resolved prompt      │
│  • Decides which actions to call     │
│  • Generates the response            │
└──────────────────────────────────────┘
```

**Core rule:** deterministic logic controls *what the agent knows*; the LLM controls *what to do with that knowledge*.

---

## 2. The `.agent` file structure

An `.agent` file has up to 8 top-level blocks in this mandatory order:

```yaml
system:          # Global instructions + welcome/error messages
config:          # Agent metadata (name, type, default user)
variables:       # Session state (mutable and linked)
connection:      # Messaging channel and escalation route
knowledge:       # (optional) Agentforce Data Library
language:        # Default locale
start_agent:     # Required entry point — the central router
subagent:        # One or more specialized subagents
```

Inside each `start_agent` or `subagent`:

```yaml
subagent my_subagent:
    description: "..."          # required — LLM uses this for routing
    before_reasoning:           # runs BEFORE the LLM (deterministic)
        set @variables.x = True
    reasoning:                  # main block
        instructions: ->        # prompt sent to the LLM
            | Text here.
        actions:                # tools available to the LLM
            my_action: @actions.xyz
    after_reasoning:            # runs AFTER the LLM (deterministic)
        set @variables.y = True
    actions:                    # action definitions (Apex/Flow targets)
        xyz:
            target: "apex://MyClass"
```

### Instructions syntax

Two modes are available:

```yaml
# Static mode — fixed text, no logic
instructions: |
    Help the customer. Use {!@actions.search} to look up data.

# Dynamic mode (arrow) — combines logic with text
instructions: ->
    if @variables.authenticated == True:
        | Welcome back, {!@variables.name}!
    else:
        | Please verify your identity first.
```

The `|` prefix starts a line of text that goes into the LLM's prompt. `{!@variables.x}` injects a variable's value into that text.

---

## 3. Aria's architecture

Aria uses the **Hub-and-Spoke + Verification Gate** pattern:

```
                    ┌─────────────────┐
                    │   aria_router   │  ← start_agent (central hub)
                    │  (before_reas.) │
                    └────────┬────────┘
         ┌──────────┬────────┼────────┬───────────┬──────────────┐
         ↓          ↓        ↓        ↓           ↓              ↓
        faq     create_   auth_    post_      escalation   ambiguous/
                reserv.   gate     inter.                  off_topic
                    ↓        ↓
              (no auth)  auth_verify
                              ↓
                       reservation_hub
                         ↙          ↘
               modify_res.      cancel_res.
```

### Why Hub-and-Spoke?

- Each `start_agent` and `subagent` is an **isolated scope** — the LLM focuses on a single responsibility
- Transitions are one-way (`@utils.transition to`) — no return to the previous subagent within the same turn
- The hub's `before_reasoning` intercepts incoming turns and deterministically redirects when a multi-turn flow is in progress

### Router `before_reasoning` gates

```yaml
start_agent aria_router:
    before_reasoning:
        # If OTP was sent, force code verification
        if @variables.otp_sent == True and @variables.customer_authenticated == False:
            transition to @subagent.auth_verify_code
        # If auth started but OTP not yet sent
        if @variables.auth_in_progress == True and @variables.otp_sent == False and @variables.customer_authenticated == False:
            transition to @subagent.authentication_gate
        # If DSAT survey started but not yet collected
        if @variables.dsat_started == True and @variables.dsat_collected == False:
            transition to @subagent.post_interaction
```

This pattern ensures **multi-turn flows** (OTP auth, DSAT survey) continue correctly even if the user sends an unrelated message — the router never loses track of the conversation state.

---

## 4. Subagents — detailed guide

### `aria_router` (start_agent)

**Responsibility:** classify the user's intent and route to the correct subagent.

Key business rule:
- **New reservation** → `create_reservation` directly, **no authentication required**
- **Modify/cancel** → `authentication_gate` if not authenticated, `reservation_hub` if already verified

```yaml
go_to_create: @utils.transition to @subagent.create_reservation
    description: "Customer wants to make a NEW reservation — no authentication required"

go_to_auth: @utils.transition to @subagent.authentication_gate
    description: "Customer wants to MODIFY or CANCEL and has not yet verified identity"
    available when @variables.customer_authenticated == False
```

The `available when` clause removes an action from the LLM's toolset when the condition is not met.

---

### `faq`

**Responsibility:** answer restaurant questions without requiring login.

Uses the `get_restaurant_details` action (Apex `GetRestaurantDetails`) and instructs the LLM to use the exact values returned — without paraphrasing. This prevents **grounding failures** (the LLM hallucinating data not present in the action output).

---

### `authentication_gate` + `auth_verify_code`

See section 5 for the full flow.

---

### `reservation_hub`

**Responsibility:** post-authentication router.

Has a defensive `before_reasoning`:

```yaml
before_reasoning:
    if @variables.customer_authenticated == False:
        transition to @subagent.authentication_gate
```

This ensures that even if the LLM tries to access this subagent directly, unauthenticated users are redirected to verify first.

---

### `create_reservation`

**Responsibility:** create a new booking.

Flow: collects restaurant + date/time + party size → checks availability → creates booking.

The `customerName` is bound directly from the session variable (or from what the user provides as a guest):

```yaml
create_booking: @actions.create_booking
    with restaurantName = ...
    with bookingDateTime = ...
    with partySize = ...
    with customerName = @variables.customer_name
```

---

### `post_interaction`

**Responsibility:** collect a DSAT rating (1–5) and log it to Salesforce.

Uses the **Post-Action Loop pattern** — `run @actions.log_interaction` fires deterministically in Phase 1 once `dsat_score` is populated:

```yaml
instructions: ->
    if @variables.dsat_score != "" and @variables.dsat_collected == False:
        run @actions.log_interaction      # ← deterministic, does not depend on the LLM
            with dsatScore = @variables.dsat_score
            ...
            set @variables.dsat_collected = @outputs.success
```

The `after_reasoning` sets `dsat_started = True` after the first turn, causing the router's `before_reasoning` to redirect subsequent turns back here until the rating is logged.

---

### `escalation`

**Responsibility:** create a Case in Service Cloud and hand off to a human via `@utils.escalate`.

```yaml
connect_to_human: @utils.escalate
    description: "Transfer the customer to a live human agent"
```

`@utils.escalate` is exclusive to `AgentforceServiceAgent` with a `connection messaging:` block configured.

---

## 5. OTP authentication flow

The identity verification flow uses two separate subagents:

```
User wants to modify/cancel
          ↓
[ authentication_gate ]
  • Asks for email
  • Calls send_code (Apex SendVerificationCode)
  • Sets auth_in_progress = True (after_reasoning)
          ↓  (next turn — router redirects via before_reasoning)
[ auth_verify_code ]
  • Asks for the 6-digit code
  • Calls verify_code (Apex VerifyOtpCode)
  • If OK: customer_authenticated = True → goes to reservation_hub
  • If failed: offers retry or escalation
```

### Why two separate subagents?

The platform evaluates `available when` **before** the LLM runs in a turn — so an action gated with `available when @variables.customer_email != ""` was invisible in the same turn the email was collected. By splitting into separate subagents, each one processes in its own turn and the gates work correctly.

### Demo code

For demonstration purposes, the code is fixed: **`123456`** (hardcoded in `VerifyOtpCode`). Replace with a real email delivery call for production.

---

## 6. Session variables

| Variable | Type | Description |
|---|---|---|
| `customer_authenticated` | boolean | True after OTP is verified |
| `customer_email` | string | Email collected during auth |
| `customer_contact_id` | string | Salesforce Contact Id |
| `customer_name` | string | Verified customer's full name |
| `booking_number` | string | Confirmation number of the last booking action |
| `auth_in_progress` | boolean | True while the auth flow is active |
| `otp_sent` | boolean | True after a code was sent by email |
| `otp_code` | string | Code entered by the user |
| `dsat_started` | boolean | True after the survey was prompted |
| `dsat_score` | string | Rating 1–5 provided by the user |
| `dsat_collected` | boolean | True after log_interaction executes |

**Mutable variables** have a default value and the agent can read and write them.  
**Linked variables** (`EndUserId`, `ContactId`, etc.) are read-only, populated from the messaging session context.

---

## 7. Apex Actions

All classes use `@InvocableMethod` and `Database.queryWithBinds` with `SYSTEM_MODE` to avoid sharing rule issues.

| Class | Description |
|---|---|
| `GetRestaurantDetails` | Looks up a restaurant by name (LIKE) or Salesforce Id |
| `CheckBookingAvailability` | Checks availability for a given date, time, and party size |
| `CreateBooking` | Creates a `Booking__c` record with Status = Confirmed |
| `ModifyOrCancelBooking` | Modifies or cancels an existing booking (action = MODIFY or CANCEL) |
| `SendVerificationCode` | Checks if a Contact exists for the email and "sends" the code (fixed `123456` in demo) |
| `VerifyOtpCode` | Validates the code and returns the authenticated Contact |
| `VerifyCustomerIdentity` | Legacy method — verifies email + booking number (not used by Aria) |
| `LogAgentInteraction` | Creates an `Agent_Interaction__c` record with the DSAT score |
| `CreateServiceCase` | Creates a Case with `Origin = 'Agentforce'` for escalations |
| `InitDsatSurvey` | Marks the survey as started (returns `started = true`) |

### Invocable pattern example

```java
public class GetRestaurantDetails {
    public class Request {
        @InvocableVariable(label='Restaurant Name or Id' required=true)
        public String restaurantIdOrName;
    }

    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public String restaurantName;
        // ... other fields
    }

    @InvocableMethod(label='Get Restaurant Details')
    public static List<Result> execute(List<Request> requests) {
        // implementation
    }
}
```

In Agent Script, the reference looks like:

```yaml
actions:
    get_details:
        target: "apex://GetRestaurantDetails"
        inputs:
            restaurantIdOrName: string   # must match the @InvocableVariable name exactly
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

**5 seed restaurants:** La Bella Italia, Sakura Garden, El Rancho, The Brooklyn Grill, Maison Paris

**Test Contact:** `john.smith@example.com` — use this to test the OTP authentication flow.

---

## 9. How to deploy

### Prerequisites

- Salesforce CLI (`sf`) v2.x
- Org with Agentforce enabled
- Einstein Agent User created and licensed

### Step by step

```bash
# 1. Authenticate to the org
sf org login web -a DinerAgent

# 2. Deploy all metadata
sf project deploy start --source-dir force-app

# 3. Assign the permission set to the Einstein Agent User
sf org assign permset --name DinerAgent_Access \
  --on-behalf-of <einstein-agent-username>

# 4. Assign it to your user as well (for testing)
sf org assign permset --name DinerAgent_Access

# 5. Publish the agent
sf agent publish authoring-bundle --json --api-name Aria_Diner_Agent

# 6. Activate
sf agent activate --json --api-name Aria_Diner_Agent
```

### Seed data

```bash
sf apex run --file scripts/apex/seed_data.apex
```

---

## 10. How to test

### Via CLI — authoring bundle (development inner loop)

```bash
# Start a session
sf agent preview start --json --use-live-actions --authoring-bundle Aria_Diner_Agent

# Send a message (replace SESSION_ID)
sf agent preview send --json --authoring-bundle Aria_Diner_Agent \
  --session-id <SESSION_ID> -u "Tell me about La Bella Italia"
```

### Via CLI — published agent

```bash
sf agent preview start --json --api-name Aria_Diner_Agent
sf agent preview send --json --api-name Aria_Diner_Agent \
  --session-id <SESSION_ID> -u "I want to book a table"
```

### Test script

| Flow | Messages |
|---|---|
| FAQ | `"Tell me about La Bella Italia"` |
| New reservation (no auth) | `"I want to book a table"` → `"El Rancho, 2 people, July 25 at 7pm"` |
| OTP auth + modify | `"I want to modify my reservation"` → `"john.smith@example.com"` → `"123456"` → `"Change BKG-0010 to July 28 at 8pm"` |
| Unknown email | `"I want to cancel"` → `"nobody@fake.com"` |
| Wrong code | auth as john.smith → `"000000"` |
| Escalation | `"I need to speak with a human"` |
| DSAT survey | `"I'm done, thanks"` → `"4"` |

### Verify records created

```bash
# Bookings
sf data query --json -q "SELECT Name, Status__c, Customer_Name__c FROM Booking__c ORDER BY CreatedDate DESC LIMIT 5"

# DSAT interactions
sf data query --json -q "SELECT Name, DSAT_Score__c, CreatedDate FROM Agent_Interaction__c ORDER BY CreatedDate DESC LIMIT 5"

# Escalation cases
sf data query --json -q "SELECT CaseNumber, Subject, Origin FROM Case ORDER BY CreatedDate DESC LIMIT 5"
```

---

## 11. Lessons learned

### Agent Script

1. **`run` inside `after_reasoning` is unreliable** — only use `set` and `transition to` in directive blocks. To call Apex deterministically, use `run` inside `instructions: ->`.

2. **`available when` does not re-evaluate between tool calls in the same turn** — if one action sets a variable and another depends on it in the same turn, the second action won't appear in the toolset. Solution: separate subagents, one per turn.

3. **Nested `if` inside `if` causes `error compiling` at `preview start`** even when `validate authoring-bundle` passes — the server has compile-time restrictions the local validator doesn't catch.

4. **`available when @variables.X != ""`** when `X` is empty can hide a critical entry-point action even when it is the only logical next step. For actions that must always be available, remove the gate and control behavior through instructions instead.

5. **Multi-turn flows require state flags + `before_reasoning` in the router** — every turn starts at `start_agent`. The one-way transition from the previous turn does not persist control. Solution: a boolean flag variable + a gate in `before_reasoning`.

### Architecture

6. **Separate flows by authentication requirement** — new reservation (guest) vs. modify/cancel (requires identity). This simplifies routing and reflects real-world business rules.

7. **Use the Post-Action Loop for mandatory end-of-session actions** — the LLM tends to generate a goodbye message without calling optional actions. Place `run @actions.X` deterministically at the top of `instructions: ->` gated on a state variable.

---

## Repository structure

```
CapstoneAgentforce/
├── Aria_Diner_Agent-AgentSpec.md          # Agent design specification
├── force-app/main/default/
│   ├── aiAuthoringBundles/
│   │   └── Aria_Diner_Agent/
│   │       └── Aria_Diner_Agent.agent     # Main Agent Script file
│   ├── classes/                           # Apex Actions
│   │   ├── GetRestaurantDetails.cls
│   │   ├── CheckBookingAvailability.cls
│   │   ├── CreateBooking.cls
│   │   ├── ModifyOrCancelBooking.cls
│   │   ├── SendVerificationCode.cls       # OTP — sends the code
│   │   ├── VerifyOtpCode.cls              # OTP — validates the code
│   │   ├── LogAgentInteraction.cls        # DSAT logging
│   │   ├── CreateServiceCase.cls          # Escalation
│   │   └── InitDsatSurvey.cls             # Survey started flag
│   ├── objects/                           # Custom objects
│   │   ├── Restaurant__c/
│   │   ├── Booking__c/
│   │   └── Agent_Interaction__c/
│   └── permissionsets/
│       └── DinerAgent_Access.permissionset-meta.xml
├── scripts/apex/
│   └── seed_data.apex                     # Test data
└── sfdx-project.json
```

---

*Built as the capstone project for the Salesforce FDE "Ready in Six" Onboarding Program, 2026.*
