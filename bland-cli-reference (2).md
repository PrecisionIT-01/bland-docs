# Bland CLI — Agent Reference

You have access to the Bland CLI (`bland-cli`), a command-line tool for interacting with Bland AI. Use it to manage pathways, calls, phone numbers, voices, tools, knowledge bases, personas, batch campaigns, SMS, and more. This document is your complete reference. Follow it exactly.

---

## Installation and Authentication

The CLI requires Node.js 18+.

```bash
npm install -g bland-cli
```

Or run without installing:

```bash
npx bland-cli
```

### Authenticating

Authenticate before any other command. Two methods:

```bash
# Interactive
bland auth login

# Non-interactive (preferred in automation)
bland auth login --key sk-...

# Log out / clear stored credentials
bland auth logout
```

Or set the environment variable to skip login entirely:

```bash
export BLAND_API_KEY=your_key_here
```

**Note on key format:** Bland API keys may appear as `sk-...`, `org_...`, or other prefixes depending on account type and era. Do not validate or reject a key based on its prefix shape.

### Verifying Authentication

Always verify before starting work:

```bash
bland auth whoami
```

This returns the account name and current balance. If it fails, you are not authenticated. Do not proceed.

### Multiple Profiles

The CLI supports multiple profiles for different orgs or environments. Profiles are stored at `~/.config/bland-cli/config.json`.

```bash
bland auth profiles           # List all saved profiles
bland auth switch              # Switch between profiles
```

You can override the active profile per-command:

```bash
BLAND_API_KEY=sk-staging-xxx bland pathway list
```

---

## Pathways

Pathways define how a voice agent conducts a call — nodes, edges, prompts, variables, and routing logic. The CLI lets you manage pathways as YAML files locally and sync them with the Bland API.

**You must never author or modify agent-facing prompt text.** Your role with pathways is limited to structural operations: creating, syncing, testing, versioning, and validating. If a task requires writing or editing what the agent says, stop and ask the user to provide the prompt content.

### YAML Format

Pathways are defined in YAML with this structure:

```yaml
name: "Pathway Name"
description: "What this pathway does"
version: draft

global:
  voice: nat
  model: base
  prompt: |
    # Global prompt content goes here — provided by a human, never written by you.

nodes:
  node_name:
    type: default
    prompt: |
      # Node prompt — provided by a human, never written by you.
    extract_variables:
      - name: variable_name
        type: string
        description: "What this variable captures"
    edges:
      - target: next_node_name
        label: "Natural language description of when this edge fires"
      - target: another_node
        label: "Another transition condition"

  transfer_node:
    type: transfer
    number: "+15551234567"

  end_node:
    type: end_call
    prompt: |
      # End call prompt — provided by a human.
```

Key rules about this format:
- Edge labels are **natural language descriptions**, not boolean conditions. Write `"Caller wants to book an appointment"`, never `"if intent == 'booking'"`.
- Node types include: `default`, `transfer`, `end_call`.
- `extract_variables` captures structured data from conversation. Each variable needs `name`, `type`, and `description`.
- The `global` block sets defaults (voice, model, prompt) that apply to all nodes.

### Project Scaffolding

To start a new pathway project:

```bash
bland pathway init ./project-dir --name "Pathway Name"
```

This creates:

```
project-dir/
  bland-pathway.yaml       # Pathway definition
  tests/
    test-cases.yaml        # Test cases
  .blandrc                 # Project config (links local files to remote pathway)
```

The `.blandrc` file maps the local project to a remote pathway:

```yaml
pathway_id: pw_abc123
pathway_file: bland-pathway.yaml
test_file: tests/test-cases.yaml
```

### Syncing with Bland

```bash
bland pathway push [dir]              # Upload local YAML to Bland
bland pathway push [dir] --create     # Create new pathway if no ID linked
bland pathway pull <id> [dir]         # Download remote pathway as YAML
bland pathway diff [dir]              # Compare local YAML vs remote state
bland pathway validate [dir]          # Validate YAML locally before pushing
bland pathway watch [dir]             # Auto-push on every file save
```

**Always validate before pushing.** Run `bland pathway validate` first. If it reports errors, fix them before pushing.

### Listing and Inspecting

```bash
bland pathway list                    # List all pathways
bland pathway get <id>                # Show full pathway details
```

### Creating, Duplicating, Deleting

```bash
bland pathway create [name]           # Create a new empty pathway
bland pathway create --from-file <path>  # Create from a YAML file
bland pathway duplicate <id>          # Duplicate an existing pathway
bland pathway delete <id>             # Delete a pathway (irreversible)
```

### Versioning and Promotion

```bash
bland pathway versions <id>           # List all versions of a pathway
bland pathway promote <id>            # Promote the current draft to production
```

Always confirm with the user before promoting. Promotion is a deployment action.

### Interactive Testing

```bash
bland pathway chat <id>               # Chat with a pathway in the terminal
bland pathway chat <id> --verbose     # Show node transitions and variable state
bland pathway chat <id> --start-node <name>   # Start at a specific node
bland pathway chat <id> --variables '{"key":"value"}'  # Inject variables
```

**Use `--verbose` by default when testing.** It shows which node is active, what variables are set, and how edges are evaluated. Without it, you are testing blind.

### Automated Testing

Define test cases in YAML:

```yaml
pathway: "Pathway Name"
tests:
  - name: test_case_name
    scenario: "Description of what the simulated caller does."
    expected_path: [greeting, identify_issue, billing_help, goodbye]
    expected_variables:
      issue_type: "billing"
```

Run them:

```bash
bland pathway test <id>                       # Run test cases from .blandrc
bland pathway test <id> --file tests/custom.yaml  # Run specific test file
bland pathway test <id> --json                # Output as JSON
```

**Caveat:** In the current CLI version (0.2.x), `pathway test` drives chat using the `scenario` field and checks for a response, but does not rigorously validate `expected_path` or `expected_variables` against actual execution. These fields are useful for documenting intent, but do not treat them as assertions that the CLI enforces. Use `pathway chat --verbose` and `pathway simulate run` for deeper validation.

### AI Simulation

Simulation uses a subcommand structure — `run` to start, `get` to retrieve results.

```bash
# Start a simulation
bland pathway simulate run <id>
  --persona <text>                    # Persona description for the simulated caller
  --instructions <text>              # Specific instructions for the simulation
  --turns <n>                         # Number of conversation turns
  --start-node <name>                # Start at a specific node
  --variables <json>                 # Inject variables
  --ver <draft|production>           # Pathway version to simulate against
  --wait                              # Wait for simulation to complete before returning
  --json                              # Output as JSON

# Retrieve simulation results
bland pathway simulate get <simulation_id>
  --json                              # Output as JSON
```

**Important:** The command is `bland pathway simulate run <id>`, not `bland pathway simulate <id>`. Without the `run` subcommand, the CLI will error.

### Node-Level Testing

```bash
bland pathway node test <pathway_id> <node_id>         # Test a single node
bland pathway node test <pathway_id> <node_id> --permutations 5  # Multiple variations
```

### Code Node Testing

```bash
bland pathway code test <pathway_id> <node_id>         # Test a custom code node
bland pathway code test <pathway_id> <node_id> --input '{"key":"value"}'
```

### AI Generation

```bash
bland pathway generate --description "A pathway that handles appointment scheduling for a dental office"
```

This generates a pathway from a natural language description. Always review the output before pushing — the generated prompts will need human review and likely rewriting.

### Editing

```bash
bland pathway edit <id>                # Opens a node prompt in $EDITOR
```

**Do not use this command yourself.** It opens an interactive editor. If the user asks you to edit a prompt, remind them that you do not author prompt text.

### Folders

```bash
bland pathway folder list
bland pathway folder create <name>
```

---

## Calls

### Sending Calls

```bash
bland call send <phone_number>
  --task <prompt>                 # What the AI should do (simple calls without a pathway)
  --pathway <id>                  # Use a pathway instead of a task
  --voice <voice>                 # Voice selection (e.g., nat, josh)
  --from <number>                 # Caller ID / from number
  --first-sentence <text>         # Opening line
  --model <base|turbo>            # Model selection
  --max-duration <minutes>        # Maximum call length
  --wait                          # Wait and stream the live transcript
  --record                        # Enable call recording
  --transfer <number>             # Transfer number
  --request-data <json>           # Variables to inject into the call
  --webhook <url>                 # Post-call webhook URL
```

When sending a call with `--pathway`, do not also pass `--task`. They are mutually exclusive.

Use `--wait` when you need to observe the call outcome before proceeding. It streams the transcript to your terminal in real time.

### Listing and Inspecting Calls

```bash
bland call list                       # List recent calls (default: 20)
bland call list --limit 50            # More results
bland call list --status completed    # Filter by status: completed, active, failed
bland call list --from 2025-01-01 --to 2025-01-31  # Date range
bland call list --inbound             # Only inbound calls
bland call list --batch <batch_id>    # Filter by batch

bland call get <call_id>              # Full call details including transcript
bland call events <call_id>           # View call events (node transitions, tool calls, etc.)
bland call recording <call_id>        # Get recording URL
bland call recording <call_id> --download  # Download recording to local file
```

### Stopping and Analyzing Calls

```bash
bland call stop <call_id>             # End an active call immediately
bland call analyze <call_id>          # Run post-call analysis
```

---

## Phone Numbers

```bash
bland number list                     # List all owned numbers
bland number buy                      # Purchase a new number
bland number buy --area-code 402      # Preferred area code
bland number buy --country US         # Country code (default: US)
bland number buy --count 3            # Buy multiple numbers

bland number release <number>         # Release a number (irreversible)

bland number update <number>          # Update number configuration
  --pathway <id>                      # Set inbound pathway
  --persona <id>                      # Set persona
  --webhook <url>                     # Set webhook
  --prompt <text>                     # Set prompt
  --voice <voice>                     # Set voice

bland number configure <number>       # Interactive configuration wizard
```

When buying numbers, always confirm the area code and count with the user first. Number purchases cost money.

---

## Personas

```bash
bland persona list                    # List all personas
bland persona get <id>                # Show persona details
bland persona create                  # Create interactively
bland persona update <id>             # Update a persona
bland persona delete <id>             # Delete a persona
bland persona promote <id>            # Promote draft to production
bland persona reset-draft <id>        # Reset draft to match production
bland persona gaps <id>               # View knowledge gaps identified from calls
```

---

## Voices

```bash
bland voice list                      # List all available voices
bland voice list --language es        # Filter by language code
bland voice list --custom             # Show only custom/cloned voices

bland voice speak "Hello, how are you today?"    # Generate TTS audio
bland voice speak "Test phrase" --voice josh      # Specific voice
bland voice speak "Test phrase" -o output.mp3     # Save to file
```

Use `bland voice speak` to audition voices before assigning them to pathways or numbers. Always save to a file with `-o` so the user can review.

---

## Tools

Tools are webhook or custom integrations attached to pathway nodes. They let the agent fetch or send data in real time during a call.

```bash
bland tool list                       # List all tools
bland tool get <id>                   # Show tool details
bland tool create                     # Create interactively
bland tool update <id>                # Update a tool
bland tool delete <id>                # Delete a tool
bland tool types                      # List available tool types

bland tool test <id>                  # Test a tool with sample input
bland tool test <id> --input '{"phone":"+15551234567"}'
bland tool test <id> --verbose        # Show full request/response cycle
```

**Always test tools with `--verbose` after creating or updating them.** This shows the full HTTP request and response, which is essential for debugging integration issues.

---

## Knowledge Bases

```bash
bland knowledge list                  # List all knowledge bases (alias: bland kb list)
bland knowledge create <name>         # Create a new knowledge base
bland knowledge delete <id>           # Delete a knowledge base
bland knowledge status <id>           # Check processing status

bland knowledge scrape <name>         # Scrape URLs into a knowledge base
  --urls https://example.com,https://example.com/faq   # Comma-separated
  --file urls.txt                     # Or a file with one URL per line
```

After scraping, always check `bland knowledge status <id>` before using the knowledge base. Processing is asynchronous and the KB is not usable until status is complete.

---

## Batch Campaigns

```bash
bland batch create                    # Create a batch campaign
  --file contacts.csv                 # CSV file with contacts
  --pathway <id>                      # Pathway to use
  --from <number>                     # From number

bland batch list                      # List all batches
bland batch get <id>                  # Batch details and statistics
bland batch stop <id>                 # Stop a running batch
```

**Never create a batch without explicit user confirmation.** Batches make real calls to real numbers and cost money. Always confirm: the contact file, the pathway, the from number, and the expected volume.

---

## SMS

```bash
bland sms send <number>              # Send an SMS
  --from <number>                    # From number
  --message "Your message here"      # Message text
  --pathway <id>                     # Use a pathway for conversational SMS

bland sms conversations              # List SMS conversations
bland sms get <conversation_id>      # Get full conversation thread
```

---

## Web Agents

```bash
bland agent list
bland agent get <id>
bland agent create
bland agent update <id>
bland agent delete <id>
```

---

## Guard Rails

```bash
bland guard list
bland guard create
bland guard delete <id>
```

---

## Monitoring and Alarms

```bash
bland alarm list
bland alarm create
bland alarm delete <id>
```

---

## Secrets

```bash
bland secret list
bland secret set <name> <value>
bland secret delete <name>
```

Use secrets for API keys, tokens, or credentials that tools or code nodes need at runtime. Never hardcode secrets into pathway YAML, tool configs, or code nodes.

---

## Releases

```bash
bland release list
bland release create
bland release promote <id>
```

---

## Widgets

```bash
bland widget list
bland widget create
bland widget delete <id>
```

---

## Evaluations

```bash
bland eval run
bland eval list
bland eval get <id>
```

---

## Audio

```bash
bland audio generate "Text to speak" --voice nat -o output.mp3
bland audio analyze <audio_file>
```

---

## SIP

```bash
bland sip discover <host>
```

---

## Local Webhook Development

Forward Bland webhooks to a local dev server without ngrok:

```bash
bland listen
  --forward-to http://localhost:3000/webhook   # Your local server URL
  --port 4242                                   # Listen port (default: 4242)
  --events call.completed,call.failed           # Filter event types
```

This creates a temporary public endpoint and forwards incoming webhook events to your local URL. It logs each event with timestamps and HTTP response codes.

---

## JSON Output

Every `list` and `get` command supports `--json` for structured output. **Always use `--json` when you need to parse or process CLI output programmatically.**

```bash
bland pathway list --json | jq '.[].id'
bland call get <id> --json | jq '.transcripts'
bland number list --json | jq 'length'
```

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `BLAND_API_KEY` | API key. Overrides the stored profile. |
| `BLAND_BASE_URL` | API base URL. Default: `https://api.bland.ai`. Only change for staging or custom endpoints. |

### Project-Level .env Usage

Some workspaces invoke the CLI via `npm run bland` with a `.env` file (loaded by `dotenv`) instead of a global `bland` command. If this workspace uses that pattern, replace `bland` with `npm run bland --` in all commands. For example:

```bash
# Global install
bland pathway list --json

# npm run + dotenv pattern
npm run bland -- pathway list --json
```

Check for a `.env` file or a `"bland"` script in `package.json` to determine which pattern this project uses.

---

## MCP Server

The CLI includes a built-in MCP (Model Context Protocol) server that lets AI tools interact with the Bland account programmatically.

```bash
bland mcp                            # Start MCP server (stdio transport)
bland mcp --transport sse --port 3100 # Start with SSE transport
```

### Claude Code Integration

Add to your Claude Code config (`.claude/mcp.json` or equivalent):

```json
{
  "mcpServers": {
    "bland": {
      "command": "npx",
      "args": ["bland-cli", "mcp"]
    }
  }
}
```

### Cursor Integration

Add to your Cursor MCP config (`.cursor/mcp.json` in the project root, or configure via Cursor Settings → MCP):

```json
{
  "mcpServers": {
    "bland": {
      "command": "npx",
      "args": ["bland-cli", "mcp"]
    }
  }
}
```

The configuration payload is identical — the difference is where Cursor looks for it. If the MCP server does not connect, verify that `npx bland-cli mcp` runs successfully in a standalone terminal first.

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `bland_guide_list` | List all available guides |
| `bland_guide_get` | Read a specific guide by slug |
| `bland_call_send` | Make a phone call |
| `bland_call_list` | List recent calls |
| `bland_call_get` | Get call details and transcript |
| `bland_pathway_list` | List pathways |
| `bland_pathway_get` | Get pathway details |
| `bland_pathway_create` | Create a pathway from nodes/edges |
| `bland_pathway_chat` | Chat with a pathway |
| `bland_pathway_node_test` | Test a single node |
| `bland_persona_list` | List personas |
| `bland_persona_get` | Get persona details |
| `bland_number_list` | List phone numbers |
| `bland_number_buy` | Buy a phone number |
| `bland_voice_list` | List available voices |
| `bland_tool_test` | Test a custom tool |
| `bland_knowledge_list` | List knowledge bases |
| `bland_audio_generate` | Generate TTS audio |

---

## Built-In Guides

The CLI ships with a guide system for LLM context. Access them via:

```bash
bland guide                           # List all guides
bland guide phone-tone                # Writing natural phone prompts
bland guide pathways                  # Node/edge architecture and execution model
bland guide tools                     # Webhook and custom tools on nodes
bland guide testing                   # Chat, simulate, node tests
bland guide variables                 # Extracting and using caller data
```

| Guide | What It Covers |
|-------|----------------|
| `phone-tone` | How to write prompts that sound natural on the phone. Brevity, back-channeling, empathy, topic transitions. |
| `pathways` | How the conversation graph works: nodes, edges, global nodes, variables, global prompt, execution model. |
| `tools` | Attaching webhook/custom tools to nodes. `speech`, `behavior`, `response_data` fields. |
| `testing` | Full testing workflow: `pathway chat`, `simulate`, `node test`. |
| `variables` | `extract_variables`, `{{curly_braces}}` in prompts, `spelling_precision` for names/emails. |

When working on a pathway-related task, read the relevant guide first with `bland guide <slug>` to load platform-specific context before proceeding.

---

## Standard Workflow

When building or iterating on a pathway, follow this sequence:

```
1. bland pathway init ./project       # Scaffold
2. Edit bland-pathway.yaml            # Human authors the prompts
3. bland pathway validate             # Check for structural errors
4. bland pathway push --create        # Upload to Bland
5. bland pathway chat <id> --verbose  # Test interactively
6. bland pathway test <id>            # Run scenario-driven test cases
7. bland pathway simulate run <id>    # Run AI simulation for deeper validation
8. bland pathway promote <id>         # Deploy to production (with user approval)
9. bland pathway watch                # Auto-push on save during iteration
```

Never skip steps 3 and 5. Validation catches structural errors. Interactive chat with `--verbose` catches logic and routing errors that validation cannot detect.

---

## Rules

1. **Never author or modify agent-facing prompt text.** You may scaffold pathway structure, create nodes, define edges, set up variables, and configure tools — but all prompt content must be provided by a human. This applies everywhere: YAML files, pathway create/edit commands, node prompts, global prompts, first-sentence text, and task prompts on calls.
2. **Never use guide content to write prompts.** The CLI includes built-in guides (`bland guide phone-tone`, etc.) that contain prompt-writing advice. These guides exist for human reference. You may read them to understand platform behavior, but you must never use them as templates or instructions to author prompt text yourself.
3. **Always validate before pushing.** Run `bland pathway validate` before every `bland pathway push`.
4. **Always test with `--verbose`.** When running `bland pathway chat`, always include `--verbose` unless the user explicitly says otherwise.
5. **Always use `--json` for programmatic output.** When parsing CLI output in scripts or pipelines, always append `--json`.
6. **Never create batches, buy numbers, or promote pathways without explicit user confirmation.** These actions cost money or affect production.
7. **Always check knowledge base status after scraping.** Processing is asynchronous. Verify with `bland knowledge status <id>` before referencing the KB.
8. **Always test tools with `--verbose` after changes.** This reveals the full HTTP cycle and catches integration issues.
9. **Use `bland guide <slug>` to understand platform architecture — never to generate prompt text.** The guides explain how nodes, edges, variables, and tools work. Use that knowledge for structural decisions only.

---

## Companion Document

For task-driven workflows (pulling call logs, building test cases, troubleshooting pathways with call data, running simulations), see **`bland-cli-workflows.md`**. That document tells you how to chain CLI commands to accomplish real tasks. This document is the command reference it depends on.
