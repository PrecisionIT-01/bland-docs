# Testing Workflows

This document covers test case creation, simulation, and validation workflows for Bland pathways.

## Test Cases

### Purpose

Test cases define scenarios the simulated caller will follow through a pathway. They help you verify routing behavior, variable extraction, and edge cases.

### Structure

```yaml
pathway: "Pathway Name"
tests:
  - name: descriptive_snake_case_name
    scenario: "Description of what the simulated caller does and says."
    # Optional fields for documentation (not enforced by CLI):
    expected_path: [greeting, identify_issue, billing_help, goodbye]
    expected_variables:
      issue_type: "billing"
    # Optional notes for broader context:
    notes: "Tests the happy path where caller has a billing inquiry and it's resolved."
```

### Rules for Writing Test Cases

1. **`scenario` describes caller behavior, not agent behavior.** The agent's responses are defined by the pathway's prompts. You describe what the caller says and does.

   ✅ **Good:**
   ```yaml
   scenario: "Caller wants to reschedule an appointment. Provide name (John Smith) and request to move to next Tuesday afternoon."
   ```

   ❌ **Bad:**
   ```yaml
   scenario: "Agent should greet warmly and ask about their issue. Then offer rescheduling options."
   ```

2. **Start with the happy path.** Write test cases for each distinct path that ends at a normal `end_call` node.

3. **Then cover edge cases.**
   - Caller asks to speak to a human
   - Caller goes off-topic
   - Caller provides invalid input (e.g., invalid zip code)
   - Caller changes their mind mid-flow
   - Caller is silent or unresponsive
   - Caller provides ambiguous information

4. **Name each test case descriptively.** Use `billing_inquiry_resolved`, `transfer_request_immediate`, not `test1`, `test2`.

5. **If based on real call failures**, pull the call data first ([Workflow 1](troubleshooting.md#workflow-1-pull-call-logs)), identify the scenario that caused the failure, and write a test case that reproduces it.

### Running Test Cases

```bash
# Run tests from .blandrc (default test file)
bland pathway test <pathway_id>

# Run specific test file
bland pathway test <pathway_id> --file tests/custom.yaml

# Output as JSON for parsing
bland pathway test <pathway_id> --json
```

**Caveat:** In CLI version 0.2.x, `pathway test` drives chat using the `scenario` field and checks for a response, but **does not rigorously validate** `expected_path` or `expected_variables`. These fields are useful for documenting intent, but do not treat them as enforced assertions. For deeper validation, use `pathway chat --verbose` and `pathway simulate run`.

### Test Case Example

```yaml
pathway: "Support Assistant"
tests:
  - name: billing_inquiry_happy_path
    scenario: "Caller asks about a late charge on their last bill. They provide account number 12345 and confirm it's for December. They accept the explanation and say thanks."
    expected_path: [greeting, identify_issue, check_billing, resolve, goodbye]
    expected_variables:
      account_number: "12345"
      issue_type: "billing"
    notes: "Standard billing question that can be answered immediately."

  - name: billing_inquiry_esalate_to_human
    scenario: "Caller is angry about charges and demands to speak with a manager. They refuse to provide account information and keep yelling. Eventually they say 'put me through to a human'."
    expected_path: [greeting, identify_issue, escalation_to_human, transfer]
    expected_variables:
      escalation_reason: "customer_dissatisfaction"
    notes: "Tests escalation routing when customer is agitated."

  - name: billing_inquiry_invalid_account
    scenario: "Caller asks about a charge but provides an invalid account number 'XYZ123'. They are confused and don't have their bill available. Eventually they agree to check and call back."
    expected_path: [greeting, identify_issue, invalid_account, unable_to_help, goodbye]
    notes: "Tests handling of invalid input when caller doesn't have required information."

  - name: billing_inquiry_off_topic
    scenario: "Caller starts asking about billing but then asks about their flight schedule for tomorrow. They keep bringing up unrelated travel plans."
    expected_path: [greeting, identify_issue, off_topic_redirection, back_on_track, resolve, goodbye]
    notes: "Tests pathway's ability to redirect from off-topic conversation."
```

---

## Simulations

Simulations use AI-driven simulated callers to test pathways. They're more flexible than static test cases because the AI can produce natural conversation variations.

### Running a Simulation

```bash
bland pathway simulate run <pathway_id> \
  --persona "Description of the simulated caller's personality and intent" \
  --instructions "Specific things the caller should do or say" \
  --turns <n> \
  --ver <draft|production> \
  --start-node <node_name> \
  --variables '{"key":"value"}' \
  --wait \
  --json
```

- `--persona` — Describe who the caller is (e.g., "An impatient customer who wants a refund and will escalate if not resolved quickly")
- `--instructions` — Describe what the caller does (e.g., "Ask about a billing charge from last month. If asked for account number, give 12345. If offered a credit, accept it.")
- `--turns` — Number of conversation turns (default varies)
- `--ver <draft|production>` — Which pathway version to test against
- `--start-node <node_name>` — Start at a specific node (optional)
- `--variables <json>` — Inject variables (optional)
- `--wait` — Wait for completion before returning (useful for single simulations)
- `--json` — Output as JSON for programmatic parsing

### Retrieving Simulation Results

If you don't use `--wait`, you get a simulation ID:

```bash
bland pathway simulate get <simulation_id> --json
```

### Workflow: Simulate Based on Real Failures

1. Pull the failed call: `bland call get <call_id> --json`
2. Pull the pathway: `bland pathway pull <pathway_id> ./repro`
3. Study the failure — identify what the caller said/did
4. Write simulation that reproduces the failure
5. Run simulation with `--wait`
6. Compare results to original call — did it reproduce the failure?
7. If fix was made, re-simulate to verify

See [Workflow 6](troubleshooting.md#workflow-6-troubleshoot-with-simulation) for full details.

### Simulation Examples

**Simple happy path from Draft version:**
```bash
bland pathway simulate run pw_abc123 \
  --persona "A customer with a billing question" \
  --instructions "Ask about a $25 charge on your last bill. Confirm it's for December. Accept the explanation." \
  --ver draft \
  --wait \
  --json
```

**Edge case starting at specific node:**
```bash
bland pathway simulate run pw_abc123 \
  --persona "An upset customer dissatisfied with service" \
  --instructions "Demand to speak with a manager. Escalate if not offered help immediately." \
  --ver production \
  --start-node identify_issue \
  --wait \
  --json
```

**Multiple turns with variables:**
```bash
bland pathway simulate run pw_abc123 \
  --persona "A confused elderly caller who doesn't have their account information" \
  --instructions "Ask about charges but don't provide correct info when asked. Need assistance finding your documents." \
  --turns 10 \
  --variables '{"age": 75, "has_documents": false}' \
  --ver production \
  --wait \
  --json
```

---

## Node Testing

Test individual nodes in isolation:

```bash
# Test a single node
bland pathway node test <pathway_id> <node_id>

# Test with multiple variations
bland pathway node test <pathway_id> <node_id> --permutations 5

# Test with specific input
bland pathway node test <pathway_id> <node_id> --input '{"phone":"+15551234567"}'

# Test custom code node
bland pathway code test <pathway_id> <node_id>
bland pathway code test <pathway_id> <node_id> --input '{"key":"value"}'
```

Use node testing to:
- Verify node logic works as expected
- Test custom code nodes independently
- Debug specific portions of a pathway

---

## Interactive Testing

Chat with a pathway from the terminal:

```bash
bland pathway chat <pathway_id> \
  --verbose \
  --start-node <node_name> \
  --variables '{"key":"value"}'
```

- **Always use `--verbose`** — shows node transitions, variable state, edge evaluations
- **--start-node** — start at a specific node for targeted testing
- **--variables** — inject context variables

Use `pathway chat` for:
- Exploratory testing
- Verifying behavior in real-time
- Seeing how the agent responds to different inputs

---

## Validation Workflow

### Before Production

1. **Pull the pathway** → `bland pathway pull <id> ./prod-check`
2. **Review structure** → Check for dead ends, unreachable nodes, missing variables
3. **Create test cases** → Cover happy path, edge cases, error scenarios
4. **Run `pathway test`** → Execute test cases (note: assertions not enforced)
5. **Run `pathway chat --verbose`** → Manual testing of key paths
6. **Run simulations** → `pathway simulate run` for realistic caller behavior
7. Review results → All critical paths working as expected
8. **Promote to production** → `bland pathway promote <id>` (with user approval)

### After Changes

1. **Pull the latest version** → `bland pathway pull <id> ./review`
2. **`pathway diff`** → Compare versions to see what changed
3. **Create test cases for new behavior** → Cover new edges, nodes, variables
4. **Run tests and simulations** → Verify changes work, nothing broken
5. **Review regression** → Check that old paths still work
6. **Promote** → Only if all tests pass

---

## Best Practices

1. **Write descriptive test scenarios.** Make it clear what the caller does, not what should happen.
2. **Cover edge cases thoroughly.** Happy paths aren't enough — test failures, off-topic, invalid input.
3. **Use `--verbose` for pathway chat.** Without it, you're testing blind.
4. **Use `--wait` for single simulations.** Makes results immediate and clear.
5. **Simulate against `draft` version first.** Promote to `production` only after verification.
6. **Use node testing for isolated debugging.** Great for pinpointing issues.
7. **Review diffs before promoting.** Ensure you know exactly what changed.
8. **Never deploy without testing.** Even "small" changes can have unexpected effects.

## Companion Documents

- **[troubleshooting.md](troubleshooting.md)** — Full workflow for diagnosing call failures
- **[cli-commands.md](../reference/cli-commands.md)** — Full CLI reference
- **[mcp-tools.md](../reference/mcp-tools.md)** — MCP access to pathways and calls