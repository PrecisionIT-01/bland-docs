# Web Agent SDK

> Embed a Bland voice agent into any web application with secure, token-based authentication.

## Overview

Embed a Bland voice agent into any web application (React, Vanilla JS, or Node). The SDK handles secure authentication between your server and Bland, so your API key is never exposed to the browser.

**Install:** `npm install @blandsdk/client` (Node.js 18+, React 18+ required for React)

## How It Works

```
Browser Client  →  Your Server (Admin SDK)  →  Bland
Browser Client  →  Bland (once session token is obtained)
```

Your server creates a single-use session token using the Admin SDK. That token is handed to the browser, which uses the Webchat SDK to connect directly to Bland — no API key on the client.

## Creating Sessions (Server-Side)

Set up an endpoint on your server to mint session tokens:

```typescript
import { Bland } from '@blandsdk/client';

const bland = new Bland({
  admin: {
    apiKey: process.env.BLAND_API_KEY,
    endpoint: "https://api.bland.ai"
  },
  webchat: {}
});

// Express route example
app.post("/api/agent-authorize", async (req, res) => {
  const { agentId } = req.body;
  const admin = await bland.AdminClient();
  const session = await admin.sessions.create({ agentId });
  res.json({ token: session.token });
});
```

**Important:** Never expose your API key on the client side. Always create session tokens server-side.

## Starting a Conversation (Client-Side, React)

Use the `useWebchat` hook:

```typescript
import { useWebchat } from "@blandsdk/client/react";

function AgentWidget({ agentId }) {
  const { state, start, stop, webchat } = useWebchat({
    agentId,
    getToken: async () => {
      const res = await fetch("/api/agent-authorize", {
        method: "POST",
        body: JSON.stringify({ agentId }),
        headers: { "Content-Type": "application/json" },
      });
      const { token } = await res.json();
      return token;
    },
  });

  webchat?.on("message", (msg) => {
    console.log("New message:", msg);
  });

  return (
    <div>
      <p>Status: {state}</p>
      <button onClick={start}>Start</button>
      <button onClick={stop}>Stop</button>
    </div>
  );
}
```

## Conversation Events

| Event | Description |
|-------|-------------|
| `open` | Connection established |
| `message` | New message received |
| `update` | Conversation state updated |
| `closed` | Connection closed |

## Companion Documents

- **[cli-commands.md](cli-commands.md)** — Full CLI reference
- **[setup/installation.md](../setup/installation.md)** — CLI installation and auth
- **[reference/personas.md](personas.md)** — Personas for agent configuration