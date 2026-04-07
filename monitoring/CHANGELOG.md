# Bland Documentation Changelog

Track of local updates made to this documentation repository based on changes detected in Bland docs.

---

## 2026-04-07

### Initial Repository Organization

- **Restructured documentation** into organized folders:
  - `setup/` — Installation and Cursor integration
  - `reference/` — Command and API references
  - `workflows/` — Task-driven workflows
  - `monitoring/` — Change tracking and automation
  
- **Created/Reorganized files:**
  - `README.md` — Project overview and structure
  - `setup/installation.md` — CLI installation and authentication (extracted from bland-cli-and-mcp-setup.md)
  - `setup/cursor-integration.md` — Cursor-specific MCP configuration
  - `reference/cli-commands.md` — Complete CLI command reference (from bland-cli-reference (2).md)
  - `reference/mcp-tools.md` — MCP tools and equivalents
  - `reference/tools.md` — Tools v2 integration guide (from docs.bland.ai)
  - `reference/webhooks.md` — Webhook node configuration (from docs.bland.ai)
  - `reference/personas.md` — Personas configuration (from docs.bland.ai)
  - `reference/custom-code-node.md` — Custom code node guide (from docs.bland.ai)
  - `reference/web-agent-sdk.md` — Web Agent SDK reference (from docs.bland.ai)
  - `workflows/troubleshooting.md` — Call and pathway troubleshooting (from bland-cli-workflows.md)
  - `workflows/testing.md` — Test cases and simulations (extracted from bland-cli-workflows.md)
  - `workflows/daily-tasks.md` — Common tasks and workflows

- **Deprecated/Archived:**
  - `bland-cli-and-mcp-setup.md` → Merged into setup/installation.md and setup/cursor-integration.md
  - `bland-cli-reference (2).md` → Moved to reference/cli-commands.md
  - `bland-cli-workflows.md` → Moved to workflows/troubleshooting.md with testing portions extracted

- **Added automation:**
  - `scripts/monitor-bland-docs.sh` — Nightly monitoring script
  - `monitoring/last-check.json` — State tracking for documentation monitoring

### Notes

- Fetch initial documentation from Bland docs April 6, 2026
- Focus on CLI and MCP tools for Cursor integration
- Emphasis on structural operations (not prompt authoring)

---