"""Size every bet in slate.csv and write the stakes to stakes.csv.

slate.csv columns: sport,team,opponent,odds,opponent_odds,confidence
"""
import csv
import os
import requests

API = os.environ.get("KELLYIQ_API_BASE", "https://api.kellyiq.com")
KEY = os.environ["KELLYIQ_API_KEY"]
BANKROLL = 1000

# utf-8-sig also reads the byte-order mark Excel puts at the start of "CSV UTF-8" files.
with open("slate.csv", newline="", encoding="utf-8-sig") as f:
    rows = list(csv.DictReader(f))

picks = [
    {
        "id": str(i),  # the row number, so results map back to rows
        "sport": r["sport"],
        "team": r["team"],
        "opponent": r["opponent"],
        "odds": int(r["odds"]),
        "opponentOdds": int(r["opponent_odds"]),
        "confidence": r["confidence"],
    }
    for i, r in enumerate(rows)
]

resp = requests.post(
    f"{API}/v1/optimize",
    headers={"Authorization": f"Bearer {KEY}"},
    json={"bankroll": BANKROLL, "picks": picks},
    timeout=60,
)
if not resp.ok:
    # A VALIDATION_ERROR lists every problem; picks[2].odds is the third data row.
    raise SystemExit(f"HTTP {resp.status_code}: {resp.text[:500]}")
result = resp.json()

stakes = {t["id"]: t["stake"] for t in result["allocation"]["stakes"]}

with open("stakes.csv", "w", newline="", encoding="utf-8") as f:
    out = csv.writer(f)
    out.writerow(["team", "odds", "stake", "note"])
    for p in result["picks"]:
        out.writerow([p["team"], p["odds"], stakes.get(p["id"], 0), p["reason"] or ""])

print(f"Wrote stakes.csv: {len(stakes)} of {len(picks)} bets, "
      f"${result['allocation']['totalStake']:.2f} in total (seed {result['seed']})")
