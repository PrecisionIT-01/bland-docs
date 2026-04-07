# Bland CLI and MCP — Installation and Authentication

This document describes how to install the Bland CLI, authenticate it, and verify it's working. For Cursor-specific integration, see [cursor-integration.md](cursor-integration.md).

---

## Prerequisites

- **Node.js 18+**
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

## Part 3 — Verify MCP Server Availability

The same `bland-cli` package includes an MCP server. The CLI does **not** need a separate MCP install if `bland-cli` is already installed.

### Step 1: Confirm the MCP command runs

From a terminal (with `PATH` including `~/.local/bin` if you used that layout):

```bash
bland mcp
```

That starts the MCP server on **stdio** (typical for editor integration). It may appear to "hang"; that is normal when run alone — editors spawn it as a subprocess.

Optional SSE transport (for other clients):

```bash
bland mcp --transport sse --port 3100
```

### Step 2: Test MCP

For Cursor-specific configuration, see [cursor-integration.md](cursor-integration.md).

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

---

## Next Steps

- **Cursor Integration:** See [cursor-integration.md](cursor-integration.md) for configuring Cursor to use the Bland MCP server.
- **CLI Commands:** See [cli-commands.md](../reference/cli-commands.md) for complete command reference.
- **Workflows:** See [troubleshooting.md](../workflows/troubleshooting.md) for how to pull call data and diagnose issues.