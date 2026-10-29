"""Size a slate from your model's probabilities with the kellyiq package, then merge the stakes back.

    pip install kellyiq pandas
    python size_from_model.py               # reads model_output.csv

CSV columns: id,team,opponent,odds,opponent_odds,p (p is your model's win probability for team).
Sending your own probabilities needs Bettor or above (every new account starts with a 14-day
Bettor trial). Uses one optimize from your daily allowance. Walkthrough:
https://www.kellyiq.com/blog/bring-kellyiq-into-your-workflow
"""
import pandas as pd
from kellyiq import KellyIQ

slate = pd.read_csv("model_output.csv", dtype={"id": str})  # ids come back as strings

client = KellyIQ()  # reads KELLYIQ_API_KEY
result = client.optimize({
    "bankroll": 10_000,
    "kellyFraction": 0.25,     # quarter Kelly
    "perBetCap": 0.02,         # at most 2% of the bankroll on one bet
    "maxTotalExposure": 0.10,  # at most 10% staked across the slate
    "picks": [
        {
            "id": r.id,
            "sport": "basketball_nba",
            "team": r.team,
            "opponent": r.opponent,
            "odds": int(r.odds),
            "opponentOdds": int(r.opponent_odds),
            "probability": float(r.p),
        }
        for r in slate.itertuples()
    ],
})

stakes = pd.DataFrame(result["allocation"]["stakes"])[["id", "stake"]]
slate = slate.merge(stakes, on="id", how="left").fillna({"stake": 0})
print(slate[["team", "odds", "p", "stake"]])
print("Total staked:", slate["stake"].sum())
