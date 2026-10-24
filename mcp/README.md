# KellyIQ MCP configs

KellyIQ's hosted MCP server is `https://api.kellyiq.com/mcp`. It exposes six tools:
`optimize_slate`, `list_sports`, `get_limits`, `remove_vig`, `implied_probability` and `kelly_single_bet`.

- **Claude (web, desktop and mobile)**: no key or file needed. On claude.ai, open Settings, Connectors, Add custom connector, paste the URL, then click Connect and sign in to KellyIQ. It then works in the desktop and mobile apps too.
- **Cursor**: copy `cursor.json` into `~/.cursor/mcp.json` (all projects) or `.cursor/mcp.json`, set `KELLYIQ_API_KEY`, restart Cursor.
- **VS Code**: copy `vscode.json` into `.vscode/mcp.json`; VS Code asks for the key once and stores it securely.
- **Claude Code** and **Gemini CLI**: see the `.md` files.

The coding-tool configs use your KellyIQ API key. Never commit a config that contains your key. Full guide: https://www.kellyiq.com/developers/mcp
