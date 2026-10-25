# Skills

Skills teach an assistant how to use the KellyIQ MCP tools well. Each one is a folder with a
`SKILL.md`. They need the KellyIQ connector first: see [`mcp/`](../mcp).

| Skill | What it does |
|---|---|
| [`analyze-my-slate`](analyze-my-slate/SKILL.md) | Collects your slate in one message (both sides' prices, your view of each bet), confirms before using an optimize, sizes it with `optimize_slate`, and explains the stakes and the risk |

## Install

**Claude (web, desktop, mobile)**, any plan:

1. In Settings → Capabilities, turn on **Code execution and file creation**.
2. Download [`analyze-my-slate.zip`](analyze-my-slate.zip).
3. Open **Customize → Skills**, click **+**, then **Create skill → Upload a skill**, and choose the zip.
4. Turn the skill on. In a chat with the KellyIQ connector on, ask: *Analyze my slate.*

**Claude Code**: copy the folder into your skills directory.

```bash
git clone https://github.com/kellyiq/kellyiq-examples
cp -r kellyiq-examples/skills/analyze-my-slate ~/.claude/skills/
```

Start a new session; Claude Code picks the skill up when you ask it to size a slate.

`analyze-my-slate.zip` is the `analyze-my-slate` folder zipped as-is. If you change the skill,
rebuild it from this directory: `zip -r analyze-my-slate.zip analyze-my-slate`.
