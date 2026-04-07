# Tools (v2) — Integration Guide

This document covers the Tools v2 system for giving your AI agent the ability to take actions during live calls.

## Overview

Tools let your agent take real actions during calls:

- Schedule meetings on Cal.com
- Create contacts in Salesforce
- Send Slack messages
- Call your own API to check status or update databases

## Tools vs Custom Tools (Legacy)

| Feature | Custom Tools (Legacy) | Tools (v2) |
|---------|----------------------|-----------|
| Configuration | Raw JSON, manual HTTP | Visual Tool Builder |
| Integrations | Build yourself | Pre-built + custom API |
| Authentication | Manual headers | Managed OAuth |
| Field Input | Static only | Agent/Linked/Manual Mode |
| Response Handling | Manual parsing | Visual variable extraction |
| Pathway Variables | Not supported | Link to variables |
| Tool Logs | None | Full execution logs |

## The Tools Hub

Access at **[Tools Hub](https://app.bland.ai/dashboard/tools)**

- **Tools** — Your created tools
- **Connections** — Authenticated links to services
- **Integrations** — Browse and create connections
- **Analytics** — Execution logs and metrics

## Creating a Tool

1. **Set Up a Connection** — Connect to the service (OAuth for third-party, base URL + auth for custom APIs)
2. **Choose an Action** — Select what the tool does (POST, GET, Create Contact, etc.)
3. **Configure the Tool** — Four sections: Integration, Prompting, Action Parameters, Response Variables
4. **Add to Pathway** — Use the tool in your conversational pathway

## Parameter Modes

**Agent Mode** — The AI fills this field by extracting from the conversation (what the caller says).

**Manual Mode** — You set a fixed value that never changes.

**Linked Mode** — System variables like `{{phone_number}}` and `{{call_id}}` are available automatically.

## Response Modes

**Capture Response** — Waits for response, captures data. Use when you need confirmation or result data.

**Fire and Forget** — Sends request but doesn't wait. Use when speed is critical or you don't need confirmation.

## Response Routing

Route your pathway based on tool results:

| If | Condition | Value | Then Go To |
|----|-----------|-------|------------|
| `ok` | equals | `true` | Confirmation Node |
| `ok` | equals | `false` | Error Handler |

Available conditions: `==`, `!=`, `>`, `<`, `contains`, `is null`, `is not null`

## CLI Access

```bash
bland tool list                       # List all tools
bland tool get <id>                   # Show tool details
bland tool create                     # Create interactively
bland tool update <id>                # Update a tool
bland tool delete <id>                # Delete a tool
bland tool test <id>                  # Test a tool
bland tool test <id> --input '{"key":"value"}'  # Test with specific input
bland tool test <id> --verbose        # Show full request/response
```

Always test tools with `--verbose` after changes.

## Custom API Integration

To integrate with your own backend:

1. Go to **Tools Hub → Integrations → API → Add Connection**
2. Set **Base URL** (e.g., `https://api.bland.ai`)
3. Choose **Authentication** (Bearer Token, API Key, Basic Auth, or None)
4. Store API keys in **Secrets** for security
5. Create a **POST** or **GET** tool action
6. Configure **URL Path** (appended to base URL, e.g., `/v1/prompts`)
7. Add **Variables** to the body (name, description, type, required)
8. Use reference syntax: `{{input.userName}}` in the request body

See [v2-tools-custom-api.md](https://docs.bland.ai/tutorials/v2-tools-custom-api.md) for full tutorial.

## Tools with Personas

1. Add tool to Persona's tool list
2. The agent reads the tool's prompt
3. When triggered, agent fills Agent Mode fields from conversation
4. Linked Mode fields use system variables automatically
5. Manual Mode fields use your static values

## Tools with Pathways

1. Extract variables in earlier nodes using Variable Extraction
2. Add a **Custom Tool node** to your pathway
3. In the **Fields** section, select which pathway variables to use for each input
4. The tool runs when the pathway reaches that node

In Pathways, link extracted variables to tool fields — the agent doesn't fill them automatically.

## Monitoring

- **Analytics Panel** — Shows execution logs, error rates, performance metrics
- **Tool Logs in Call View** — See exactly what was sent, what came back, and the result

## API Reference

```bash
# Manage tools programmatically
curl -X POST "https://api.bland.ai/v2/tools" \
  -H "Authorization: YOUR_API_KEY" \
  -d '{ ... }'

curl -X GET "https://api.bland.ai/v2/tools" \
  -H "Authorization: YOUR_API_KEY"

curl -X POST "https://api.bland.ai/v2/tools/<tool_id>" \
  -H "Authorization: YOUR_API_KEY" \
  -d '{ ... }'
```

## Companion Documents

- **[cli-commands.md](cli-commands.md)** — Full CLI reference with tool commands
- **[webhooks.md](webhooks.md)** — Webhook node configuration
- **[mcp-tools.md](mcp-tools.md)** — MCP tool access
- **[workflows/testing.md](../workflows/testing.md)** — Testing tools in pathways