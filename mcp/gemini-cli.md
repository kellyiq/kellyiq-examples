# Gemini CLI

```bash
export KELLYIQ_API_KEY="kiqa_..."
gemini mcp add --scope user --transport http --header "Authorization: Bearer $KELLYIQ_API_KEY" kellyiq https://api.kellyiq.com/mcp
```

This writes the entry, including the key, to your user settings (`~/.gemini/settings.json`). Keep `--scope user`: without it the key is saved in the current project's folder, where it can end up in a commit.
