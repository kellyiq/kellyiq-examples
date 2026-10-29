# KellyIQ examples

Working examples for the [KellyIQ API](https://www.kellyiq.com/developers): size a whole sports
betting slate as one portfolio from your own scripts, models, spreadsheets and AI assistants.

You send your bankroll and the bets you have chosen, with your view of each. KellyIQ removes the
bookmaker's margin from each price, applies your view, and returns a dollar stake for every bet,
sized across the slate together under per-bet and total-exposure limits.

## Get a key

Create an API key in the KellyIQ app under **Settings → API**. Every plan includes API access, Free
included, each with its own daily allowance. Then:

```bash
export KELLYIQ_API_KEY="kiqa_..."
```

## Recipes

Each recipe is a complete script in Python (`requests`) and JavaScript (Node 18+, no packages).

| Recipe | What it shows |
|---|---|
| [`first-optimize`](recipes/first-optimize.py) | Size a three-bet slate and read every part of the result |
| [`slate-from-csv`](recipes/slate-from-csv.py) | Keep your slate in a spreadsheet: CSV in, CSV of stakes out ([`slate.csv`](recipes/slate.csv)) |
| [`reproducible-results`](recipes/reproducible-results.py) | Get exactly the same answer again with the returned seed |
| [`handling-limits`](recipes/handling-limits.py) | Back off and retry on rate limits and a busy server |

```bash
cd recipes
python first-optimize.py        # or: node first-optimize.mjs
```

Each recipe has a walkthrough in the docs: [Recipes](https://www.kellyiq.com/developers/recipes/first-optimize).

## Python package

`pip install kellyiq` ([kellyiq-python](https://github.com/kellyiq/kellyiq-python)): the same API with
specific exceptions for each error and automatic retries when the server is busy.

| Example | What it shows |
|---|---|
| [`python/size-a-slate.ipynb`](python/size-a-slate.ipynb) | A notebook: stakes, the probabilities behind them, and the risk at each Kelly fraction, as tables |
| [`python/slate_from_csv.py`](python/slate_from_csv.py) | CSV in, CSV of stakes out, with each error handled ([`slate.csv`](python/slate.csv)) |
| [`python/size_from_model.py`](python/size_from_model.py) | Your model's probabilities in, stakes merged back into the DataFrame ([`model_output.csv`](python/model_output.csv)); needs `pandas` |

Guide: [Python SDK](https://www.kellyiq.com/developers/python).

## Excel

[`spreadsheets/kellyiq-slate.xlsx`](spreadsheets/kellyiq-slate.xlsx): enter your bankroll and your
bets, press Ctrl+Alt+F5, and get a stake for every bet with a summary of the slate. No macros, and your API key stays in a
file on your computer, never in the workbook. Excel for Windows. Setup: [`spreadsheets/`](spreadsheets).

## Benchmark

[`benchmarks/slate-sizing`](benchmarks/slate-sizing): three NBA slates sized by cap-then-scale, by
the exact constrained optimum and by KellyIQ, scored by exact expected log growth. The slates, the
scoring script and every stake are included so you can rerun it.

## AI assistants (MCP)

KellyIQ runs a hosted MCP server at `https://api.kellyiq.com/mcp`, so your assistant can size a
slate as one of its tools. Claude connects by signing in; coding tools use an API key, with
ready-to-use configs in [`mcp/`](mcp):

| Assistant | Setup |
|---|---|
| Claude (web, desktop, mobile) | Settings, Connectors, Add custom connector, paste the URL, then Connect and sign in |
| Claude Code | [`mcp/claude-code.md`](mcp/claude-code.md) |
| Cursor | [`mcp/cursor.json`](mcp/cursor.json) |
| VS Code (GitHub Copilot) | [`mcp/vscode.json`](mcp/vscode.json) |
| Gemini CLI | [`mcp/gemini-cli.md`](mcp/gemini-cli.md) |

Full guide: [AI assistants (MCP)](https://www.kellyiq.com/developers/mcp).

### Skills

[`skills/analyze-my-slate`](skills/analyze-my-slate/SKILL.md) teaches the assistant to collect your
slate in one message, confirm before using an optimize, and explain the stakes and the risk.
Install steps for Claude and Claude Code: [`skills/`](skills).

## Docs and support

- [Quickstart](https://www.kellyiq.com/developers/quickstart), [API reference](https://www.kellyiq.com/developers/reference/optimize), [OpenAPI spec](https://www.kellyiq.com/openapi-v1.yaml)
- support@kellyiq.com (include the `requestId` from any error)

Keep your key out of code you commit or share; every example here reads it from the environment.

KellyIQ sizes the bets you choose; it does not choose bets or predict outcomes. Results are
calculations, not betting advice. 21+, where legal.

The examples are MIT licensed. The KellyIQ optimizer itself runs as a hosted service.
