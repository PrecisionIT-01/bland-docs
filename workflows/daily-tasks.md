# Daily Tasks — Common Workflows

This document covers common, repetitive tasks you'll perform regularly when working with Bland.

## Pull Call Data for a Specific Call

### Task

You have a call ID and need to see what happened.

### Commands

```bash
# Get full call details and transcript
bland call get <call_id> --json

# Get call events for node transitions
bland call events <call_id> --json

# Get recording URL (if recorded)
bland call recording <call_id>

# Download recording locally
bland call recording <call_id> --download
```

### Output Analysis

After pulling call data:
- Check `status` (completed, failed, active)
- Review `transcripts` for conversation content
- Examine `variables` extracted during call
- Look at `events` for node traversal path
- Note any `errors` or warnings

## Pull Multiple Call IDs

### Task

You have a list of call IDs and need to review them all.

### Commands

```bash
# Pull each call in turn
bland call get call_abc123 --json
bland call get call_def456 --json
bland call get call_ghi789 --json

# Or process via script (example)
for call_id in call_abc123 call_def456 call_ghi789; do
  echo "=== $call_id ==="
  bland call get "$call_id" --json | jq '{status, duration, variables}'
  echo ""
done
```

## List Recent Calls with Filters

### Task

Need to see recent calls, maybe filtered by status or date.

### Commands

```bash
# List recent 20 calls
bland call list

# List more calls
bland call list --limit 50

# Filter by status
bland call list --status completed
bland call list --status failed
bland call list --status active

# Filter by date range
bland call list --from 2025-01-01 --to 2025-01-31

# Only inbound calls
bland call list --inbound

# Filter by batch campaign
bland call list --batch batch_xyz789

# Get structured output
bland call list --json | jq '.[] | {call_id: .id, status: .status, phone_number: .to}'
```

## Pull Pathway structure

### Task

Need to see a pathway's node/edge structure for troubleshooting or analysis.

### Commands

```bash
# Pull pathway as YAML to local directory
bland pathway pull <pathway_id> ./pathway-review

# View the YAML
cat ./pathway-review/bland-pathway.yaml

# Get pathway details as JSON (for programmatic path analysis)
bland pathway get <pathway_id> --json

# List all pathways
bland pathway list

# List with structured output
bland pathway list --json | jq '.[] | {id, name, version}'
```

## Get Pathway Versions

### Task

Need to see what versions of a pathway exist, often before pulling.

### Commands

```bash
# List all versions
bland pathway versions <pathway_id> --json

# Pull specific version (not directly via CLI, use get to see details)
```

## List Personas

### Task

Need to see what personas exist in the account.

### Commands

```bash
# List all personas
bland persona list

# Get structured output
bland persona list --json | jq '.[] | {id, name, status}'

# Get specific persona details
bland persona get <persona_id>

# Or via MCP
tools.bland_persona_list()
tools.bland_persona_get(persona_id="persona_xyz789")
```

## List Phone Numbers

### Task

Need to see what phone numbers are owned and their configuration.

### Commands

```bash
# List all numbers
bland number list

# Get structured output
bland number list --json | jq '.[] | {phone_number, pathway, persona, friendly_name}'

# View configuration for specific number
bland number get <phone_number>

# Configure number interactively
bland number configure <phone_number>
```

## List Voices

### Task

Need to see available voices for selection.

### Commands

```bash
# List all voices
bland voice list

# Filter by language
bland voice list --language es

# Show only custom/cloned voices
bland voice list --custom

# Test a voice
bland voice speak "Hello, how are you?" --voice nat -o test.mp3
```

## Test a Single Node

### Task

Need to test a specific node's behavior in isolation.

### Commands

```bash
# Test a node
bland pathway node test <pathway_id> <node_id>

# Test with multiple permutations
bland pathway node test <pathway_id> <node_id> --permutations 5

# Test with specific input
bland pathway node test <pathway_id> <node_id> --input '{"phone":"+15551234567","email":"user@example.com"}'

# Test custom code node
bland pathway code test <pathway_id> <node_id>
bland pathway code test <pathway_id> <node_id> --input '{"user_age": 30}'
```

## Quick Pathway Chat Test

### Task

Need to quickly test a pathway's behavior from the terminal.

### Commands

```bash
# Chat with pathway (always use --verbose)
bland pathway chat <pathway_id> --verbose

# Start at specific node
bland pathway chat <pathway_id> --start-node <node_name>

# Inject initial variables
bland pathway chat <pathway_id> \
  --verbose \
  --variables '{"account_number": "12345", "account_type": "billing"}'
```

## Validate Pathway Locally

### Task

Before pushing changes, validate the YAML to catch errors early.

### Commands

```bash
# Validate pathway YAML
bland pathway validate ./pathway-directory

# Validate the current directory (if it has bland-pathway.yaml)
bland pathway validate .
```

## Push Pathway Changes

### Task

Need to update a pathway with local changes.

### Commands

```bash
# Step 1: Always validate first
bland pathway validate .

# Step 2: Push changes
bland pathway push .

# Step 3: If creating new pathway
bland pathway push . --create

# Step 4: After push, test
bland pathway chat <pathway_id> --verbose
```

## Check Authentication Status

### Task

Need to verify you're authenticated and which profile is active.

### Commands

```bash
# Check who you are
bland auth whoami

# List all profiles
bland auth profiles

# Switch profiles
bland auth switch
```

## Quick MCP Connection Test

### Task

Need to verify MCP server is working (especially after Cursor setup).

### Commands

```bash
# Test MCP server starts (it will hang, that's normal)
bland mcp

# Or move it to background to verify no errors
bland mcp &
sleep 2
jobs  # Should show the job running
```

If errors appear, fix them before using in Cursor.

## Send a Test Call

### Task

Need to test a pathway with a test call.

### Commands

```bash
# Send a call with numeros pathway
bland call send +15551234567 \
  --pathway <pathway_id> \
  --voice nat \
  --wait \
  --record

# Send a simple task call
bland call send +15551234567 \
  --task "Call and collect basic information" \
  --voice josh \
  --wait
```

**Confirm with user before sending calls** — real calls cost money and use credits.

## Download Multiple Recordings

### Task

Need to download several call recordings.

### Commands

```bash
# Download each recording
bland call recording call_abc123 --download
bland call recording call_def456 --download

# Or batch download
for call_id in call_abc123 call_def456 call_ghi789; do
  echo "Downloading $call_id..."
  bland call recording "$call_id" --download --output "${call_id}.mp3"
done
```

## Batch Test Cases (Basic)

### Task

Run all test cases for a pathway.

### Commands

```bash
# Run test cases from .blandrc
bland pathway test <pathway_id>

# Run specific test file
bland pathway test <pathway_id> --file tests/custom.yaml

# Get JSON output for processing
bland pathway test <pathway_id> --json | jq '.tests | length'
```

## Quick Environment Setup

### Task

Need to check if CLI is installed and authenticated.

### Commands

```bash
# Check if bland command exists
which bland

# If not, install with npx quickly
npx bland-cli --version

# Check authentication
bland auth whoami

# If not authenticated, prompt for key
echo "Need to run: bland auth login --key YOUR_API_KEY"
```

## Git Workflow for Pathway Changes

### Task

Making pathway changes and tracking them in git.

### Commands

```bash
# 1. Pull current pathway
bland pathway pull <pathway_id> ./my-pathway

# 2. Make edits to ./my-pathway/bland-pathway.yaml

# 3. Validate
bland pathway validate ./my-pathway

# 4. Push changes
bland pathway push ./my-pathway

# 5. Test
bland pathway chat <pathway_id> --verbose

# 6. Commit to git
git add ./my-pathway/
git commit -m "Updated pathway structure"
```

## Companion Documents

- **[troubleshooting.md](troubleshooting.md)** — Full diagnostic workflows
- **[testing.md](testing.md)** — Test cases and simulations
- **[cli-commands.md](../reference/cli-commands.md)** — Full CLI reference