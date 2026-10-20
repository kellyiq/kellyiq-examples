# Claude Code

```bash
export KELLYIQ_API_KEY="kiqa_..."
claude mcp add --transport http kellyiq --scope user https://api.kellyiq.com/mcp \
  --header "Authorization: Bearer $KELLYIQ_API_KEY"
```

Then run `/mcp` in a session to check it connected. `--scope user` makes KellyIQ available in every project.

Or, in a project's `.mcp.json` (the key is read from your environment, never written to the file):

```json
{
  "mcpServers": {
    "kellyiq": {
      "type": "http",
      "url": "https://api.kellyiq.com/mcp",
      "headers": { "Authorization": "Bearer ${KELLYIQ_API_KEY}" }
    }
  }
}
```
