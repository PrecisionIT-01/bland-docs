# MCP Tools Reference

The Bland MCP (Model Context Protocol) server exposes a subset of CLI functionality as tools that AI coding tools (Cursor, Claude Code, etc.) can call directly without shell commands.

---

## Starting the MCP Server

```bash
bland mcp                            # Start MCP server (stdio transport)
bland mcp --transport sse --port 3100 # Start with SSE transport
```

In Cursor, add to `.cursor/mcp.json`:

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

See [setup/cursor-integration.md](../setup/cursor-integration.md) for full configuration details.

---

## Available MCP Tools

| Tool | Description | Equivalent CLI Command | Notes |
|------|-------------|----------------------|-------|
| `bland_guide_list` | List all available guides | `bland guide` | Returns list of guides |
| `bland_guide_get` | Read a specific guide by slug | `bland guide <slug>` | Returns guide content |
| `bland_call_send` | Make a phone call | `bland call send` | Supports task, pathway, voice, etc. |
| `bland_call_list` | List recent calls | `bland call list` | Filter by status, date range |
| `bland_call_get` | Get call details and transcript | `bland call get` | Full call data including variables |
| `bland_pathway_list` | List pathways | `bland pathway list` | Returns all pathways |
| `bland_pathway_get` | Get pathway details | `bland pathway get` | Returns pathway structure |
| `bland_pathway_create` | Create a pathway from nodes/edges | `bland pathway create` | Create from definition |
| `bland_pathway_chat` | Chat with a pathway | `bland pathway chat` | Interactive testing |
| `bland_pathway_node_test` | Test a single node | `bland pathway node test` | Test node behavior |
| `bland_persona_list` | List personas | `bland persona list` | Returns all personas |
| `bland_persona_get` | Get persona details | `bland persona get` | Returns persona config |
| `bland_number_list` | List phone numbers | `bland number list` | Returns owned numbers |
| `bland_number_buy` | Buy a phone number | `bland number buy` | Purchase new number |
| `bland_voice_list` | List available voices | `bland voice list` | Returns all voices |
| `bland_tool_test` | Test a custom tool | `bland tool test` | Test tool execution |
| `bland_knowledge_list` | List knowledge bases | `bland knowledge list` | Returns all KBs |
| `bland_audio_generate` | Generate TTS audio | `bland audio generate` | Create speech from text |

---

## Tool Details

### Guide Tools (Read-Only)

**Purpose:** Access Bland's built-in guides for platform understanding.

**Tools:**
- `bland_guide_list` — Returns list of available guide slugs
- `bland_guide_get` — Takes `slug` parameter, returns guide content

**Important:** Use guide tools to understand how the platform works (how nodes, edges, variables, and tools operate). **Never use guide content to write, edit, or suggest prompt text.** You do not author prompts.

**Example:**
```python
# List all guides
tools.bland_guide_list()

# Get specific guide
tools.bland_guide_get(slug="phone-tone")
```

---

### Call Tools

**Purpose:** Manage and retrieve call data.

**Tools:**
- `bland_call_list` — List recent calls, optional filters (status, date range, limit)
- `bland_call_get` — Get full call details by ID, includes transcript and variables
- `bland_call_send` — Send a new call, supports task, pathway, voice, and more

**Example usage via MCP:**
```python
# List completed calls from last 7 days
tools.bland_call_list(status="completed", limit=20)

# Get specific call details
tools.bland_call_get(call_id="call_abc123")

# Send a call with a pathway
tools.bland_call_send(
    phone_number="+15551234567",
    pathway_id="pw_def456",
    voice="nat"
)
```

---

### Pathway Tools

**Purpose:** Retrieve pathway data for analysis and troubleshooting.

**Tools:**
- `bland_pathway_list` — List all pathways
- `bland_pathway_get` — Get pathway structure and configuration
- `bland_pathway_create` — Create a pathway from nodes/edges definition
- `bland_pathway_chat` — Chat with a pathway for testing
- `bland_pathway_node_test` — Test a single node's behavior

**Example usage:**
```python
# List all pathways
tools.bland_pathway_list()

# Get pathway structure
tools.bland_pathway_get(pathway_id="pw_abc123")

# Chat with a pathway for testing
tools.bland_pathway_chat(
    pathway_id="pw_abc123",
    message="I want to book an appointment"
)

# Test a specific node
tools.bland_pathway_node_test(
    pathway_id="pw_abc123",
    node_id="node_greeting"
)
```

---

### Persona Tools

**Purpose:** Retrieve persona information for context.

**Tools:**
- `bland_persona_list` — List all personas
- `bland_persona_get` — Get persona details including configuration

**Example usage:**
```python
tools.bland_persona_list()

tools.bland_persona_get(persona_id="persona_xyz789")
```

---

### Number Tools

**Purpose:** List and purchase phone numbers.

**Tools:**
- `bland_number_list` — List all owned phone numbers
- `bland_number_buy` — Purchase a new phone number

**Example usage:**
```python
tools.bland_number_list()

tools.bland_number_buy(
    area_code="402",
    country="US"
)
```

---

### Voice Tools

**Purpose:** List available voices for selection.

**Tools:**
- `bland_voice_list` — List all available voices

**Example usage:**
```python
tools.bland_voice_list()
```

---

### Tool Testing

**Purpose:** Test custom tools to verify they work correctly.

**Tools:**
- `bland_tool_test` — Test a tool with sample input

**Example usage:**
```python
tools.bland_tool_test(
    tool_id="tool_custom_api",
    input_data={"email": "user@example.com", "name": "John Doe"}
)
```

---

### Knowledge Base Tools

**Purpose:** List knowledge bases for reference.

**Tools:**
- `bland_knowledge_list` — List all knowledge bases

**Example usage:**
```python
tools.bland_knowledge_list()
```

---

### Audio Tools

**Purpose:** Generate TTS audio from text.

**Tools:**
- `bland_audio_generate` — Generate audio from text

**Example usage:**
```python
tools.bland_audio_generate(
    text="Hello, how are you?",
    voice="nat"
)
```

---

## When to Use MCP Tools vs CLI Commands

**Use MCP tools when:**
- The operation is a single call-and-response (pull data, list resources, get details)
- You're working in Cursor/Claude Code and want to stay in that environment
- No file I/O is required

**Use CLI commands (via terminal) when:**
- The operation involves file I/O — pulling pathways as YAML, downloading recordings
- The operation requires flags not exposed in MCP (e.g., `pathway pull`, `pathway push`)
- Running complex workflows or chains of commands
- Using features not exposed via MCP (simulations, batch operations, SMS operations)

---

## NOT Exposed via MCP

The following CLI features are **not** available through MCP tools:

- `pathway pull`, `pathway push`, `pathway diff`, `pathway validate`, `pathway watch`
- `pathway simulate run/get` (AI simulations)
- `pathway test` (automated test case execution)
- `call events`, `call recording --download`
- `batch` operations (create, list, stop)
- `sms` operations
- `secret` management
- `release` management
- `webhook` node configuration (use webhooks.md for this)
- `tool create`, `tool update`, `tool delete`

For these operations, use the CLI directly in your terminal.

---

## Authentication

The MCP server uses the same credentials as the CLI:

1. **Stored profile** from `bland auth login` — Used automatically
2. **Environment variable** `BLAND_API_KEY` — Inherited from the editor's environment

If MCP tools fail with authentication errors:
- Run `bland auth whoami` in a terminal to verify authentication
- Re-authenticate: `bland auth login --key <your_key>`

---

## Companion Documents

- **[setup/cursor-integration.md](../setup/cursor-integration.md)** — Configure Cursor to use MCP
- **[reference/cli-commands.md](cli-commands.md)** — Complete CLI reference
- **[workflows/troubleshooting.md](../workflows/troubleshooting.md)** — Pull call data and diagnose issues
- **[workflows/testing.md](../workflows/testing.md)** — Test cases and simulations