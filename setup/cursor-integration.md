# Cursor Integration with Bland MCP

This document explains how to configure Cursor to use the Bland MCP server, enabling AI-powered interaction with your Bland account directly from Cursor.

**Prerequisite:** Complete [installation.md](installation.md) first.

---

## How It Works

The Bland CLI includes a built-in MCP (Model Context Protocol) server. When configured in Cursor, this server exposes tools that let Cursor:

- Pull call logs and transcripts
- List and retrieve pathway information
- Test pathway nodes
- Manage personas
- Interact with your Bland account without leaving Cursor

---

## Installing Bland CLI on Cursor's Machine

Cursor runs the MCP server using commands defined in its configuration. You have two options:

### Option 1: Use `npx` (recommended)

Cursor can run `npx bland-cli mcp` directly — no global installation required. This works because `npx` downloads and runs the package on each invocation.

### Option 2: Global install (faster, more reliable for frequent use)

If you already installed globally as described in [installation.md](installation.md), Cursor can use the installed binary directly:

**macOS/Linux:**
```bash
/Users/YOUR_USERNAME/.local/bin/bland mcp
```

**Windows:**
```bash
%LOCALAPPDATA%\bland-cli\bland.exe mcp
```

Replace `YOUR_USERNAME` with your actual macOS/Linux username.

---

## Cursor MCP Configuration

### Step 1: Create `.cursor/mcp.json`

In your project root, create the `.cursor` directory (if it doesn't exist) and add `mcp.json`:

```bash
mkdir -p .cursor
touch .cursor/mcp.json
```

### Step 2: Add Bland MCP configuration

The configuration is the same whether you use `npx` or a global install — just change the `command` value.

**Using npx (no global install needed):**

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

**Using global install (replace path as needed):**

```json
{
  "mcpServers": {
    "bland": {
      "command": "/Users/YOUR_USERNAME/.local/bin/bland",
      "args": ["mcp"]
    }
  }
}
```

Replace `/Users/YOUR_USERNAME/.local/bin/bland` with the actual path to your `bland` binary.

**Find your path:**

```bash
which bland
```

### Step 3: Restart Cursor

Close Cursor completely and reopen it. It will read the `mcp.json` configuration and attempt to start the MCP server.

---

## Verifying MCP Connection

After restarting Cursor:

1. Open **Cursor Settings → MCP** (or look for MCP status in the sidebar)
2. You should see the "bland" server listed with a **Connected** status

If the server fails to connect:
- Check the terminal output for errors
- Verify your command path is correct
- Test the command in a standalone terminal first

**Test standalone:**

```bash
# Using npx
npx bland-cli mcp

# Using global install
bland mcp
```

If the command fails to run or shows errors, fix those before attempting cursor integration again.

---

## Authentication

The MCP server uses the same credentials as the CLI curses:

1. **If you ran `bland auth login`**: The stored profile is used automatically
2. **If you set `BLAND_API_KEY` environment variable**: The MCP server inherits it from Cursor's environment

For Cursor, the simplest approach is to use the stored profile from `bland auth login`. If the MCP server fails with auth errors, verify authentication:

```bash
bland auth whoami
```

If this fails, re-authenticate:

```bash
bland auth login --key YOUR_API_KEY_HERE
```

---

## Available MCP Tools

Once connected, Cursor can use these tools directly in conversations:

| Tool | Description | Equivalent CLI Command |
|------|-------------|----------------------|
| `bland_guide_list` | List all available guides | `bland guide` |
| `bland_guide_get` | Read a specific guide by slug | `bland guide <slug>` |
| `bland_call_send` | Make a phone call | `bland call send` |
| `bland_call_list` | List recent calls | `bland call list` |
| `bland_call_get` | Get call details and transcript | `bland call get` |
| `bland_pathway_list` | List pathways | `bland pathway list` |
| `bland_pathway_get` | Get pathway details | `bland pathway get` |
| `bland_pathway_create` | Create a pathway from nodes/edges | `bland pathway create` |
| `bland_pathway_chat` | Chat with a pathway | `bland pathway chat` |
| `bland_pathway_node_test` | Test a single node | `bland pathway node test` |
| `bland_persona_list` | List personas | `bland persona list` |
| `bland_persona_get` | Get persona details | `bland persona get` |
| `bland_number_list` | List phone numbers | `bland number list` |
| `bland_number_buy` | Buy a phone number | `bland number buy` |
| `bland_voice_list` | List available voices | `bland voice list` |
| `bland_tool_test` | Test a custom tool | `bland tool test` |
| `bland_knowledge_list` | List knowledge bases | `bland knowledge list` |
| `bland_audio_generate` | Generate TTS audio | `bland audio generate` |

---

## Using MCP Tools in Cursor

You can ask Cursor to use these tools in natural language:

> "Pull the last 10 calls and show me their status"
> "Get pathway pw_abc123 and summarize its structure"
> "Test the greeting node in pathway pw_def456"
> "List all personas"

Cursor will:
1. Choose the appropriate MCP tool
2. Execute it with the right parameters
3. Present the results in the conversation

---

## When to Use MCP Tools vs CLI Commands

**Use MCP tools when:**
- You need a single call-and-response (pull a call, list pathways, get details)
- You're already in Cursor and don't want to switch to a terminal
- The operation doesn't require file I/O

**Use CLI commands (via terminal) when:**
- You need file I/O — pulling a pathway as YAML (`pathway pull`), downloading recordings
- The operation requires flags the MCP server doesn't expose
- You're running complex workflows or chains of commands
- You need auto-commit behavior for testing

**Not exposed via MCP:**
- `pathway pull`, `pathway push`, `pathway diff`, `pathway validate`, `pathway watch`
- `pathway simulate run/get` (simulations)
- `pathway test` (automated testing)
- `call events`, `call recording --download`
- `batch` operations
- `sms` operations

For these, use the CLI directly in your terminal.

---

## Project-Level .env Usage

Some workspaces invoke the CLI via `npm run bland` with a `.env` file (loaded by `dotenv`) instead of a global `bland` command. In Cursor MCP config, you can still use `npx` or the global binary — authentication works the same regardless.

If your project uses `npm run bland` pattern for CLI commands, you may adapt the MCP config accordingly, but `npx bland-cli mcp` or `bland mcp` are the standard approaches.

---

## Troubleshooting

### "Command not found" error

- Verify the `command` path in `.cursor/mcp.json` is correct
- Run the command in a standalone terminal to test it
- If using `npx`, verify internet connectivity (it needs to download)

### Authentication errors

- Run `bland auth whoami` in a terminal to verify authentication
- Re-authenticate with `bland auth login --key <your_key>`
- Check that the API key is valid and active in your Bland dashboard

### MCP server won't start

- Check Cursor's output logs for error messages
- Try running the MCP command in a standalone terminal first
- Verify Node.js 18+ is installed (`node -v`)

### Tools not available in Cursor

- Restart Cursor completely (not just reload the window)
- Check that the MCP server shows "Connected" in Settings → MCP
- Verify `.cursor/mcp.json` is valid JSON (no trailing commas)

---

## Next Steps

- **CLI Reference:** See [cli-commands.md](../reference/cli-commands.md) for complete command documentation.
- **Workflows:** See [troubleshooting.md](../workflows/troubleshooting.md) for how to pull call data and diagnose issues.
- **Testing:** See [testing.md](../workflows/testing.md) for building test cases and running simulations.