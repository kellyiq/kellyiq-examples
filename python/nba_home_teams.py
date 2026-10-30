"""Size every home team on a real NBA slate at the same assumed edge, with the kellyiq package.

    pip install kellyiq pandas
    python nba_home_teams.py                 # reads nba_2026-10-30.csv

The sides are chosen by a rule (every home team), not by who we think wins, and every side gets
the same assumed edge: Moderate Edge, KellyIQ's no-vig price plus up to 5 points. The edge is an
illustrative assumption, not a measured advantage, so the stakes show how KellyIQ allocates a
bankroll, not which bets to make. Prices, sportsbook and observation time are in the CSV.
Moderate Edge works on every tier. Uses one optimize from your daily allowance.
"""
import pandas as pd
from kellyiq import KellyIQ

slate = pd.read_csv("nba_2026-10-30.csv")

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

stakes = pd.DataFrame(result["allocation"]["stakes"])[["id", "stake"]].astype({"id": int})
slate = slate.join(stakes.set_index("id")).fillna({"stake": 0})
print(slate[["home", "away", "home_odds", "stake"]].to_string(index=False))
print(f"Total staked: ${slate['stake'].sum():,.2f}")

# Output on Oct 29, 2026 (prices observed 2026-10-30T03:30:04Z), identical on a second run:
#         home     away  home_odds  stake
#      Wizards  Hornets       -115  13.49
#      Celtics    Bulls       -850   0.00
#         Nets  Pistons        230   5.74
#        76ers   Knicks        102  13.02
#      Raptors    Magic       -205   6.28
#    Mavericks  Rockets        180   7.47
#         Heat   Pacers       -265   0.15
# Timberwolves Clippers       -265   0.15
#     Warriors   Lakers        110  12.76
#         Suns  Nuggets        142   9.51
# Total staked: $68.57
