import os
import time
import requests

API = os.environ.get("KELLYIQ_API_BASE", "https://api.kellyiq.com")
KEY = os.environ["KELLYIQ_API_KEY"]
RETRYABLE = ("BURST_LIMIT_EXCEEDED", "SERVICE_BUSY")


class DailyLimitReached(Exception):
    pass


def optimize(body, max_attempts=5):
    """POST /v1/optimize, waiting out per-minute limits and busy periods."""
    for attempt in range(1, max_attempts + 1):
        resp = requests.post(f"{API}/v1/optimize", headers={"Authorization": f"Bearer {KEY}"},
                             json=body, timeout=60)
        if resp.ok:
            print("optimizes left today:", resp.headers.get("X-RateLimit-Remaining"))
            return resp.json()

        try:
            err = resp.json()
        except ValueError:
            # Not from the API (e.g. a proxy timeout page): treat it like SERVICE_BUSY.
            err = {"error": "SERVICE_BUSY"}

        if err["error"] == "DAILY_LIMIT_EXCEEDED":
            # Done for today. Retrying only adds to the count.
            raise DailyLimitReached(f"allowance used up; resets at {err['resetsAt']}")
        if err["error"] not in RETRYABLE:
            # A problem with the request itself: fix it rather than retry.
            raise RuntimeError(f"{resp.status_code} {err['error']}: "
                               f"{err.get('violations') or err.get('message')} (request {err.get('requestId')})")
        if attempt < max_attempts:
            wait = int(resp.headers.get("Retry-After", "5"))
            print(f"{err['error']}: waiting {wait}s (attempt {attempt})")
            time.sleep(wait)
    raise RuntimeError(f"still limited after {max_attempts} attempts")


slates = [
    {"bankroll": 1000, "picks": [
        {"sport": "baseball_mlb", "team": "Dodgers", "opponent": "Padres",
         "odds": -145, "opponentOdds": 125, "confidence": "MODERATE_EDGE"}]},
    {"bankroll": 1000, "picks": [
        {"sport": "baseball_mlb", "team": "Cubs", "opponent": "Cardinals",
         "odds": 120, "opponentOdds": -140, "confidence": "MODERATE_EDGE"}]},
]

try:
    for s in slates:
        result = optimize(s)
        print(result["allocation"]["totalStake"])
except DailyLimitReached as e:
    print(e)
