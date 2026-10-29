"""Size the three benchmark slates with the kellyiq package and write the stakes for score.mjs.

    pip install kellyiq
    python size_slates.py                   # writes my-results.json
    node score.mjs my-results.json

Uses three optimizes from your daily allowance. Sending your own probabilities needs Bettor or
above, and slate C has 20 bets, which needs Sharp (Bettor sizes up to 12 games per slate).
"""
import json
from pathlib import Path

from kellyiq import KellyIQ, KellyIQError

here = Path(__file__).parent
spec = json.loads((here / "slates.json").read_text(encoding="utf-8"))

client = KellyIQ()  # reads KELLYIQ_API_KEY
stakes = {}
for name, bets in spec["slates"].items():
    try:
        result = client.optimize({
            **spec["request"],
            "picks": [
                {
                    "id": b["id"],
                    "sport": "basketball_nba",
                    "team": b["team"],
                    "opponent": b["opponent"],
                    "odds": b["odds"],
                    "opponentOdds": b["opponentOdds"],
                    "probability": b["p"],
                }
                for b in bets
            ],
        })
    except KellyIQError as e:
        # Keep the slates already sized; score.mjs reports a missing slate as "no allocation".
        print(f"Slate {name}: not sized ({e.code}: {e.message})")
        continue
    stakes[name] = {s["id"]: s["stake"] for s in result["allocation"]["stakes"]}
    print(f"Slate {name}: ${result['allocation']['totalStake']:.2f} staked "
          f"(engine {result.get('engineVersion')})")

out = here / "my-results.json"
out.write_text(json.dumps({"KellyIQ": {"yours": stakes}}, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {out.name}. Score it with: node score.mjs {out.name}")
