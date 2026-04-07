# Bland CLI Documentation

Complete documentation for the Bland CLI, MCP server, and related workflows for Cursor integration.

## Structure

- **[setup/](setup/)** - Installation, authentication, and Cursor integration
  - [installation.md](setup/installation.md) - CLI and MCP setup instructions
  - [cursor-integration.md](setup/cursor-integration.md) - Cursor-specific MCP configuration

- **[reference/](reference/)** - Command and API references
  - [cli-commands.md](reference/cli-commands.md) - Complete CLI command reference
  - [mcp-tools.md](reference/mcp-tools.md) - MCP tools and their equivalents
  - [tools.md](reference/tools.md) - Tools (v2) integration guide
  - [webhooks.md](reference/webhooks.md) - Webhook node configuration
  - [personas.md](reference/personas.md) - Personas configuration
  - [custom-code-node.md](reference/custom-code-node.md) - Custom code node guide
  - [web-agent-sdk.md](reference/web-agent-sdk.md) - Web Agent SDK reference

- **[workflows/](workflows/)** - Task-driven workflows
  - [troubleshooting.md](workflows/troubleshooting.md) - Call and pathway troubleshooting
  - [testing.md](workflows/testing.md) - Test cases, simulations, and validation
  - [daily-tasks.md](workflows/daily-tasks.md) - Pulling call IDs, getting pathways, common tasks

- **[monitoring/](monitoring/)** - Change tracking and automation
  - [CHANGELOG.md](monitoring/CHANGELOG.md) - Local documentation changelog
  - [last-check.json](monitoring/last-check.json) - Automated tracking state

## Purpose

This repository maintains documentation for using the Bland CLI and MCP server with Cursor and other AI coding tools. It focuses on:

1. **Setting up MCP** for Cursor to interact with Bland accounts
2. **Pulling call IDs** and pathway data for troubleshooting
3. **Building simulated test cases** based on real failures
4. **Keeping up-to-date** with Bland's CLI and MCP documentation changes

## Rules for Updating This Documentation

When using this documentation to work with Bland:

1. **Never author or modify agent-facing prompt text.** Prompts are provided by humans — your role is structural operations and diagnosis.
2. **Never use `bland guide` content to generate prompts.** Read guides for platform understanding only.
3. **Always validate before pushing.** Run `bland pathway validate` before every `bland pathway push`.
4. **Always test with `--verbose`.** When running `bland pathway chat`, always include `--verbose`.
5. **Always use `--json` for programmatic output.** When parsing CLI output in scripts or pipelines.

## Nightly Monitoring

This repository is automatically monitored nightly via the `scripts/monitor-bland-docs.sh` script, which:

- Fetches the latest CLI and MCP documentation from `https://docs.bland.ai/sdks/cli.md`
- Checks the latest changelog for CLI/MCP-related updates
- Compares with cached versions (stored in `monitoring/last-check.json`)
- Updates relevant MD files when changes are detected
- Commits changes to GitHub
- Emails diffs and updated files to `timothy@vegocs.com`

## Links

- **Bland CLI Docs:** https://docs.bland.ai/sdks/cli.md
- **CLI Package:** https://www.npmjs.com/package/bland-cli
- **Bland API Docs:** https://docs.bland.ai/api-v1/get/calls.md
- **Bland Changelog:** https://docs.bland.ai/changelog/