# Personas

> Create unified AI agents that manage all your phone numbers and use cases. Build once, use everywhere.

## Overview

Personas are unified AI agents that handle all your use cases in one place. Instead of configuring each phone number separately, create a single intelligent persona that manages everything:

- **Smart Routing** — Automatically routes calls to the right pathways
- **Visual Builder** — Design identity, voice, behavior through visual interface
- **Version Management** — Test in draft, promote to production
- **Live Testing** — Chat with persona before going live
- **Phone Integration** — Apply persona to multiple phone numbers
- **API Compatible** — Use via `persona_id` parameter

## Getting Started

### Access Personas

Navigate to the **Personas** section in your Bland dashboard.

### Create Your First Persona

Click **Create Persona** to open the visual builder.

## Building Your Persona

### 1. General Configuration

Define identity, voice, and communication channels:

- **Identity** — Name, role, description
- **Voice Selection** — Choose from voices (June, Karl, Estella, etc.)
- **Language** — Select primary language
- **Background Noise** — Add ambient sounds (office-style with typing, chatter)
- **Modalities** — Configure channels:
  - Voice & Calls
  - SMS Messaging (coming soon)
  - Web Widget (coming soon)

### 2. Behavior Configuration

Configure conversational behavior and routing logic:

- **Global Prompt** — Describe overall behaviors, personality, motivations
- **Wait for Greeting** — Toggle to only begin speaking after caller says something
- **Interruption Threshold** — Adjust response timing (e.g., 500ms)
- **Conversational Pathways** — Set up intelligent routing rules with "+ Add routing"

### 3. Knowledge Integration

Connect to knowledge bases for intelligent retrieval:

- Toggle knowledge bases on/off
- Add more from library dropdown
- Link to knowledge base management

### 4. Analysis & Webhooks

Set up post-conversation analysis and webhook integrations:

- **Generate Summary** — Auto-create summaries with customizable prompt
- **Data Extraction** — Configure citation schemas (Enterprise only)
- **Webhook Integration** — URL and events to send during call

### 5. Version Management

Manage deployment lifecycle:

- **Draft vs Production** — Work in draft without affecting live calls
- **Changes Tracking** — Visual diff showing what changed
- **Promote to Production** — Deploy changes
- **Reset Draft** — Revert to match production
- **Version History** — Access previous versions

## Testing Your Persona

Use the built-in testing interface on the right side of the builder. Start web calls with yourself to test changes before going live.

## Phone Number Integration

Apply persona to phone numbers from the **Inbound Numbers** dashboard:

- **Direct Persona Assignment** — Apply persona to handle all inbound calls
- **Pathway Override** — Combine persona with specific pathway routing
- **Multiple Number Support** — Use same persona across different numbers

### Benefits

- **Consistent Experience** — Same personality regardless of which number the caller reaches
- **Centralized Management** — Update once, apply everywhere
- **Smart Routing** — Automatic pathway selection based on context
- **Unified Analytics** — Track performance across all numbers

## API Usage

Reference your persona in API calls using `persona_id`:

```json
{
  "phone_number": "+15551234567",
  "persona_id": "your_persona_id_here",
  "task": "Additional context or overrides"
}
```

### Finding Your Persona ID

```bash
curl -X GET "https://api.bland.ai/v1/personas" \
  -H "Authorization: YOUR_API_KEY"
```

Returns all personas with IDs. Copy the `id` field.

### Parameter Override Behavior

When using `persona_id`:
- Persona settings provide base configuration
- Additional parameters in request override defaults
- Flexible, context-specific customization while maintaining consistency

## CLI Commands

```bash
bland persona list                    # List all personas
bland persona get <id>                # Show persona details
bland persona create                  # Create interactively
bland persona update <id>             # Update a persona
bland persona delete <id>             # Delete a persona
bland persona promote <id>            # Promote draft to production
bland persona reset-draft <id>        # Reset draft to match production
bland persona gaps <id>               # View knowledge gaps from calls
```

## MCP Tools Access

```python
tools.bland_persona_list()
tools.bland_persona_get(persona_id="persona_xyz789")
```

## Best Practices

1. **Test before promoting** — Use the built-in testing interface
2. **Use version control** — Work in draft, promote when ready
3. **Review changes** — Check the visual diff before promoting
4. **Configure routing wisely** — Set up pathways to handle common scenarios
5. **Monitor analytics** — Track performance across all numbers using the persona

See full documentation at https://docs.bland.ai/tutorials/personas.md

## Companion Documents

- **[cli-commands.md](cli-commands.md)** — Full CLI reference
- **[mcp-tools.md](mcp-tools.md)** — MCP tool access
- **[tools.md](tools.md)** — Tools integration
- **[workflows/troubleshooting.md](../workflows/troubleshooting.md)** — Troubleshooting persona-related issues