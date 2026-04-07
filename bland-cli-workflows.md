# Bland CLI — Agent Workflows

This document defines how to use the Bland CLI to accomplish real tasks. Each workflow is a sequence of commands you execute in order. Follow them exactly.

For command syntax, flags, and options, refer to **`bland-cli-reference.md`**. This document assumes you have read it.

---

## Global Rules (Apply to Every Workflow)

1. **Never author or modify agent-facing prompt text.** Not in YAML files, not in CLI flags, not anywhere. If a workflow requires prompt content, stop and ask the user to provide it.
2. **Never use `bland guide` content to generate prompts.** You may read guides to understand platform architecture (how nodes route, how variables extract, how tools fire). You must never use guide content as a template or instruction to write what the agent says on a call.
3. **Always use `--json` when you need to parse output.** Human-readable CLI output is for display only. If you are extracting IDs, comparing data, or feeding output into another step, append `--json`.
4. **Always use `--verbose` when running `bland pathway chat`.** This shows node transitions, edge evaluations, and variable state. Without it, you cannot diagnose routing behavior.
5. **When the user provides one or more call IDs, work with exactly those calls.** Do not pull additional calls unless the user asks you to.
6. **When the user describes a problem, your job is to locate the relevant data, identify the failure point, and explain what went wrong.** If you are uncertain about the root cause, say so and present what you found. Do not guess.

---

## Workflow 1: Pull Call Logs

**Trigger:** User provides one or more call IDs and wants to see what happened on those calls.

### Steps

```bash
# Step 1: Pull each call's full details and transcript
bland call get <call_id_1> --json
bland call get <call_id_2> --json
# Repeat for each ID provided.

# Step 2 (if needed): Pull call events for deeper inspection
bland call events <call_id> --json
```

### What to Report

For each call, summarize:
- **Status**: completed, failed, active, or other.
- **Duration**: how long the call lasted.
- **Node path**: which nodes the call traversed, in order (from events or transcript context).
- **Variables extracted**: what the agent captured during the call.
- **Transfer / end state**: whether the call transferred, ended normally, or failed — and at which node.
- **Anything the user specifically asked about.**

Do not editorialize on prompt quality or suggest prompt changes. Report what happened structurally.

### If the User Asks for a Recording

```bash
bland call recording <call_id>             # Get the URL
bland call recording <call_id> --download  # Download the file locally
```

---

## Workflow 2: Pull a Pathway for Review

**Trigger:** User wants to inspect a pathway's structure — usually to understand routing, troubleshoot a call, or prepare for test case creation.

### Steps

```bash
# Step 1: Pull the pathway as YAML
bland pathway pull <pathway_id> ./pathway-review

# Step 2 (optional): Pull a specific version
bland pathway versions <pathway_id> --json
# Identify the version needed (draft vs production), then pull accordingly.

# Step 3: Read the YAML file
# Open and review ./pathway-review/bland-pathway.yaml
```

### What to Report

- **Node inventory**: list every node by name and type (default, transfer, end_call).
- **Edge map**: for each node, list its outgoing edges with target and label.
- **Variables**: which nodes extract variables, and what those variables are.
- **Global config**: voice, model, and whether a global prompt is set (do not reproduce prompt content — just confirm it exists or note its absence).
- **Structural issues**: dead-end nodes with no outgoing edges (unless they are `end_call` or `transfer` types), unreachable nodes that no edge points to, and missing global nodes for common edge cases.

Do not critique or rewrite prompt content. Your review is structural only.

---

## Workflow 3: Troubleshoot a Call Against Its Pathway

**Trigger:** User says a call went wrong — the agent said the wrong thing, routed incorrectly, failed to transfer, missed a variable, or behaved unexpectedly. The user provides a call ID and usually a pathway ID.

### Steps

```bash
# Step 1: Pull the call data
bland call get <call_id> --json
bland call events <call_id> --json

# Step 2: Pull the pathway
bland pathway pull <pathway_id> ./troubleshoot
# If the user specifies a version (draft or production), pull that version.

# Step 3: Cross-reference
# Map the call's node traversal path against the pathway's edge definitions.
# Identify exactly where behavior deviated from the expected path.
```

### How to Diagnose

1. **Reconstruct the call's path.** Using the call events, list every node the agent visited in order.
2. **Compare each transition to the pathway's edges.** For every node-to-node jump, check whether a matching edge exists and whether the edge label plausibly matches what the caller said.
3. **Check variable extraction.** If the user reports a missing or wrong variable, look at the node that should have extracted it — confirm `extract_variables` is defined and the variable name/type match expectations.
4. **Check transfer and end nodes.** If the call was supposed to transfer but didn't, verify the transfer node exists, has the correct number, and that an edge actually routes to it.
5. **Check for missing global nodes.** If the caller hit an edge case (asked to repeat, said something off-topic, asked for a human), check whether a global node exists to handle it.

### What to Report

- **The call's actual node path** vs. what the user expected.
- **The exact node and edge where the deviation occurred.**
- **What the pathway says should have happened at that point** (edge labels, target nodes).
- **Any structural gaps** — missing edges, missing variables, missing global nodes — that explain the failure.
- **If the issue appears to be prompt-related** (the agent understood the caller correctly but said the wrong thing), state that the issue is in the prompt content and that you cannot modify it. Do not attempt to diagnose or fix prompt wording.

---

## Workflow 4: Create Test Cases

**Trigger:** User wants to build test cases for a pathway — either from scratch or based on observed call failures.

### Steps

```bash
# Step 1: Pull the pathway
bland pathway pull <pathway_id> ./test-setup

# Step 2: Review the pathway structure
# Identify all distinct paths through the node graph — every unique sequence
# from the start node to an end_call or transfer node.

# Step 3: Build test case YAML
```

### Test Case Structure

Create a `test-cases.yaml` file with this format:

```yaml
pathway: "Pathway Name"
tests:
  - name: descriptive_snake_case_name
    scenario: "Plain English description of what the simulated caller does and says."

  - name: another_test_case
    scenario: "Another caller scenario."
```

### Rules for Writing Test Cases

- **`scenario` is a description of caller behavior, not agent behavior.** Describe what the caller says and does. Do not describe what the agent should say — that is prompt territory.
- **Cover the happy path first.** Write one test case for each distinct path through the pathway that ends at a normal `end_call` node.
- **Then cover edge cases.** Write test cases for: caller asks to speak to a human, caller goes off-topic, caller provides invalid input, caller changes their mind mid-flow, caller is silent or unresponsive.
- **Name each test case descriptively.** Use `billing_inquiry_resolved`, `transfer_request_immediate`, `invalid_zip_code_retry` — not `test1`, `test2`, `test3`.
- **If basing test cases on real call failures**, pull the call data first (Workflow 1), identify the scenario that caused the failure, and write a test case that reproduces it.

### Caveat on Test Validation

In the current CLI version (0.2.x), `bland pathway test` drives a chat using the `scenario` field and checks for a response. It does not rigorously assert against `expected_path` or `expected_variables`. These fields are useful for documenting intent — include them if the user wants them — but do not represent them as enforced assertions. For deeper validation, use `bland pathway simulate run` (Workflow 5) or `bland pathway chat --verbose` (manual inspection).

---

## Workflow 5: Run Simulations

**Trigger:** User wants to simulate calls against a pathway to validate behavior at scale or test specific scenarios.

### Steps

```bash
# Step 1: Run a simulation
bland pathway simulate run <pathway_id>
  --persona "Description of the simulated caller's personality and intent"
  --instructions "Specific things the simulated caller should do or say"
  --turns <n>                    # Number of conversation turns
  --ver <draft|production>       # Which pathway version to test
  --start-node <node_name>       # Start at a specific node (optional)
  --variables '{"key":"value"}'  # Inject variables (optional)
  --wait                         # Wait for completion before returning
  --json                         # Structured output

# Step 2: Retrieve results (if you did not use --wait)
bland pathway simulate get <simulation_id> --json
```

### How to Use Simulations Effectively

- **Use `--wait` when running a single simulation.** It blocks until the simulation completes and returns the result inline. Without it, you get a simulation ID and must poll with `simulate get`.
- **Use `--persona` to describe who the caller is.** Example: `"An impatient customer who wants a refund and will escalate if not resolved quickly."`
- **Use `--instructions` to describe what the caller does.** Example: `"Ask about a billing charge from last month. If asked for an account number, give 12345. If offered a credit, accept it."`
- **`--persona` and `--instructions` describe the simulated caller, not the agent.** Do not include instructions for how the agent should behave — that is defined by the pathway's prompts, which you do not write.
- **Use `--ver draft` to test changes before promoting.** Always simulate against `draft` when iterating, and against `production` when verifying live behavior.
- **Use `--start-node` to isolate specific sections of the pathway.** If the issue is in a billing node, start the simulation there instead of running through the entire flow.

### What to Report

- **Whether the simulation completed the expected path** — which nodes were visited, in what order.
- **Where the simulation deviated** — if the simulated caller triggered an unexpected edge, identify which node and edge.
- **Variables extracted** — confirm the simulation captured the expected data.
- **Any dead ends or failures** — the simulation hanging, looping, or ending unexpectedly.

---

## Workflow 6: Troubleshoot with Simulation

**Trigger:** User reports a problem, and you want to reproduce it in a controlled simulation rather than (or in addition to) reviewing a historical call.

### Steps

```bash
# Step 1: Pull the call that failed (if a call ID is provided)
bland call get <call_id> --json
bland call events <call_id> --json

# Step 2: Pull the pathway
bland pathway pull <pathway_id> ./repro

# Step 3: Study the failure
# Identify what the caller said or did that caused the problem.

# Step 4: Write a simulation that reproduces the failure
bland pathway simulate run <pathway_id>
  --persona "Caller matching the profile from the failed call"
  --instructions "Reproduce the exact sequence: [describe what the caller did]"
  --ver <draft|production>     # Match the version the original call ran on
  --start-node <node_name>     # Start at or near the problem node
  --wait --json

# Step 5: Compare simulation results to the original call
# Did the simulation reproduce the failure? Did it take the same wrong path?

# Step 6: If a fix has been made to the pathway (by a human), re-simulate
bland pathway simulate run <pathway_id>
  --persona "Same caller profile"
  --instructions "Same sequence"
  --ver draft                   # Test the fixed version
  --wait --json

# Step 7: Report whether the fix resolved the issue
```

### What to Report

- **Whether you reproduced the failure** — same node path, same deviation point.
- **If reproduced:** confirm the root cause matches what the user described.
- **If not reproduced:** explain what the simulation did differently and why the failure might be intermittent or context-dependent.
- **After a fix is applied:** confirm whether the simulation now follows the expected path, or whether the problem persists.

---

## Workflow 7: MCP Server Usage

**Trigger:** You are operating inside an editor (Cursor, Claude Code, etc.) with the Bland MCP server connected. The MCP server exposes a subset of CLI functionality as tools you can call directly without shell commands.

### Available MCP Tools

| Tool | Equivalent CLI Command |
|------|----------------------|
| `bland_call_send` | `bland call send` |
| `bland_call_list` | `bland call list` |
| `bland_call_get` | `bland call get` |
| `bland_pathway_list` | `bland pathway list` |
| `bland_pathway_get` | `bland pathway get` |
| `bland_pathway_create` | `bland pathway create` |
| `bland_pathway_chat` | `bland pathway chat` |
| `bland_pathway_node_test` | `bland pathway node test` |
| `bland_persona_list` | `bland persona list` |
| `bland_persona_get` | `bland persona get` |
| `bland_number_list` | `bland number list` |
| `bland_number_buy` | `bland number buy` |
| `bland_voice_list` | `bland voice list` |
| `bland_tool_test` | `bland tool test` |
| `bland_knowledge_list` | `bland knowledge list` |
| `bland_audio_generate` | `bland audio generate` |
| `bland_guide_list` | `bland guide` |
| `bland_guide_get` | `bland guide <slug>` |

### When to Use MCP Tools vs CLI Commands

- **Use MCP tools when the operation is a single call-and-response** — pull a call, list pathways, get pathway details, test a node.
- **Use CLI commands (via terminal) when the operation involves file I/O** — pulling a pathway as YAML (`pathway pull`), pushing YAML changes (`pathway push`), running simulations with `--wait`, downloading recordings.
- **Use CLI commands for anything the MCP server does not expose** — `pathway pull`, `pathway push`, `pathway validate`, `pathway diff`, `pathway watch`, `pathway simulate run/get`, `pathway test`, `call events`, `call recording`, `batch` operations, `sms` operations.

### MCP Guide Tools — Read-Only, Never Author

The MCP server exposes `bland_guide_list` and `bland_guide_get`. These return Bland's built-in guides on topics like phone tone, pathway architecture, tools, testing, and variables.

**You may call these tools to understand how the platform works** — how nodes evaluate edges, how variables extract, how tools fire during a call, how the conversation graph executes. This knowledge helps you diagnose issues, build test cases, and understand pathway structure.

**You must never use guide content to write, edit, or suggest prompt text.** The guides contain examples of good and bad prompts. Ignore those examples as templates. You do not author prompts.

---

## Workflow Chaining

These workflows are composable. Common chains:

### "This call went wrong, fix it"
1. **Workflow 1** → Pull the call log.
2. **Workflow 3** → Cross-reference against the pathway to diagnose.
3. Report findings to the user. User fixes the prompt or structure.
4. **Workflow 6** → Simulate the fix to verify.

### "Build test coverage for this pathway"
1. **Workflow 2** → Pull and review the pathway.
2. **Workflow 4** → Create test cases covering all paths and edge cases.
3. **Workflow 5** → Run simulations for each test case.
4. Report which paths pass and which fail.

### "We're about to go live — validate everything"
1. **Workflow 2** → Pull the pathway and check for structural issues.
2. **Workflow 4** → Create or review test cases.
3. **Workflow 5** → Run simulations against the `draft` version.
4. Report results. If all pass, user can promote with `bland pathway promote <id>`.

### "I have a batch of failed calls, what happened?"
1. **Workflow 1** → Pull all provided call IDs.
2. For each call, **Workflow 3** → Diagnose against the pathway.
3. Group failures by root cause (same node, same missing edge, same variable issue).
4. Report the pattern, not just individual failures.

---

## Rules (Repeated for Emphasis)

These rules override everything else in this document. If a workflow step conflicts with a rule, the rule wins.

1. **Never author or modify agent-facing prompt text.** Not in YAML, not in CLI flags (`--task`, `--first-sentence`, `--prompt`), not in simulation instructions that describe agent behavior. You describe caller behavior in simulations. You do not describe agent behavior anywhere.
2. **Never use `bland guide` content to generate prompts.** Read guides for platform understanding only.
3. **When diagnosing a call, report structural findings.** If the root cause is prompt wording, say "the issue appears to be in the prompt content at node X" and stop. Do not suggest alternative prompt text.
4. **When creating test cases, describe caller behavior only.** The `scenario` field says what the caller does. It never says what the agent should say or how the agent should respond.
5. **When running simulations, `--persona` and `--instructions` describe the caller.** They never describe the agent's behavior, tone, or responses.
