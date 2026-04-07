# Bland CLI and MCP — Setup Steps

This document describes how the Bland CLI was installed and authenticated on this machine, and how to finish (or verify) MCP so Cursor can talk to Bland.

---

## Prerequisites

- **Node.js 18+** (this environment had Node v24.x and npm 11.x).
- A **Bland API key** (`sk-...`, `org_...`, or other prefix — the CLI accepts the format your account uses).

---

## Part 1 — Install the CLI

### Step 1: Check Node and npm

```bash
node -v
npm -v
```

### Step 2: Try a global install (optional)

```bash
npm install -g bland-cli
```

On many macOS setups this **fails** with `EACCES` when npm tries to write under `/usr/local/lib/node_modules`. If that happens, use a user-writable prefix (next step).

### Step 3: Install into `~/.local` (works without sudo)

```bash
mkdir -p "$HOME/.local"
npm install -g bland-cli --prefix "$HOME/.local"
```

The `bland` binary ends up at:

`~/.local/bin/bland`

### Step 4: Put `bland` on your `PATH`

If `command -v bland` returns nothing, prepend `~/.local/bin` to `PATH`.

**Example (zsh, login shells):** add to `~/.zprofile` (or `~/.zshrc` if you prefer):

```bash
# Bland CLI (npm install -g --prefix ~/.local)
export PATH="$HOME/.local/bin:$PATH"
```

Open a **new terminal** (or run `source ~/.zprofile`) so the change applies.

### Step 5: Verify the CLI

```bash
export PATH="$HOME/.local/bin:$PATH"   # if needed in the current shell
bland --version
bland auth whoami
```

---

## Part 2 — Authenticate

### Step 1: Log in with your API key (stores a profile)

```bash
bland auth login --key YOUR_API_KEY_HERE
```

You should see a success message and account summary (profile, balance, etc.).

### Step 2: Confirm stored credentials

```bash
bland auth whoami
```

### Alternative: environment variable only

You can skip interactive profile storage for scripts by exporting:

```bash
export BLAND_API_KEY=YOUR_API_KEY_HERE
bland auth whoami
```

---

## Part 3 — MCP server (Cursor / editors)

The same `bland-cli` package includes an MCP server. The CLI does **not** need a separate MCP install if `bland-cli` is already installed.

### Step 1: Confirm the MCP command runs

From a terminal (with `PATH` including `~/.local/bin` if you used that layout):

```bash
bland mcp
```

That starts the MCP server on **stdio** (typical for editor integration). It may appear to “hang”; that is normal when run alone — editors spawn it as a subprocess.

Optional SSE transport (for other clients):

```bash
bland mcp --transport sse --port 3100
```

### Step 2: Wire MCP into Cursor

1. Ensure `npx bland-cli mcp` works **or** that `bland mcp` is on your `PATH` (so Cursor can find it).
2. In Cursor, add an MCP server config (project file **`.cursor/mcp.json`** in the repo root, or **Cursor Settings → MCP**), for example using `npx` (no global install required on that machine):

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

If you rely on the `~/.local/bin` install and a full path is more reliable on your Mac:

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

Replace `YOUR_USERNAME` with your macOS username.

3. **Restart Cursor** (or reload MCP) so it picks up the config.
4. If the server fails to connect, run the same `command` + `args` in a standalone terminal and fix any “command not found” or auth errors first.

### Step 3: Auth for MCP

MCP uses the same credentials as the CLI: either the profile from `bland auth login` or **`BLAND_API_KEY`** in the environment Cursor inherits. If tools fail with auth errors, set the key in your shell profile or in Cursor’s environment for the integrated terminal / MCP process (per Cursor docs for your version).

---

## Quick reference — what was done in the original setup session

| Action | Detail |
|--------|--------|
| Global npm install | Failed (`EACCES` on `/usr/local`) |
| Working install | `npm install -g bland-cli --prefix ~/.local` |
| PATH | Prepended `$HOME/.local/bin` in `~/.zprofile` |
| Auth | `bland auth login --key <key>` |
| MCP | Documented here; configure `.cursor/mcp.json` or Settings → MCP and verify `bland mcp` / `npx bland-cli mcp` |

---

## Security note

API keys should not be committed to git. If a key was ever pasted into chat or logs, **rotate it** in the Bland dashboard and run `bland auth login --key <new_key>` again.
