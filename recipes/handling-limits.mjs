// Node 18 or later. Run: node handling-limits.mjs
const API = process.env.KELLYIQ_API_BASE ?? "https://api.kellyiq.com";
const KEY = process.env.KELLYIQ_API_KEY;
const RETRYABLE = ["BURST_LIMIT_EXCEEDED", "SERVICE_BUSY"];

class DailyLimitReached extends Error {}
const sleep = (s) => new Promise((r) => setTimeout(r, s * 1000));

/** POST /v1/optimize, waiting out per-minute limits and busy periods. */
async function optimize(body, maxAttempts = 5) {
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    const resp = await fetch(`${API}/v1/optimize`, {
      method: "POST",
      headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    if (resp.ok) {
      console.log("optimizes left today:", resp.headers.get("X-RateLimit-Remaining"));
      return resp.json();
    }

    // Not from the API (e.g. a proxy timeout page): treat it like SERVICE_BUSY.
    const err = await resp.json().catch(() => ({ error: "SERVICE_BUSY" }));

    if (err.error === "DAILY_LIMIT_EXCEEDED") {
      // Done for today. Retrying only adds to the count.
      throw new DailyLimitReached(`allowance used up; resets at ${err.resetsAt}`);
    }
    if (!RETRYABLE.includes(err.error)) {
      // A problem with the request itself: fix it rather than retry.
      throw new Error(`${resp.status} ${err.error}: ${err.violations ?? err.message} (request ${err.requestId})`);
    }
    if (attempt < maxAttempts) {
      const wait = Number(resp.headers.get("Retry-After") ?? 5);
      console.log(`${err.error}: waiting ${wait}s (attempt ${attempt})`);
      await sleep(wait);
    }
  }
  throw new Error(`still limited after ${maxAttempts} attempts`);
}

const slates = [
  { bankroll: 1000, picks: [{ sport: "baseball_mlb", team: "Dodgers", opponent: "Padres",
    odds: -145, opponentOdds: 125, confidence: "MODERATE_EDGE" }] },
  { bankroll: 1000, picks: [{ sport: "baseball_mlb", team: "Cubs", opponent: "Cardinals",
    odds: 120, opponentOdds: -140, confidence: "MODERATE_EDGE" }] },
];

try {
  for (const s of slates) {
    const result = await optimize(s);
    console.log(result.allocation.totalStake);
  }
} catch (e) {
  if (e instanceof DailyLimitReached) console.log(e.message);
  else throw e;
}
