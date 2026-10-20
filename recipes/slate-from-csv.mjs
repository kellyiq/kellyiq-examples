// Size every bet in slate.csv and write the stakes to stakes.csv.
// slate.csv columns: sport,team,opponent,odds,opponent_odds,confidence
// Node 18 or later. Simple CSV only: no commas or quotes inside fields.
import { readFileSync, writeFileSync } from "node:fs";

const API = process.env.KELLYIQ_API_BASE ?? "https://api.kellyiq.com";
const KEY = process.env.KELLYIQ_API_KEY;
const BANKROLL = 1000;

// Drop the byte-order mark Excel puts at the start of "CSV UTF-8" files.
const text = readFileSync("slate.csv", "utf8").replace(/^﻿/, "");
const [header, ...lines] = text.trim().split(/\r?\n/);
const cols = header.split(",").map((c) => c.trim());
const rows = lines.map((line) => Object.fromEntries(line.split(",").map((v, i) => [cols[i], v.trim()])));

const picks = rows.map((r, i) => ({
  id: String(i), // the row number, so results map back to rows
  sport: r.sport,
  team: r.team,
  opponent: r.opponent,
  odds: Number(r.odds),
  opponentOdds: Number(r.opponent_odds),
  confidence: r.confidence,
}));

const resp = await fetch(`${API}/v1/optimize`, {
  method: "POST",
  headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
  body: JSON.stringify({ bankroll: BANKROLL, picks }),
});
if (!resp.ok) {
  // A VALIDATION_ERROR lists every problem; picks[2].odds is the third data row.
  throw new Error(`HTTP ${resp.status}: ${(await resp.text()).slice(0, 500)}`);
}
const result = await resp.json();

const stakes = new Map(result.allocation.stakes.map((t) => [t.id, t.stake]));

const out = ["team,odds,stake,note"];
for (const p of result.picks) out.push([p.team, p.odds, stakes.get(p.id) ?? 0, p.reason ?? ""].join(","));
writeFileSync("stakes.csv", out.join("\n") + "\n");

console.log(`Wrote stakes.csv: ${stakes.size} of ${picks.length} bets, ` +
  `$${result.allocation.totalStake.toFixed(2)} in total (seed ${result.seed})`);
