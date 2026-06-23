# Agent Spec: Aria_Diner_Agent

## Purpose & Scope

Aria is a customer-facing service agent embedded in The Diner website. She helps guests search for restaurants, answer policy/FAQ questions without authentication, and handle reservation creation, modification, and cancellation (all requiring identity verification). After completing any task, Aria collects a DSAT rating and logs the interaction in Salesforce.

## Behavioral Intent

- Aria introduces herself as "Aria" and discloses she is AI-powered.
- No reservation action is accessible until identity is verified via email lookup against a Salesforce Contact.
- Restaurant browsing and FAQ questions are always available without auth.
- Every session ends with a mandatory DSAT (1–5 star) rating, stored in `Agent_Interaction__c`.
- Escalation creates a Service Cloud Case and transfers to a human via `@utils.escalate`.
- All Apex actions run in `SYSTEM_MODE` to avoid FLS issues with the Einstein Agent User.
- Prompt injection guard is in `system.instructions`.

## Subagent Map

```mermaid
%%{init: {'theme':'neutral'}}%%
graph TD
    R([start_agent<br/>aria_router])

    R -->|restaurant/FAQ intent| FAQ[faq<br/>Subagent]
    R -->|reservation intent| AUTH[authentication_gate<br/>Subagent]
    R -->|human escalation| ESC[escalation<br/>Subagent]
    R -->|user is done| POST[post_interaction<br/>Subagent]
    R -->|unclear| AMB[ambiguous_question<br/>Subagent]
    R -->|out of scope| OT[off_topic<br/>Subagent]

    FAQ -->|back to hub| R
    FAQ -->|get_restaurant_details| RD[GetRestaurantDetails<br/>Apex]

    AUTH -->|verify_customer action| VC[VerifyCustomerIdentity<br/>Apex]
    AUTH -->|auth success| RH[reservation_hub<br/>Subagent]
    AUTH -->|auth failed| R

    RH -->|create intent| CR[create_reservation<br/>Subagent]
    RH -->|modify intent| MR[modify_reservation<br/>Subagent]
    RH -->|cancel intent| CNR[cancel_reservation<br/>Subagent]

    CR --> CA[CheckBookingAvailability<br/>Apex]
    CR --> CB[CreateBooking<br/>Apex]
    CR --> R

    MR --> MOC[ModifyOrCancelBooking MODIFY<br/>Apex]
    MR --> R

    CNR --> MOC2[ModifyOrCancelBooking CANCEL<br/>Apex]
    CNR --> R
    CNR -->|fee applies| ESC

    POST --> LOG[LogAgentInteraction<br/>Apex]

    ESC --> CC[CreateServiceCase<br/>Apex]
    ESC --> HUMAN[@utils.escalate]

    AMB --> R
    OT --> R
```

## Variables

- `customer_authenticated` (mutable boolean = False) — True after VerifyCustomerIdentity finds a Contact. Gates all reservation transitions in `reservation_hub`.
- `customer_email` (mutable string = "") — Email collected by authentication_gate. Passed to VerifyCustomerIdentity.
- `customer_booking_number` (mutable string = "") — Booking number (BKG-XXXX) collected by authentication_gate. Used with email to verify identity.
- `customer_contact_id` (mutable string = "") — Salesforce Contact Id returned by VerifyCustomerIdentity. Passed to LogAgentInteraction and CreateServiceCase.
- `customer_name` (mutable string = "") — Contact name returned by VerifyCustomerIdentity. Used in greeting.
- `booking_number` (mutable string = "") — BKG-XXXX returned by CreateBooking or existing booking confirmed by modify/cancel. Passed to LogAgentInteraction.
- `restaurant_id` (mutable string = "") — Restaurant Salesforce Id returned by GetRestaurantDetails or CheckBookingAvailability. Used to gate CreateBooking.
- `escalation_reason` (mutable string = "") — Reason text set before transitioning to escalation.

## Actions & Backing Logic

---

### get_restaurant_details (faq subagent)

- **Target:** `apex://GetRestaurantDetails`
- **Backing Status:** EXISTS

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| restaurantIdOrName | string | Yes | LLM slot-fill (`...`) |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| found | boolean | No | Internal routing flag |
| restaurantId | string | No | Stored to `restaurant_id` variable |
| restaurantName | string | Yes | Displayed in response |
| cuisineType | string | Yes | Displayed in response |
| location | string | Yes | Displayed in response |
| openingHours | string | Yes | Displayed in response |
| capacity | integer | No | Internal |
| dietaryOptions | string | Yes | Displayed in response |
| phone | string | Yes | Displayed in response |
| summary | string | Yes | Displayed as main response |

---

### verify_customer (authentication_gate subagent)

- **Target:** `apex://VerifyCustomerIdentity`
- **Backing Status:** NEEDS IMPLEMENTATION

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| email | string | Yes | `@variables.customer_email` |
| bookingNumber | string | Yes | `@variables.customer_booking_number` |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| verified | boolean | No | Gates transition to reservation_hub |
| contactId | string | No | Stored to `customer_contact_id` |
| contactName | string | Yes | Used in welcome back greeting |
| errorMessage | string | Yes | Shown if not found |

#### Implementation Requirements

Query `Contact WHERE Email = :email LIMIT 1` in `SYSTEM_MODE`. If found, verify the provided `bookingNumber` belongs to that contact by querying `Booking__c WHERE Name = :bookingNumber AND Customer_Email__c = :email LIMIT 1`. If both match, return `verified=true`, `contactId`, `contactName`. If either check fails, return `verified=false`, `errorMessage` explaining what didn't match.

---

### check_availability (create_reservation subagent)

- **Target:** `apex://CheckBookingAvailability`
- **Backing Status:** EXISTS

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| restaurantId | string | Yes | `@variables.restaurant_id` |
| requestedDateTime | datetime | Yes | LLM slot-fill |
| partySize | integer | Yes | LLM slot-fill |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| isAvailable | boolean | No | Gates create_booking action |
| message | string | Yes | Availability message shown to user |
| restaurantName | string | Yes | Confirm which restaurant |
| availableSlots | string | Yes | Shown if not available |

---

### create_booking (create_reservation subagent)

- **Target:** `apex://CreateBooking`
- **Backing Status:** EXISTS

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| restaurantName | string | Yes | LLM slot-fill |
| bookingDateTime | datetime | Yes | LLM slot-fill |
| partySize | integer | Yes | LLM slot-fill |
| customerName | string | Yes | `@variables.customer_name` |
| specialRequests | string | No | LLM slot-fill |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| success | boolean | No | Gates confirmation message |
| message | string | Yes | Success or error message |
| bookingNumber | string | Yes | BKG-XXXX stored to `booking_number` |

> Note: `require_user_confirmation: True` on this action forces platform-level confirm before creating.

---

### modify_booking (modify_reservation subagent)

- **Target:** `apex://ModifyOrCancelBooking`
- **Backing Status:** EXISTS

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| bookingId | string | Yes | LLM slot-fill (BKG-XXXX or Salesforce Id) |
| action | string | Yes | Fixed: `"MODIFY"` |
| newDateTime | datetime | No | LLM slot-fill |
| newPartySize | integer | No | LLM slot-fill |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| success | boolean | No | Internal |
| message | string | Yes | Result message |
| bookingNumber | string | Yes | Stored to `booking_number` |
| newStatus | string | Yes | New booking status |

> Note: `require_user_confirmation: True` on this action.

---

### cancel_booking (cancel_reservation subagent)

- **Target:** `apex://ModifyOrCancelBooking`
- **Backing Status:** EXISTS

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| bookingId | string | Yes | LLM slot-fill |
| action | string | Yes | Fixed: `"CANCEL"` |
| newDateTime | datetime | No | Not used for cancel |
| newPartySize | integer | No | Not used for cancel |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| success | boolean | No | Gates confirmation |
| message | string | Yes | Cancellation result |
| bookingNumber | string | Yes | Stored to `booking_number` |
| newStatus | string | Yes | Should be "Cancelled" |

> Note: `require_user_confirmation: True` on this action.

---

### log_interaction (post_interaction subagent)

- **Target:** `apex://LogAgentInteraction`
- **Backing Status:** NEEDS IMPLEMENTATION

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| contactId | string | No | `@variables.customer_contact_id` |
| bookingNumber | string | No | `@variables.booking_number` |
| dsatScore | string | Yes | LLM slot-fill (user's 1–5 rating) |
| interactionType | string | Yes | `@variables.escalation_reason` or "GENERAL" |
| notes | string | No | LLM slot-fill (optional comment) |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| success | boolean | No | Internal |
| interactionId | string | No | Internal |

#### Implementation Requirements

Create `Agent_Interaction__c` record. Look up Booking__c by Name (bookingNumber) if provided. Parse `dsatScore` string to Integer. Fields: `Contact__c`, `Booking__c`, `DSAT_Score__c`, `Interaction_Type__c`, `Notes__c`.

---

### create_service_case (escalation subagent)

- **Target:** `apex://CreateServiceCase`
- **Backing Status:** NEEDS IMPLEMENTATION

#### Inputs

| Name | Type | Required | Source |
|------|------|----------|--------|
| contactId | string | No | `@variables.customer_contact_id` |
| reason | string | Yes | `@variables.escalation_reason` |
| description | string | Yes | LLM slot-fill (summary of issue) |

#### Outputs

| Name | Type | Visible to User? | Notes |
|------|------|-----------------|-------|
| success | boolean | No | Internal |
| caseNumber | string | Yes | Shown to user before escalation |
| errorMessage | string | Yes | Shown if case creation fails |

#### Implementation Requirements

Create `Case` record with `ContactId`, `Reason`, `Description`, `Origin = 'Agentforce'`, `Status = 'New'`. Return `CaseNumber`.

---

## Gating Logic

- `verify_customer` — `available when @variables.customer_email != "" and @variables.customer_booking_number != ""`
  Prevents calling VerifyCustomerIdentity before the user has provided both email and booking number.

- `go_to_reservation_hub` transition in `authentication_gate` — `available when @variables.customer_authenticated == True`
  Prevents routing to reservation actions if identity check failed.

- All transitions in `reservation_hub` (create/modify/cancel) — `available when @variables.customer_authenticated == True`
  Defense-in-depth: even if auth gate is bypassed, reservation_hub won't route unauthenticated users.

- `check_availability` — `available when @variables.restaurant_id != ""`
  Ensures a restaurant has been selected before checking availability. GetRestaurantDetails must run first.

- `create_booking` — `available when @variables.restaurant_id != ""`
  Prevents CreateBooking from running before a restaurant is identified.

- `log_interaction` in `post_interaction` — `available when @variables.dsat_collected != "True"` (via variable or after_reasoning)
  Prevents double-logging.

## Architecture Pattern

**Hub-and-Spoke with Verification Gate.** `aria_router` is the hub and the sole `start_agent`. Domain subagents are spokes. `authentication_gate` acts as a one-time verification gate — once `customer_authenticated = True`, transitions back through `aria_router` no longer re-trigger authentication. `reservation_hub` is a secondary post-auth routing hub for the three reservation operations.

After completing any domain task, subagents transition back to `aria_router`. The router handles "is there anything else?" naturally and routes to `post_interaction` when the user is done.

## New Metadata Required

### Agent_Interaction__c (custom object — NEEDS CREATION)

| Field API Name | Type | Description |
|---------------|------|-------------|
| Contact__c | Lookup(Contact) | Authenticated customer |
| Booking__c | Lookup(Booking__c) | Related booking (optional) |
| DSAT_Score__c | Number(1,0) | Rating 1–5 |
| Interaction_Type__c | Text(50) | BOOKING_CREATED / BOOKING_MODIFIED / BOOKING_CANCELLED / FAQ / ESCALATION |
| Notes__c | Long Text Area | Optional additional notes |

## Agent Configuration

- **developer_name:** `Aria_Diner_Agent`
- **agent_label:** `Aria - Diner Support Agent`
- **agent_type:** `AgentforceServiceAgent` — customer-facing, embedded on website
- **default_agent_user:** `agentforce_service_agent2.5it0yxbpwhk3.vdrdxv9neuca@orgfarm.salesforce.com.devorg` (existing Einstein Agent User from DinerAgent org)
- **permissions:** `DinerAgent_Access` permission set must be updated to include `Agent_Interaction__c` object access and new Apex classes.
