import os
import requests

API = os.environ.get("KELLYIQ_API_BASE", "https://api.kellyiq.com")
KEY = os.environ["KELLYIQ_API_KEY"]

slate = {
    "bankroll": 1000,
    "picks": [
        {"id": "lad", "sport": "baseball_mlb", "team": "Dodgers", "opponent": "Padres",
         "odds": -145, "opponentOdds": 125, "confidence": "MODERATE_EDGE"},
        {"id": "chc", "sport": "baseball_mlb", "team": "Cubs", "opponent": "Cardinals",
         "odds": 120, "opponentOdds": -140, "confidence": "MODERATE_EDGE"},
        {"id": "nyy", "sport": "baseball_mlb", "team": "Yankees", "opponent": "Red Sox",
         "odds": -110, "opponentOdds": -110, "confidence": "MARKET"},
    ],
}

resp = requests.post(
    f"{API}/v1/optimize",
    headers={"Authorization": f"Bearer {KEY}"},
    json=slate,
    timeout=60,
)
if not resp.ok:
    # API errors are JSON; a proxy timeout may not be, so show the raw text then.
    raise SystemExit(f"HTTP {resp.status_code}: {resp.text[:500]}")
result = resp.json()


def usd(n):
    return f"-${-n:.2f}" if n < 0 else f"${n:.2f}"


# 1. The allocation: how much to stake on each bet.
alloc = result["allocation"]
if alloc["kellyMultiplier"] is not None:
    print(f"Allocation: {alloc['kellyMultiplier']:.2f}x Kelly, {usd(alloc['totalStake'])} in total")
for t in alloc["stakes"]:
    print(f"  {usd(t['stake']):>9}  {t['team']} {t['odds']:+d}")

# 2. What happened to each pick, including the ones with no stake.
print()
for p in result["picks"]:
    if p["included"]:
        print(f"{p['team']} {p['odds']:+d}: staked")
    else:
        print(f"{p['team']} {p['odds']:+d}: no stake ({p['reason']})")

# 3. The allocation's risk, from 100,000 simulated slates.
risk = result["risk"]["allocation"]["independent"]
if risk is not None:
    print(f"\nAverage profit {usd(risk['meanProfit'])}, chance of losing money {risk['probLoss']:.0%}, "
          f"worst 5% average {usd(risk['cvar5'])}")

# 4. The settings that were used, and where each came from.
print()
for name, s in result["settingsApplied"].items():
    print(f"{name}: {s['value']} (from {s['source']})")
for w in result["warnings"]:
    print("warning:", w)

# 5. Keep these with the result: with the request, they reproduce it exactly.
print(f"\nseed={result['seed']} engine={result['engineVersion']} request={result['requestId']}")
