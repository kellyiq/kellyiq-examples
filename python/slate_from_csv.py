"""Size every bet in a CSV with the kellyiq package and write the stakes to stakes.csv.

    pip install kellyiq
    python slate_from_csv.py                 # reads slate.csv, bankroll 1000
    python slate_from_csv.py my.csv 2500     # your file, your bankroll

CSV columns: sport,team,opponent,odds,opponent_odds,confidence
Uses one optimize from your daily allowance each time it runs.
"""
import csv
import sys

from kellyiq import DailyLimitError, KellyIQ, SlateNotOptimizableError, ValidationError

path = sys.argv[1] if len(sys.argv) > 1 else "slate.csv"
bankroll = float(sys.argv[2]) if len(sys.argv) > 2 else 1000

# utf-8-sig also reads the byte-order mark Excel puts at the start of "CSV UTF-8" files.
with open(path, newline="", encoding="utf-8-sig") as f:
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

client = KellyIQ()  # reads KELLYIQ_API_KEY
try:
    result = client.optimize({"bankroll": bankroll, "picks": picks})
except ValidationError as e:
    # Every problem at once; picks[2].odds is the third data row.
    raise SystemExit("Fix the CSV:\n  " + "\n  ".join(e.violations))
except SlateNotOptimizableError as e:
    raise SystemExit("KellyIQ could not size this slate:\n  " + "\n  ".join(e.violations))
except DailyLimitError as e:
    raise SystemExit(f"No optimizes left today. The allowance resets at {e.resets_at}.")

stakes = {s["id"]: s["stake"] for s in result["allocation"]["stakes"]}

with open("stakes.csv", "w", newline="", encoding="utf-8") as f:
    out = csv.writer(f)
    out.writerow(["team", "odds", "stake", "note"])
    for p in result["picks"]:
        out.writerow([p["team"], p["odds"], stakes.get(p["id"], 0), p["reason"] or ""])

print(f"Wrote stakes.csv: {len(stakes)} of {len(picks)} bets, "
      f"${result['allocation']['totalStake']:.2f} in total (seed {result['seed']})")
