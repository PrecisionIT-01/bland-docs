# Scheduling Node Architecture

This document describes the Scheduling Node implementation for Bland's pathway agent system.

## Overview

The Scheduling Node is a specialized pathway node that:

1. Fetches available appointment slots from external scheduling APIs
2. Presents slot options to the caller using natural language
3. Validates that the user confirms a time from the available slots
4. Optionally locks the slot via a reservation API

### v1 Mode Override

Scheduling nodes always use v1 (plain text) mode regardless of the agent's USE_TOOL setting. This is set in the constructor: `this.USE_TOOL = false`. The SchedulingPrompt requires plain text output with `<function_name=fetch_more_slots>` syntax, and `handleAfterWebhookDialogue` only sends audio in v1 mode. Without this, p2p/IVR calls (which force v2 via `containsIVRNode`) would use the generic `toolDialoguePrompt` — which has no scheduling content. The `processStream.ts` checks for `curr_node?.USE_TOOL` alongside `this.agent.USE_TOOL` to route scheduling nodes through v1 parsing even when the agent is v2.

## Key Files

| File | Purpose |
|------|---------|
| `schedulingNode.ts` | Node class definition, inherits from ConversationNode |
| `processStream.ts:3485-3560` | `handleSchedulingFunctionCall()` - Executes slot fetching |
| `processStream.ts:3782-3890` | `handleAfterWebhookDialogue()` - Generates dialogue after webhook |
| `mediaStream.ts:6993-7408` | Webhook execution and failure tracking |
| `pathwayAgent.ts:1542-1579` | beforeRun action handling during route transitions |
| `schedulingToolUtils.ts` | Utility functions for processing scheduling data |
| `types/scheduling.ts` | TypeScript interfaces |

## Execution Flow

### 1. Node Entry (pathwayAgent.ts:1542-1579)

When the pathway agent routes to a scheduling node:

```
Route Decision → Detect beforeRun actions → Extract Variables → Fetch Slots
```

Key code path:

- Check if node has `fetch_scheduling_slots` action with `beforeRun: true`
- Call `handleNodeActions()` for `extractInfo` action (extracts `start_datetime`)
- Call `handleSchedulingFunctionCall({ skipDialogue: true })` to fetch available slots without generating dialogue
- Set `shouldRegenerateDialogueStream = true` to generate fresh dialogue with the fetched slots

The `skipDialogue: true` flag is critical — without it, `handleSchedulingFunctionCall` generates dialogue, the responses get injected as user messages via `addUserMessage`, and then `shouldRegenerateDialogueStream` triggers a second generation, resulting in triple dialogue.

### 2. Slot Fetching (processStream.ts:3485-3560)

`handleSchedulingFunctionCall()`:

1. **Guard**: Check if `scheduling_api_failed` is true → block further API calls
2. **Abort**: Cancel any previous in-flight fetch requests
3. **Extract**: Re-extract scheduling variables from conversation
4. **Process**: Build request from `scheduling_tool` configuration
5. **Fetch**: Call `fetchSingleDynamicData()` to execute webhook
6. **Handle Response**: Call `handleAfterWebhookDialogue()` on success

### 3. Webhook Execution (mediaStream.ts)

**Success Path** (lines 7165-7193):

- Reset `schedulingWebhookFailures` to 0
- Add slots to `slotFetchHistory` (sliding window: last 2 fetches)
- Update `variables["available_slots"]`
- Sync to agent via `agent.insertVariables()`

**Failure Path** (lines 6993-7036, 7368-7408):

- Increment `schedulingWebhookFailures++`
- If failures >= 2:
  - Set `variables["scheduling_api_failed"] = true`
  - Store error message in chat history
  - Set `available_slots = []` to prevent recursion

### 4. Dialogue Generation (processStream.ts:3782-3890)

`handleAfterWebhookDialogue()`:

1. Check if slots already fetched via beforeRun
2. If not, execute beforeRun actions again
3. Get dialogue generator from node
4. Stream sentences through SmartTextSplitter
5. Queue each sentence to audio via `queueAudioStream()`

## Data Structures

### SchedulingToolData

```typescript
interface SchedulingToolData {
  url: string;                    // API endpoint with {{placeholders}}
  method: string;                 // HTTP method
  headers?: Record<string, string>;
  body?: string | Record<string, unknown>;
  auth?: { token: string; encode?: boolean; type?: string };
  response_data?: Array<{         // JSONPath extractors
    name: string;
    data: string;
    context?: string;
  }>;
  variables?: Record<string, {   // Variables to extract from conversation
    type: string;
    description: string;
    increaseSpellingAccuracy?: boolean;
  }>;
}
```

### Available Slots Format

Slots are stored in `variables["available_slots"]` as formatted groups:

```typescript
[
  { date: "Monday, January 19, 2026", times: ["4:50 PM"] },
  { date: "Tuesday, January 20, 2026", times: ["8:00 AM", "8:10 AM", "8:20 AM"] }
]
```

## Node Configuration

### Constructor Parameters

```typescript
interface SchedulingNodeConfig extends NodeConfig {
  scheduling_tool: SchedulingToolData;  // API configuration
  errorFallbackNode?: string;           // Node to route to on API failure
  slotLocking?: {                       // Optional slot reservation
    url: string;
    method: string;
    // ...
  };
}
```

### Internal Loop Condition

The scheduling node has a built-in validation condition:

> "Wait until the user has given a valid time and the agent has confirmed the time.
> The agent must explicitly repeat the date and time back to the user, and the user
> must agree that they want to confirm the appointment for that date and time."

If the node has a custom `condition`, it is appended after this built-in prompt.

### Programmatic Condition Short-Circuit

`checkSchedulingConditionProgrammatically()` bypasses LLM condition evaluation when a user gives an affirmative response to a confirmation question. Uses a two-tier regex approach:

- **Tier 1 (strict)**: Single-word responses — "yes", "yeah", "correct", "sure", "ok", "perfect", etc.
- **Tier 2 (permissive)**: Multi-word phrases — "that's correct", "sounds good", "works for me", "let's do it", "yes please", etc.

Only activates when the assistant's last message was a confirmation question (contains "confirm", "correct?", "right?", or ends with "?"). Both tiers still require: `start_datetime` is set, matches an available slot, and assistant's last message contains a date mention + confirmation pattern.

## Error Handling

### API Failure After 2 Retries

1. `scheduling_api_failed` flag is set to `true`
2. Error message injected into chat history:

```
SCHEDULING API ERROR: [error details]
Do NOT offer any new times to the user.
```

3. Node condition check detects `scheduling_api_failed` and forces exit
4. Routes to `errorFallbackNode` if configured

### Guard Against Infinite Retries

In `handleSchedulingFunctionCall()`:

```typescript
if (this.parentMediaStream.variables["scheduling_api_failed"]) {
  logger.log_message("Blocking fetch_more_slots call - scheduling_api_failed is true");
  return;
}
```

## Debugging Tips

### Key Log Patterns

```bash
# Slot fetching
grep "fetch_scheduling_slots\|handleSchedulingFunctionCall" logs.txt

# Dialogue generation
grep "handleAfterWebhookDialogue\|Storing dynamic data" logs.txt

# Audio queue issues
grep "shouldStop\|processAudioQueue\|Returning because of shouldStop" logs.txt

# Webhook failures
grep "schedulingWebhookFailures\|scheduling_api_failed" logs.txt
```

```bash
# Slot validation and locking
grep "Slot validation\|validate_scheduling_slot\|LOCK_PENDING\|LOCK_FAILED" logs.txt

# Timezone offset issues
grep "Injecting slot correction\|slot_date\|slot_time\|start_time" logs.txt
```

### Common Issues

1. **Slots generated but not spoken**: Check `shouldStop` flag in audio queue logs
2. **Infinite retries**: Verify `scheduling_api_failed` is being set after 2 failures
3. **Missing variables**: Check `extractInfo` action is running before slot fetch
4. **Wrong timezone**: Check `timezone` attribute in node configuration
5. **Lock webhook 409s**: Compare `start_time` in webhook body against the `matchedSlot` in validation logs — if they differ, it's a timezone offset conversion bug
6. **False slot corrections**: Search for "Injecting slot correction" — if `startDatetime` wall-clock matches an available slot, `isDatetimeInAvailableSlots` has a comparison bug

## Confirmation State Machine

Prevents scheduling confirmation hallucinations by gating dialogue output on slot lock results.

### States

```
IDLE → LOCK_PENDING → CONFIRMED (lock succeeded)
                  → LOCK_FAILED → IDLE (after context injection)
```

- **IDLE**: No confirmation in progress
- **LOCK_PENDING**: User confirmed a slot, waiting for lock result (built-in or webhook)
- **CONFIRMED**: Lock succeeded, safe to output confirmation dialogue
- **LOCK_FAILED**: Lock failed, stale dialogue aborted, failure context injected

### How It Works

**Built-in lock path** (`pathwayAgent.ts`):
State transitions happen inline around the `lock_scheduling_slot` action in `getDialogueGenerator`.

**Webhook lock path** (`processStream.ts`):
After `responsePathways` evaluation, the code detects slot lock webhooks by checking for `slot_locked` or `success` variables. On failure, it transitions the state machine, clears `chosen_datetime`, and calls `abortAllGenerators()` to kill pregenerated dialogue. When `handleAfterWebhookDialogue` runs for the next node, it checks for `LOCK_FAILED` state and injects a "SLOT UNAVAILABLE" message before generating new dialogue.

### Failed Slot Blacklist

When a slot fails to lock, its datetime is added to `schedulingLockContext.failedSlots`. This Set persists across retries. When `handleSchedulingFunctionCall` refetches slots, it filters out blacklisted times from `available_slots` to prevent the API from re-offering a slot that just failed.

### Webhook Lock Circuit Breaker

The webhook lock path tracks consecutive failures via `schedulingLockContext.webhookLockFailures`. After 3 consecutive failures, it sets `scheduling_api_failed = true` and injects a system error message, which triggers the existing `scheduling_api_failed` handler in `getDialogueGenerator` to force-exit the node via `errorFallbackNode`. The counter resets to 0 on any successful lock.

This is distinct from the fetch-slot circuit breaker (`schedulingWebhookFailures` on `mediaStream.ts`) which tracks failures when fetching available slots. The webhook lock circuit breaker uses a threshold of 3 (vs 2 for fetch failures) because individual lock failures can be transient (slot contention), but 3 consecutive failures indicate a systemic issue.

### False Confirmation Guard

When the LLM condition evaluator returns `isGoalAchieved = false` on a scheduling node, the system re-runs the node and generates new dialogue. To prevent the LLM from hallucinating "you're booked" based on the user's confirmation intent in the transcript, a system message is injected: "The appointment has NOT been confirmed yet. Do NOT tell the user they are booked."

This guard only fires when ALL of:

- `curr_node.type === "Scheduling"`
- `curr_node.attributes.slotLocking` is configured (non-null)
- `schedulingLockContext.state !== CONFIRMED`

The `slotLocking` gate is critical — without it, pathways using "request-only" mode (no slot locking) would loop infinitely because `lockState` stays `idle` forever and the guard fires on every iteration, preventing the condition from ever being met.

### Scheduling State Reset Between Nodes

When `updateCurrNode()` transitions to a different scheduling node (checked via `node instanceof SchedulingNode && oldNode.id !== node.id`), all scheduling state is reset: `failedSlots`, `webhookLockFailures`, `schedulingValidationFailures`, and `scheduling_api_failed`. This prevents a second scheduling node from inheriting stale failure state from a previous one. Self-transitions (re-running the same node) do NOT reset state.

### Day-of-Week Validation

`SchedulingNode.validateDayOfWeek()` checks if any day name in the assistant's dialogue matches the actual calendar day for the confirmed datetime. If the LLM says "Tuesday" but the date is a Thursday, the programmatic short-circuit is blocked and the LLM re-evaluates.

## Timezone Handling

Timezone bugs are the most common source of scheduling failures. The system uses a **wall-clock comparison** strategy to be resilient against LLM timezone offset errors.

### The Problem

LLMs frequently extract datetimes with wrong UTC offsets (e.g., `-0600` CST instead of `-0500` CDT after a DST transition). If these are converted through UTC, times shift by an hour — e.g., `09:30 -0600 → 15:30 UTC → 10:30 CDT`.

### Wall-Clock Extraction

Instead of parsing datetimes into `Date` objects (which convert to UTC), we extract wall-clock components directly via regex:

```typescript
// "2026-03-10 09:30:00-0600" → {month:3, day:10, hour:9, minute:30}
const match = datetime.match(/(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})/);
```

This makes validation **timezone-offset-agnostic** — `09:30` matches `9:30 AM` regardless of whether the offset is `-0500` or `-0600`.

### Where Wall-Clock Comparison Is Used

| Location | Function | Purpose |
|----------|----------|---------|
| `processStream.ts` | `extractWallClockComponents()` | Extracts {month, day, hour, minute} from ISO string |
| `processStream.ts` | `wallClockMatch()` / `wallClockMatchesTimeString()` | Compares wall-clock components with tolerance |
| `processStream.ts` | `validateSlotAgainstAvailable()` | Primary slot validation — returns `matchedDate`/`matchedTime` from the matched slot |
| `schedulingToolUtils.ts` | `isDatetimeInAvailableSlots()` | Secondary slot check (annotations, programmatic validation) |
| `schedulingToolUtils.ts` | `validateStartDatetime()` | Correction injection when `start_datetime` doesn't match slots |

### Matched Slot Data Flow

When `validateSlotAgainstAvailable` finds a match, it returns the **slot's own date and time strings** (`matchedDate`, `matchedTime`) rather than re-formatting the LLM's extraction. The `validate_scheduling_slot` handler uses these to set `slot_date` and `slot_time` via `formatInTimeZone` from `date-fns-tz`, ensuring the lock webhook receives the correct time.

```
LLM extracts "09:30 -0600" (wrong offset)
→ validateSlotAgainstAvailable wall-clock matches to slot "9:30 AM"
→ Returns matchedDate="Tuesday, March 10, 2026", matchedTime="9:30 AM"
→ Handler formats via date-fns-tz: slot_date="03/10/2026", slot_time="09:30 AM"
→ Lock webhook receives correct time ✓
```

### Year Tolerance

LLMs sometimes extract the wrong year (e.g., 2027 instead of 2026). Both `validateSlotAgainstAvailable` and `isDatetimeInAvailableSlots` use month+day matching without requiring exact year match, since available slots only span ~2 weeks into the future, making month+day+time unambiguous.

### Date/Time Libraries

- **`date-fns-tz`**: `formatInTimeZone()` and `toZonedTime()` for all timezone-aware formatting
- **`chrono-node`**: Used via `parseSlotDateTime()` for robust natural-language date parsing
- **Never use** `Date.getHours()`/`Date.getMinutes()` for scheduling comparisons — these return server-local time, not the agent's configured timezone

## SchedulingPrompt Design

The SchedulingPrompt (`nodeSpecificPrompts.ts`) is intentionally concise. Key design decisions:

- **Available Slots at the top** — placed before `{preDialoguePrompt}` (the Global Prompt) to ensure maximum attention weight on the actual booking data
- **Calendar reference (`datesMap`)** — a 14-day day-name-to-date mapping generated by `dateMap()` in `schedulingToolUtils.ts`, injected into `buildDialogueMessages`. Prevents day-of-week hallucinations (e.g., offering "Saturday Feb 28" when slots are on "Thursday Feb 26")
- **Positive behavioral examples** — shows the model correct behavior (fetch when empty, offer slots, handle rejection, confirm) rather than violation examples. Negative examples ("WRONG: offering March 2nd") actually prime the model toward hallucinations
- **No redundant guardrails** — the core rule "never suggest a date or time not listed here" is stated once. Previous versions repeated this ~5 times with escalating emphasis (CRITICAL, VIOLATION, STOP), which diluted attention

### preDialoguePrompt Injection

The Global Prompt (from `globalConfig` node or per-node `globalPrompt`) is injected via `{preDialoguePrompt}`. This carries the customer's persona, tone rules, and general instructions into the scheduling context. If customers include non-scheduling goals (e.g., "ask if they have a property to sell") in their Global Prompt, those instructions will compete with the scheduling task. This is a customer configuration issue — scheduling-specific instructions should be scoped to the scheduling node's prompt, not the Global Prompt.

## Slot Limiting

`limitSlotsPerDay()` in `schedulingToolUtils.ts` caps visible slots to 6 per day to reduce LLM context size. When slots are limited, `totalAvailable` is included so the agent knows more options exist. Raw slot data from the API (often 100+ slots) is preserved in `slotFetchHistory`.

## Related Commits

- `e8f923ae7` - fix: infinite webhook retries
- `50ca27d2e` - block further fetch slot calls once webhook fails
- `c772e560f` - fix: fetch slots upon node entry
- `a1e286ece` - more defensive scheduling node fixes