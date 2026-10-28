import json
import os
import requests

API = os.environ.get("KELLYIQ_API_BASE", "https://api.kellyiq.com")
KEY = os.environ["KELLYIQ_API_KEY"]

slate = {
    "bankroll": 1000,
    # Settings in the request, not from your app settings, which you might change later.
    "kellyFraction": 0.25,
    "maxTotalExposure": 0.5,
    "perBetCap": 0.2,
    "useAccountDefaults": False,
    "picks": [
        {"id": "lad", "sport": "baseball_mlb", "team": "Dodgers", "opponent": "Padres",
         "odds": -145, "opponentOdds": 125, "confidence": "MODERATE_EDGE"},
        {"id": "chc", "sport": "baseball_mlb", "team": "Cubs", "opponent": "Cardinals",
         "odds": 120, "opponentOdds": -140, "confidence": "MODERATE_EDGE"},
    ],
}


def optimize(body):
    resp = requests.post(f"{API}/v1/optimize", headers={"Authorization": f"Bearer {KEY}"},
                         json=body, timeout=60)
    if not resp.ok:
        raise SystemExit(f"HTTP {resp.status_code}: {resp.text[:500]}")
    return resp.json()


# First run: no seed, so the server picks one and returns it.
first = optimize(slate)

# Store the request and what produced the result, together.
record = {
    "request": slate,
    "seed": first["seed"],
    "engineVersion": first["engineVersion"],
    "stakes": first["allocation"]["stakes"],
}
with open("result.json", "w") as f:
    json.dump(record, f, indent=2)

# Later: resend the same request with the stored seed.
with open("result.json") as f:
    saved = json.load(f)
again = optimize({**saved["request"], "seed": saved["seed"]})

if again["engineVersion"] != saved["engineVersion"]:
    print("The engine has changed since this result was stored, so numbers may differ.")
same = again["allocation"]["stakes"] == saved["stakes"]
print("Identical allocation:", same)
if not same:
    raise SystemExit(1)
