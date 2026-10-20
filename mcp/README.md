# KellyIQ MCP configs

KellyIQ's hosted MCP server is `https://api.kellyiq.com/mcp`. It authenticates with your KellyIQ API key and exposes six tools:
`optimize_slate`, `list_sports`, `get_limits`, `remove_vig`, `implied_probability` and `kelly_single_bet`.

- **Cursor**: copy `cursor.json` into `~/.cursor/mcp.json` (all projects) or `.cursor/mcp.json`, set `KELLYIQ_API_KEY`, restart Cursor.
- **VS Code**: copy `vscode.json` into `.vscode/mcp.json`; VS Code asks for the key once and stores it securely.
- **Claude Desktop**: merge `claude-desktop.json` into your config (Settings, Developer, Edit Config), put your key after `Bearer `, quit and reopen. Needs Node.js for `mcp-remote`.
- **Claude Code** and **Gemini CLI**: see the `.md` files.

Never commit a config that contains your key. Full guide: https://www.kellyiq.com/developers/mcp
