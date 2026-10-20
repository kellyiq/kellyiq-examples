// Node 18 or later. Run: node reproducible-results.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { isDeepStrictEqual } from "node:util";

const API = process.env.KELLYIQ_API_BASE ?? "https://api.kellyiq.com";
const KEY = process.env.KELLYIQ_API_KEY;

const slate = {
  bankroll: 1000,
  // Settings in the request, not from your app settings, which you might change later.
  maxTotalExposure: 0.5,
  perBetCap: 0.2,
  useAccountDefaults: false,
  picks: [
    { id: "lad", sport: "baseball_mlb", team: "Dodgers", opponent: "Padres",
      odds: -145, opponentOdds: 125, confidence: "STRONG_EDGE" },
    { id: "chc", sport: "baseball_mlb", team: "Cubs", opponent: "Cardinals",
      odds: 120, opponentOdds: -140, confidence: "MODERATE_EDGE" },
  ],
};

async function optimize(body) {
  const resp = await fetch(`${API}/v1/optimize`, {
    method: "POST",
    headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!resp.ok) throw new Error(`HTTP ${resp.status}: ${(await resp.text()).slice(0, 500)}`);
  return resp.json();
}

// First run: no seed, so the server picks one and returns it.
const first = await optimize(slate);

// Store the request and what produced the result, together.
const record = {
  request: slate,
  seed: first.seed,
  engineVersion: first.engineVersion,
  stakes: first.allocation.stakes,
};
writeFileSync("result.json", JSON.stringify(record, null, 2));

// Later: resend the same request with the stored seed.
const saved = JSON.parse(readFileSync("result.json", "utf8"));
const again = await optimize({ ...saved.request, seed: saved.seed });

if (again.engineVersion !== saved.engineVersion) {
  console.log("The engine has changed since this result was stored, so numbers may differ.");
}
const same = isDeepStrictEqual(again.allocation.stakes, saved.stakes);
console.log("Identical allocation:", same);
if (!same) process.exitCode = 1;
