"""What does a bad night look like? Size a real NBA slate, then read KellyIQ's simulated risk for it.

    pip install kellyiq pandas
    python nba_bad_night.py                  # reads nba_2026-11-09.csv

The sides are chosen by a rule (every home team), not by who we think wins, and every side gets
the same assumed edge: Moderate Edge, KellyIQ's no-vig price plus up to 5 points. The edge is an
illustrative assumption, not a measured advantage, so the output shows how KellyIQ allocates a
bankroll and what the downside of that allocation looks like, not which bets to make. Prices,
sportsbook and observation time are in the CSV. The risk figures come from 100,000 simulated
nights and treat the games as independent. Moderate Edge works on every tier. Uses one optimize
from your daily allowance.
"""
import pandas as pd
from kellyiq import KellyIQ

slate = pd.read_csv("nba_2026-11-09.csv")

result = KellyIQ().optimize({  # reads KELLYIQ_API_KEY
    "bankroll": 1_000,
    "kellyFraction": 0.25,      # quarter Kelly
    "perBetCap": 0.02,          # at most 2% of the bankroll on one bet
    "maxTotalExposure": 0.10,   # at most 10% staked across the slate
    "picks": [
        {"id": str(i), "sport": "basketball_nba", "team": r.home, "opponent": r.away,
         "odds": int(r.home_odds), "opponentOdds": int(r.away_odds), "confidence": "MODERATE_EDGE"}
        for i, r in enumerate(slate.itertuples())
    ],
})

stakes = pd.DataFrame(result["allocation"]["stakes"], columns=["id", "stake"]).astype({"id": int, "stake": float})
slate = slate.join(stakes.set_index("id")).fillna({"stake": 0})
print(slate[["home", "away", "home_odds", "stake"]].to_string(index=False, float_format="%.2f"))
print(f"Total staked: ${slate['stake'].sum():,.2f}")

risk = ((result.get("risk") or {}).get("allocation") or {}).get("independent")  # the stakes above, simulated
if risk:
    money = lambda x: f"{'+' if x >= 0 else '-'}${abs(x):,.2f}"
    print(f"Average result:           {money(risk['meanProfit'])}")
    print(f"Chance of finishing down: {risk['probLoss']:.1%}")
    print(f"5th percentile night:     {money(risk['var5'])}")

# Output on Nov 9, 2026 (DraftKings prices observed 2026-11-09T16:00Z, 11:00 am ET). Stakes repeat
# exactly; the risk lines are simulated, so their last digits move a little from run to run.
# Enumerating all 32 win/loss outcomes of the five stakes exactly gives 54.6% down, +$1.88 average:
#      home      away  home_odds  stake
#     Hawks    Lakers       -120  14.04
#   Hornets Cavaliers        270   5.03
#   Pistons   Wizards       -490   0.00
#   Raptors Grizzlies       -148  12.02
# Mavericks    Pacers       -161  11.07
#   Rockets   Nuggets       -344   0.00
#      Suns     Spurs        286   4.77
#  Warriors  Pelicans       -395   0.00
# Total staked: $46.93
# Average result:           +$1.96
# Chance of finishing down: 54.4%
# 5th percentile night:     -$28.99
