# Troubleshooting Workflows

This document defines workflows for diagnosing call and pathway issues. For command syntax, see [cli-commands.md](../reference/cli-commands.md).

## Global Rules (Apply to Every Workflow)

1. **Never author or modify agent-facing prompt text.**
2. **Never use `bland guide` content to generate prompts.** Read guides for platform understanding only.
3. **Always use `--json`** when you need to parse output.
4. **Always use `--verbose`** when running `bland pathway chat`.
5. **When the user provides one or more call IDs, work with exactly those calls.**
6. **When the user describes a problem, locate the relevant data, identify the failure point, and explain what went wrong.**

---

## Workflow 1: Pull Call Logs

### Trigger

User provides one or more call IDs and wants to see what happened.

### Steps

```bash
# Pull each call's full details and transcript
bland call get <call_id_1> --json
bland call get <call_id_2> --json
# Repeat for each ID.

# Pull call events for deeper inspection (if needed)
bland call events <call_id> --json
```

### What to Report

For each call, summarize:

- **Status** — completed, failed, active
- **Duration** — how long the call lasted
- **Node path** — which nodes were visited, in order
- **Variables extracted** — what the agent captured
- **Transfer / end state** — whether the call transferred, ended normally, or failed (and at which node)
- **Anything the user asked about**

Do not editorialize on prompt quality. Report what happened structurally.

### If the User Asks for a Recording

```bash
bland call recording <call_id>             # Get the URL
bland call recording <call_id> --download  # Download locally
```

---

## Workflow 2: Pull a Pathway for Review

### Trigger

User wants to inspect pathway structure for troubleshooting or test case creation.

### Steps

```bash
# Pull the pathway as YAML
bland pathway pull <pathway_id> ./pathway-review

# Pull a specific version (if needed)
bland pathway versions <pathway_id> --json
# Identify the version needed, then pull.

# Read the YAML file
cat ./pathway-review/bland-pathway.yaml
```

### What to Report

- **Node inventory** — list every node by name and type (default, transfer, end_call)
- **Edge map** — for each node,列出 outgoing edges with target and label
- **Variables** — which nodes extract variables, and what those variables are
- **Global config** — voice, model, and whether a global prompt is set (do not reproduce prompt content)
- **Structural issues** — dead-end nodes (unless end_call/transfer), unreachable nodes, missing global nodes

Do not critique or rewrite prompt content. Report structural findings only.

---

## Workflow 3: Troubleshoot a Call Against Its Pathway

### Trigger

User reports call went wrong — agent said wrong thing, routed incorrectly, failed to transfer, missed variable.

### Steps

```bash
# Pull the call data
bland call get <call_id> --json
bland call events <call_id> --json

# Pull the pathway
bland pathway pull <pathway_id> ./troubleshoot
# Use specific version if specified (draft or production)

# Cross-reference
# Map the call's node traversal path against the pathway's edge definitions.
```

### How to Diagnose

1. **Reconstruct the call's path.** Use call events to list every node visited in order.
2. **Compare each transition to the pathway's edges.** For every jump, check if a matching edge exists and label matches what the caller said.
3. **Check variable extraction.** If user reports missing/wrong variable, look at the node that should have extracted it.
4. **Check transfer and end nodes.** If call was supposed to transfer, verify transfer node exists, has correct number, and edge routes to it.
5. **Check for missing global nodes.** If caller hit edge case (asked to repeat, went off-topic), check if global node exists to handle it.

### What to Report

- **The call's actual node path** vs. what the user expected
- **The exact node and edge where deviation occurred**
- **What the pathway says should have happened** (edge labels, target nodes)
- **Any structural gaps** — missing edges, variables, global nodes — that explain failure
- **If issue appears prompt-related**, state "the issue appears to be in the prompt content at node X" and stop. Do not suggest alternative prompt text.

---

## Workflow 4: Create Test Cases

### Trigger

User wants to build test cases for a pathway — from scratch or based on observed failures.

### Steps

```bash
# Pull the pathway
bland pathway pull <pathway_id> ./test-setup

# Review the pathway structure
# Identify all distinct paths through the graph.

# Build test case YAML
```

### Test Case Structure

```yaml
pathway: "Pathway Name"
tests:
  - name: descriptive_snake_case_name
    scenario: "Plain English description of what the simulated caller does and says."

  - name: another_test_case
    scenario: "Another caller scenario."
```

### Rules for Writing Test Cases

- **`scenario` describes caller behavior, not agent behavior.** Describe what the caller says/does. Do not describe what the agent should say.
- **Cover the happy path first.** One test case for each distinct path to end_call or transfer node.
- **Then cover edge cases.** Caller asks for human, goes off-topic, invalid input, changes mind, unresponsive.
- **Name each test case descriptively.** Use `billing_inquiry_resolved`, not `test1`.
- **If based on real failures**, pull call data first, identify scenario, write test case that reproduces it.

### Test Command

```bash
bland pathway test <id>                       # Run tests from .blandrc
bland pathway test <id> --file tests/custom.yaml  # Run specific test file
bland pathway test <id> --json                # Output as JSON
```

**Caveat:** In CLI version 0.2.x, `pathway test` drives chat using `scenario` but does not rigorously validate `expected_path` or `expected_variables`. Use `pathway chat --verbose` and `pathway simulate run` for deeper validation.

---

## Workflow 5: Run Simulations

### Trigger

User wants to simulate calls against a pathway to validate behavior at scale.

### Steps

```bash
# Run a simulation
bland pathway simulate run <pathway_id> \
  --persona "Description of simulated caller's personality and intent" \
  --instructions "Specific things the caller should do or say" \
  --turns <n> \
  --ver <draft|production> \
  --start-node <node_name> \
  --variables '{"key":"value"}' \
  --wait \
  --json

# Retrieve results (if not using --wait)
bland pathway simulate get <simulation_id> --json
```

### How to Use Simulations

- **Use `--wait`** for single simulations — blocks until completion
- **Use `--persona`** to describe who the caller is (e.g., "An impatient customer who wants a refund")
- **Use `--instructions`** to describe what the caller does (e.g., "Ask about billing. If asked for account number, give 12345.")
- **`--persona` and `--instructions` describe the caller**, not the agent. Do not include instructions for agent behavior.
- **Use `--ver draft`** to test changes before promoting
- **Use `--start-node`** to isolate specific sections of the pathway

### What to Report

- **Whether simulation completed the expected path** — which nodes were visited, in order
- **Where it deviated** — if it triggered unexpected edge, identify which node and edge
- **Variables extracted** — confirm simulation captured expected data
- **Any dead ends or failures** — simulation hung, looped, or ended unexpectedly

---

## Workflow 6: Troubleshoot with Simulation

### Trigger

User reports a problem and you want to reproduce it in a controlled simulation.

### Steps

```bash
# Pull the call that failed (if call ID provided)
bland call get <call_id> --json
bland call events <call_id> --json

# Pull the pathway
bland pathway pull <pathway_id> ./repro

# Study the failure
# Identify what the caller said/did that caused the problem.

# Write simulation that reproduces failure
bland pathway simulate run <pathway_id> \
  --persona "Caller matching profile from failed call" \
  --instructions "Reproduce exact sequence: [describe]" \
  --ver <draft|production> \
  --start-node <node_name> \
  --wait --json

# Compare simulation results to original call
# Did it reproduce same wrong path?

# If fix was made, re-simulate
bland pathway simulate run <pathway_id> \
  --persona "Same caller profile" \
  --instructions "Same sequence" \
  --ver draft \
  --wait --json
```

### What to Report

- **Whether you reproduced the failure** — same node path and deviation point
- **If reproduced:** confirm root cause matches description
- **If not:** explain what simulation did differently
- **After fix:** confirm whether simulation now follows expected path, or problem persists

---

## Workflow Chaining

Composable chains:

### "This call went wrong, fix it"
1. **Workflow 1** → Pull call log
2. **Workflow 3** → Diagnose against pathway
3. Report findings to user. User fixes.
4. **Workflow 6** → Simulate to verify

### "Build test coverage for this pathway"
1. **Workflow 2** → Pull and review pathway
2. **Workflow 4** → Create test cases
3. **Workflow 5** → Run simulations for each test case
4. Report which pass/fail

### "We're about to go live — validate everything"
1. **Workflow 2** → Pull pathway, check structural issues
2. **Workflow 4** → Create/review test cases
3. **Workflow 5** → Run simulations against `draft` version
4. Report results. If all pass, user can promote.

### "I have a batch of failed calls, what happened?"
1. **Workflow 1** → Pull all call IDs
2. For each call, **Workflow 3** → Diagnose
3. Group failures by root cause
4. Report pattern, not individual failures

---

## Rules (Repeated)

These rules override everything:

1. **Never author agent-facing prompt text.**
2. **Never use `bland guide` content to generate prompts.** Read for platform understanding only.
3. **When diagnosing call, report structural findings.** If prompt-related, say so and stop. Do not suggest alternative prompt text.
4. **When creating test cases, describe caller behavior only.** `scenario` field says what caller does. Never says what agent should say.
5. **When running simulations, `--persona` and `--instructions` describe the caller.** Never describe agent's behavior.

## Companion Documents

- **[cli-commands.md](../reference/cli-commands.md)** — Full CLI reference
- **[mcp-tools.md](../reference/mcp-tools.md)** — MCP tool access
- **[testing.md](testing.md)** — Detailed testing workflows