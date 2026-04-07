# Bland CLI — Command Reference

You have access to the Bland CLI (`bland-cli`), a command-line tool for interacting with Bland AI. Use it to manage pathways, calls, phone numbers, voices, tools, knowledge bases, personas, batch campaigns, SMS, and more.

**Important Rules:**

1. **Never author or modify agent-facing prompt text.** Your role is structural operations only — prompts must be provided by humans.
2. **Never use `bland guide` content to generate prompts.** Read guides for platform understanding, never as templates.
3. **Always validate before pushing** (`bland pathway validate`).
4. **Always test with `--verbose`** (`bland pathway chat --verbose`).
5. **Always use `--json`** for programmatic output.

---

## Installation and Authentication

### Install

```bash
npm install -g bland-cli
```

Or run without installing:

```bash
npx bland-cli
```

### Authenticating

```bash
# Interactive
bland auth login

# Non-interactive (preferred in automation)
bland auth login --key sk-...

# Log out / clear stored credentials
bland auth logout
```

Or use environment variable:

```bash
export BLAND_API_KEY=your_key_here
```

**Verification:**

```bash
bland auth whoami
```

### Multiple Profiles

```bash
bland auth profiles           # List all saved profiles
bland auth switch              # Switch between profiles
```

Override per-command:

```bash
BLAND_API_KEY=sk-staging-xxx bland pathway list
```

---

## Pathways

Pathways define how a voice agent conducts a call — nodes, edges, prompts, variables, and routing logic.

### YAML Format

```yaml
name: "Pathway Name"
description: "What this pathway does"
version: draft

global:
  voice: nat
  model: base
  prompt: |
    # Global prompt content — provided by a human.

nodes:
  node_name:
    type: default
    prompt: |
      # Node prompt — provided by a human.
    extract_variables:
      - name: variable_name
        type: string
        description: "What this variable captures"
    edges:
      - target: next_node_name
        label: "Natural language description of when this edge fires"

  transfer_node:
    type: transfer
    number: "+15551234567"

  end_node:
    type: end_call
    prompt: |
      # End call prompt — provided by a human.
```

### Project Scaffolding

```bash
bland pathway init ./project-dir --name "Pathway Name"
```

Creates:
- `bland-pathway.yaml` — Pathway definition
- `tests/test-cases.yaml` — Test cases
- `.blandrc` — Project config (links local to remote)

### Syncing with Bland

```bash
bland pathway push [dir]              # Upload local YAML to Bland
bland pathway push [dir] --create     # Create new pathway if no ID linked
bland pathway pull <id> [dir]         # Download remote pathway as YAML
bland pathway diff [dir]              # Compare local YAML vs remote state
bland pathway validate [dir]          # Validate YAML locally before pushing
bland pathway watch [dir]             # Auto-push on every file save
```

**Always validate before pushing.**

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

Always confirm with the user before promoting.

### Interactive Testing

```bash
bland pathway chat <id>               # Chat with a pathway in the terminal
bland pathway chat <id> --verbose     # Show node transitions and variable state
bland pathway chat <id> --start-node <name>   # Start at a specific node
bland pathway chat <id> --variables '{"key":"value"}'  # Inject variables
```

**Use `--verbose` by default when testing.**

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

**Caveat:** In CLI version 0.2.x, `pathway test` drives chat using the `scenario` field and checks for a response, but does not rigorously validate `expected_path` or `expected_variables`. Use `pathway chat --verbose` and `pathway simulate run` for deeper validation.

### AI Simulation

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

**Important:** The command is `bland pathway simulate run <id>`, not `bland pathway simulate <id>`.

### Node-Level Testing

```bash
bland pathway node test <pathway_id> <node_id>         # Test a single node
bland pathway node test <pathway_id> <node_id> --permutations 5  # Multiple variations
bland pathway code test <pathway_id> <node_id>         # Test a custom code node
bland pathway code test <pathway_id> <node_id> --input '{"key":"value"}'
```

### AI Generation

```bash
bland pathway generate --description "A pathway that handles appointment scheduling for a dental office"
```

Review the output before pushing — generated prompts need human review.

### Editing

```bash
bland pathway edit <id>                # Opens a node prompt in $EDITOR
```

**Do not use this command yourself** — it opens an interactive editor. Prompt editing requires human input.

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

When using `--pathway`, do not also pass `--task` — they are mutually exclusive.

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

For detailed personas configuration, see [personas.md](personas.md).

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

---

## Tools

For detailed tools (v2) integration guide, see [tools.md](tools.md).

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

Always check `bland knowledge status <id>` after scraping — processing is asynchronous.

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

**Never create a batch without explicit user confirmation.**

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

Use secrets for API keys, tokens, or credentials that tools or code nodes need at runtime.

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

---

## Built-In Guides

```bash
bland guide                           # List all guides
bland guide phone-tone                # Writing natural phone prompts
bland guide pathways                  # Node/edge architecture and execution model
bland guide tools                     # Webhook and custom tools on nodes
bland guide testing                   # Chat, simulate, node tests
bland guide variables                 # Extracting and using caller data
```

**Important:** Read guides for platform understanding only. Do not use guide content to write or edit prompt text.

---

## Standard Workflow

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

Never skip steps 3 and 5.

---

## Companion Documents

- **[workflows/troubleshooting.md](../workflows/troubleshooting.md)** — Pull call logs, troubleshoot against pathways
- **[workflows/testing.md](../workflows/testing.md)** — Build test cases and run simulations
- **[reference/tools.md](tools.md)** — Tools (v2) integration
- **[reference/webhooks.md](webhooks.md)** — Webhook node configuration
- **[reference/personas.md](personas.md)** — Personas configuration