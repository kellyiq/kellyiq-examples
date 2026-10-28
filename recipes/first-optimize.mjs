// Node 18 or later (built-in fetch). Run: node first-optimize.mjs
const API = process.env.KELLYIQ_API_BASE ?? "https://api.kellyiq.com";
const KEY = process.env.KELLYIQ_API_KEY;

const slate = {
  bankroll: 1000,
  picks: [
    { id: "lad", sport: "baseball_mlb", team: "Dodgers", opponent: "Padres",
      odds: -145, opponentOdds: 125, confidence: "MODERATE_EDGE" },
    { id: "chc", sport: "baseball_mlb", team: "Cubs", opponent: "Cardinals",
      odds: 120, opponentOdds: -140, confidence: "MODERATE_EDGE" },
    { id: "nyy", sport: "baseball_mlb", team: "Yankees", opponent: "Red Sox",
      odds: -110, opponentOdds: -110, confidence: "MARKET" },
  ],
};

const resp = await fetch(`${API}/v1/optimize`, {
  method: "POST",
  headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
  body: JSON.stringify(slate),
});
if (!resp.ok) {
  // API errors are JSON; a proxy timeout may not be, so show the raw text.
  throw new Error(`HTTP ${resp.status}: ${(await resp.text()).slice(0, 500)}`);
}
const result = await resp.json();

const usd = (n) => `${n < 0 ? "-" : ""}$${Math.abs(n).toFixed(2)}`;
const odds = (n) => (n > 0 ? `+${n}` : `${n}`);

// 1. The allocation: how much to stake on each bet.
const alloc = result.allocation;
if (alloc.kellyMultiplier !== null) {
  console.log(`Allocation: ${alloc.kellyMultiplier.toFixed(2)}x Kelly, ${usd(alloc.totalStake)} in total`);
}
for (const t of alloc.stakes) console.log(`  ${usd(t.stake).padStart(9)}  ${t.team} ${odds(t.odds)}`);

// 2. What happened to each pick, including the ones with no stake.
console.log();
for (const p of result.picks) {
  console.log(`${p.team} ${odds(p.odds)}: ${p.included ? "staked" : `no stake (${p.reason})`}`);
}

// 3. The allocation's risk, from 100,000 simulated slates.
const risk = result.risk.allocation.independent;
if (risk) {
  console.log(`\nAverage profit ${usd(risk.meanProfit)}, chance of losing money ${Math.round(risk.probLoss * 100)}%, ` +
    `worst 5% average ${usd(risk.cvar5)}`);
}

// 4. The settings that were used, and where each came from.
console.log();
for (const [name, s] of Object.entries(result.settingsApplied)) {
  console.log(`${name}: ${s.value} (from ${s.source})`);
}
for (const w of result.warnings) console.log("warning:", w);

// 5. Keep these with the result: with the request, they reproduce it exactly.
console.log(`\nseed=${result.seed} engine=${result.engineVersion} request=${result.requestId}`);
