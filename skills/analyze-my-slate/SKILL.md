---
name: analyze-my-slate
description: Size a sports betting slate the user has already chosen with the KellyIQ MCP tools, and explain the stakes. Use when the user wants stakes, bet sizes or a bankroll split for one or more bets they have picked, or asks to analyze, size or optimize their slate. Needs the KellyIQ connector (https://api.kellyiq.com/mcp).
---

# Analyze My Slate

Size the bets the user has already chosen with KellyIQ, then explain the result. KellyIQ does the
math; your job is to collect the right inputs on the first try, spend the user's daily optimize
only once they agree, and explain what came back.

KellyIQ sizes bets the user picked. It does not choose bets or predict outcomes, and its results are
calculations, not betting advice. Keep to that throughout: never suggest which bets to place, add or
skip, never call a bet a lock or a good play, and never recommend a Kelly fraction. Call the result
"stakes" or "calculated stakes", never "suggested" or "recommended" stakes.

If the KellyIQ tools (`optimize_slate`, `list_sports`, `get_limits`, `remove_vig`) are not
available, say so and point the user to https://www.kellyiq.com/developers/mcp to connect. Do not
size the slate yourself instead.

## 1. Check the account (free)

Call `get_limits` and `list_sports` before asking for anything. Neither counts against the
allowance.

- From `get_limits`: the plan (`tier`) and `limits.optimize.remainingToday`. If no optimizes are
  left today, tell the user when the allowance resets (`resetsAt`) and stop there.
- From `list_sports`: the sports KellyIQ can size today, and the key to send for each. Only offer
  those. A sport missing from the list is out of season.

The plan decides how the user gives their view of each bet:

- **Free**: a confidence level only: Market, Small edge or Moderate edge. Strong edge needs Bettor.
- **Bettor and up**: any confidence level, including Strong edge, or their own win probability.
  One kind for the whole slate: if the user mixes them, ask which one to use for every bet.

## 2. Ask for everything in one message

If the user's message already has everything below, skip to step 4. Otherwise ask once, with a
template, instead of one question at a time. Fill in whatever the user has already told you and ask
only for what is missing:

```
Bankroll: $____
Limits (optional): Kelly fraction ____, most on one bet ____%, most on the slate ____%

For each bet:
  Game:       ____ vs ____  (sport: ____)
  Bet:        moneyline / spread ____ / total over or under ____
  Your side:  ____ at ____   (American odds, e.g. -110)
  Other side: ____ at ____   (the opposite side of the same market)
  Draw:       ____           (soccer moneyline only)
  Your view:  ____
```

- **Both sides' prices are required.** KellyIQ removes the bookmaker's margin using the other side.
  For a total, the other side is the Over when the bet is the Under, and the reverse.
- **Your view** is a confidence level: how much more likely the user thinks their side is to win
  than the fair price says. Small edge, Moderate edge and Strong edge claim 3.5, 5 and 7.5
  probability points at even odds (less toward heavy favorites and long shots); Market claims no
  edge. There are no fade levels: a user who thinks a side is overpriced picks the other side. Free
  plans can use every level except Strong edge. On Bettor and up it can instead be their win
  probability.
- Never fill in a price, line, probability or confidence level yourself, not even "about right"
  ones. If the user does not know a price, ask them to look it up at their sportsbook.

## 3. If a Free user gives percentages (free)

Free plans do not accept the user's own probabilities, but the user's percentages still help them
choose a confidence level. Call `remove_vig` with both sides of each market and show the fair
probability next to theirs, for example *market 50%, you 56%*. Then describe the levels the plan
allows (Market, Small edge, Moderate edge) and let the user pick one for each bet. Do not pick
for them.

## 4. Confirm before spending an optimize

Each `optimize_slate` call uses one of the user's daily optimizes. Before calling it, show a short
summary: the bankroll, each bet with both prices and the user's view, and how many optimizes are
left today. Ask the user to confirm. Call it after they say go.

Only a clear go counts, such as "go", "yes" or "run it". A reply that only fills in a missing side,
price, line or view is not one: show the updated summary and ask again. If you asked anything else in
the same message, such as which side they are betting, get the answer before calling. This applies to
every optimize, including retries and what-ifs.

## 5. Call optimize_slate once

Send every bet in one call. Use the sport keys from `list_sports`.

- For spreads, `line` is from the picked team's side (-3.5 means that team must win by 4 or more);
  for totals, it is the total.
- Bets in the same game: give them the same `eventId` (any label, such as `"OSU-PSU"`) so KellyIQ
  treats them as one game.
- Settings the user gave go in as given, each a fraction: `kellyFraction` for their Kelly fraction
  (quarter Kelly is 0.25), `perBetCap` for the most on one bet and `maxTotalExposure` for the most
  on the slate, both as fractions of the bankroll (2% is 0.02), and `maxBets` for a bet-count
  limit. Do not rescale them: stakes are sized on the whole bankroll and both limits are hard caps.
- Leave out any setting the user did not give; the account's saved settings apply (a saved
  CVaR-aware setting on Sharp and up means the risk-adjusted mode chooses the fraction), else
  quarter Kelly, 100% of the bankroll on the slate and 20% on any one bet.
- On Free, the most on one bet is fixed at 25% of the slate limit; a `perBetCap` sent anyway is
  ignored and a warning says so. Tell the user if they asked for a different one.

If it returns an error, read the `error` code. Every attempt the API accepts counts toward today's
allowance, even one that fails validation, so confirm with the user before any retry.

- `VALIDATION_ERROR`: `violations` names each field and problem. Fix the input, asking the user if
  needed.
- `UPGRADE_REQUIRED`: the plan does not allow something sent: on Free, the user's own
  probabilities or Strong edge, or more bets than the plan allows. Tell the user what needs an
  upgrade (`violations` names it) and let them choose what to change, for example a confidence
  level the plan allows.
- `SLATE_NOT_OPTIMIZABLE`: `violations` gives the reasons. Pass them on.
- `DAILY_LIMIT_EXCEEDED`: do not retry. Tell the user when the allowance resets (`resetsAt`).
- `BURST_LIMIT_EXCEEDED` or `SERVICE_BUSY`: wait `retryAfterSeconds` (or a minute) before one
  retry.

## 6. Explain the result

Lead with the stakes, then what drives them. Use the numbers KellyIQ returned; do not recompute or
adjust them.

1. **Stakes**: `allocation.stakes`, one dollar amount per bet, and `allocation.totalStake`. Bets
   with no stake are in `picks[]` with `included: false` and a `reason`: `NO_EDGE` (the user's
   view puts no edge on that price), `MAX_BETS` (more bets than the bet-count limit allows),
   `BUDGET` (it has an edge, but the slate limit was used up by bets with more), `NOT_SELECTED`
   (the optimizer gave it no stake in this allocation) or `NOT_PRICEABLE` (the prices could not be
   used). Describe the reason; do not tell the user to drop or keep the bet.
2. **Limits**: stakes are sized on the whole bankroll, then held to two caps. `atRisk` is the
   most the slate could stake (bankroll × total exposure). `settingsApplied` shows each setting
   and where it came from (the request, the account's saved settings, or the plan default), and
   gives both limits in dollars (`perBetCapAmount`, `maxTotalExposureAmount`). Mention when a
   limit is what held a stake down: a stake equal to `perBetCapAmount`, or a total equal to
   `atRisk`.
3. **Why each stake is that size**: for each pick, `probability.market` (the fair price with the
   margin removed) against `probability.yours` (the probability that drove sizing), and
   `expectedValue` (expected profit per $1 staked, not a dollar total). A bigger gap between yours
   and the market means a bigger stake; for the same gap, longer odds get a smaller stake. All the
   bets share one bankroll and the limits, so stakes are usually smaller than each bet sized
   alone.
4. **Kelly fraction and risk**: `allocation.kellyMultiplier` is the fraction of full Kelly the
   stakes are sized at, and `allocation.basis` says where it came from: `REQUESTED` (the user's
   `kellyFraction`), `ACCOUNT_DEFAULT` (their saved app setting), `PRODUCT_DEFAULT` (quarter
   Kelly) or `RISK_ADJUSTED` (chosen by the risk-adjusted mode on the user's saved CVaR setting;
   only then is `riskConstraintMet` set). From `risk.allocation.independent` (these stakes):
   the chance the slate loses money overall (`probLoss`, show it as a percent), the expected
   profit (`meanProfit`), and `var5` (1 in 20 slates end at this result or worse). These treat
   the bets as independent (`correlated` is always null). If some bets are related, such as two
   in the same game, say so plainly: the figures assume they are not, and allowing for that is
   the user's call. Compare with the `independent` figures of `risk.full`, `risk.half` and
   `risk.quarter` so the user sees what larger and smaller fractions would do; each pick's stake
   at those fractions is in `picks[].sizing.full`, `.half` and `.quarter`. If the user asks which
   to use, explain the trade-off (smaller means smaller swings and slower growth) and leave the
   choice to them.
5. **Warnings**: pass on anything in `warnings`.
6. **Close with**: these stakes are calculations from the user's own prices and views, not betting
   advice; KellyIQ does not pick bets or predict results. 21+, where legal.

`explanation` holds a plain-English summary you may quote, but its wording changes, so take
numbers from the fields above.

## 7. What-ifs

The user may want to change a view, drop a bet or try a different limit. Each re-run is another
optimize: say so, and confirm first. The last result's `usage` field shows how many have been used
today, so there is no need to call `get_limits` again. To reproduce an earlier result exactly, send
the same input with the `seed` it returned.
