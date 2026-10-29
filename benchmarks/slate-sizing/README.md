# Slate sizing benchmark

When several bets share one bankroll and your limits bind, how much does it matter whether the
stakes are sized one bet at a time or across the slate together?

This folder compares two ways of sizing the same three NBA slates, and KellyIQ's answer, by their
exact expected log growth. Everything needed to check or rerun it is here.

## Setup

- **Slates** ([`slates.json`](slates.json)): A (8 bets), B (12) and C (20), NBA moneylines with
  realistic two-sided prices and at least one long shot each. Written Oct 27, 2026, before any run.
- **Probabilities**: each bet's `p` is the bettor's own estimate. For scoring, it's treated as the
  true probability. One bet per game, so the bets are independent.
- **The request**, the same for every method: $10,000 bankroll, quarter Kelly, at most 2% of the
  bankroll on any one bet, at most 10% of the bankroll staked across the slate.

## The methods

- **R1, cap then scale.** Single-bet Kelly for each bet, times 0.25, each stake clipped to 2%, then
  every stake scaled down by the same factor if the total is over 10%. This is the common way to
  size a slate in a few lines of code.
- **R3, constrained optimum.** Maximize CRRA utility with risk aversion 4 (the usual equivalent of
  quarter Kelly) subject to both limits, solved exactly over every win/loss outcome. A reference
  point, not something you'd run in production: exact enumeration is 2^n outcomes.
- **KellyIQ.** The `/v1/optimize` response's `allocation.stakes` for the same request. KellyIQ sizes
  the bets jointly, maximizing a quadratic approximation of expected log growth subject to both
  limits.

## Scoring

[`score.mjs`](score.mjs) computes R1 and R3, then scores any allocation file: the slate total,
whether both limits hold, and the exact expected log growth in basis points of bankroll per slate,
summed over all 2^n outcomes with no sampling. Node 18 or later, no packages.

```bash
node score.mjs kellyiq-results.json
```

Its output for KellyIQ's stakes is in [`output.txt`](output.txt).

## Results

KellyIQ's stakes ([`kellyiq-results.json`](kellyiq-results.json)) were requested on Oct 28, 2026
from the production API (engine `dac230b`), as three separate requests through the KellyIQ MCP
connector, each sending the request above.

| Slate | Bets | R1, cap then scale | R3, constrained optimum | KellyIQ | KellyIQ vs R1 |
|---|---:|---:|---:|---:|---:|
| A | 8 | 37.17 bps ($848.69) | 36.92 bps ($845.32) | 36.60 bps ($841.53) | 1.5% lower |
| B | 12 | 47.06 bps ($1,000) | 48.98 bps ($1,000) | 48.63 bps ($1,000) | 3.3% higher |
| C | 20 | 45.18 bps ($1,000) | 52.46 bps ($1,000) | 52.15 bps ($1,000) | 15.4% higher |

*Expected log growth in basis points of bankroll per slate, with the slate total in brackets.*

- **Limits**: every KellyIQ stake is within $200, and every slate total is within $1,000.
- **Repeatability**: the three runs returned identical stakes, to the cent, on every bet.
- **Slate A**: the 10% limit doesn't bind (only one bet reaches the 2% cap), and all three methods
  stake about $845. At quarter Kelly, slightly larger stakes score slightly higher on log growth, so
  R1 comes out ahead of both R3 and KellyIQ. KellyIQ is also 0.9% below R3 because its objective
  approximates log growth rather than computing it exactly.
- **Slates B and C**: the 10% limit binds. Scaling every bet down by the same factor keeps the
  proportions single-bet Kelly chose for each bet on its own. Sizing the slate jointly splits the
  same $1,000 differently, for more expected log growth. KellyIQ lands within 0.7% of the exact
  optimum on both.

## Limitations

- One test, three slates, one setting (quarter Kelly, 2%, 10%). How much joint sizing helps
  depends on the prices, the probabilities and the limits, not on the number of bets.
- Expected log growth assumes the probabilities are right. Real probabilities are estimates.
- The slates are ours, and we make KellyIQ. That's why the slates, the scoring script and every
  stake are published here.

## Rerun KellyIQ's side

[`size_slates.py`](size_slates.py) sends the three slates through the `kellyiq` Python package and
writes your stakes in the same format:

```bash
pip install kellyiq
export KELLYIQ_API_KEY="kiqa_..."
python size_slates.py
node score.mjs my-results.json
```

It uses three optimizes from your daily allowance. Sending your own probabilities needs Bettor or
above, and slate C's 20 bets need Sharp. It also needs NBA to be in season (`client.sports()` lists
what's live). A later engine version can return different stakes; the response's `engineVersion`
says which one answered.
