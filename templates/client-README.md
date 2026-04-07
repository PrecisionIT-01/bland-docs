# Bland AI Documentation - {{CLIENT_NAME}}

Operational documentation for working with Bland AI's CLI, MCP server, and related tools.

---

## Quick Start

### 1. Set Up Credentials

```bash
# Copy the example file
cp .env.example .env

# Edit with your credentials (already configured)
# .env is gitignored - your keys are safe
```

### 2. Install the CLI

```bash
npm install -g bland-cli
# or run without installing: npx bland-cli
```

### 3. Authenticate

```bash
bland auth login --key $BLAND_API_KEY
# or: export BLAND_API_KEY=your_key_here
```

### 4. Verify

```bash
bland auth whoami
```

---

## What You Can Do

### Pull Call Logs

```bash
# List recent calls
bland call list

# Get specific call details with transcript
bland call get <call_id> --json

# View call events (node transitions)
bland call events <call_id> --json

# Download recording
bland call recording <call_id> --download
```

### Work with Pathways

```bash
# List all pathways
bland pathway list

# Get pathway structure
bland pathway get <pathway_id>

# Pull pathway as YAML for review
bland pathway pull <pathway_id> ./

# Chat with a pathway (testing)
bland pathway chat <pathway_id> --verbose

# Test a specific node
bland pathway node test <pathway_id> <node_id>
```

### Run Simulations

```bash
# Simulate a call against a pathway
bland pathway simulate run <pathway_id> \
  --persona "A customer calling about billing" \
  --instructions "Ask about recent charges, accept explanation" \
  --wait \
  --json

# Get simulation results
bland pathway simulate get <simulation_id> --json
```

### Manage Calls

```bash
# Send a test call
bland call send +15551234567 \
  --pathway <pathway_id> \
  --voice nat \
  --wait

# Stop an active call
bland call stop <call_id>
```

---

## Cursor Integration (MCP)

This repo includes MCP (Model Context Protocol) configuration for Cursor.

### Setup

1. Create `.cursor/mcp.json` in your project:

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

2. Restart Cursor

3. MCP tools are now available in Cursor conversations

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `bland_call_list` | List recent calls |
| `bland_call_get` | Get call details + transcript |
| `bland_pathway_list` | List pathways |
| `bland_pathway_get` | Get pathway structure |
| `bland_pathway_chat` | Test a pathway |
| `bland_persona_list` | List personas |
| `bland_voice_list` | List voices |

See [setup/cursor-integration.md](setup/cursor-integration.md) for full details.

---

## Documentation Structure

```
setup/
  installation.md        # CLI installation and auth
  cursor-integration.md  # MCP setup for Cursor

reference/
  cli-commands.md        # Full CLI command reference
  mcp-tools.md           # MCP tools list and usage
  tools.md               # Tools v2 integration
  webhooks.md            # Webhook node config
  personas.md            # Personas configuration

workflows/
  troubleshooting.md     # Diagnose call/pathway issues
  testing.md             # Test cases and simulations
  daily-tasks.md         # Common operations
```

---

## Common Tasks

### Troubleshooting a Failed Call

1. Get the call ID
2. Pull call details: `bland call get <id> --json`
3. Review transcript and variables
4. Check events: `bland call events <id> --json`
5. Compare against pathway: `bland pathway get <pathway_id>`

See [workflows/troubleshooting.md](workflows/troubleshooting.md) for detailed workflows.

### Creating Test Cases

1. Pull the pathway: `bland pathway pull <id> ./`
2. Review nodes and edges
3. Create test cases in `tests/test-cases.yaml`
4. Run: `bland pathway test <id>`

See [workflows/testing.md](workflows/testing.md) for details.

### Daily Operations

- Check recent calls: `bland call list --status completed`
- Review failed calls: `bland call list --status failed`
- Get call for debugging: `bland call get <id> --json`

See [workflows/daily-tasks.md](workflows/daily-tasks.md) for more.

---

## Environment Variables

```bash
BLAND_API_KEY      # Your API key (required)
BLAND_ORG_ID       # Organization ID (if applicable)
PLANHAT_ID         # Planhat reference (internal)
SLACK_CHANNEL      # Associated Slack channel
```

---

## Links

- **Bland Dashboard:** https://app.bland.ai/dashboard
- **API Docs:** https://docs.bland.ai
- **CLI Reference:** [reference/cli-commands.md](reference/cli-commands.md)