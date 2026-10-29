// Slate sizing benchmark: exact references and scoring. See README.md.
//
//   node score.mjs                         references only
//   node score.mjs kellyiq-results.json    references, then score every allocation in the file
//
// Results shape: { "<method>": { "<run>": { "A": { "A1": 123.45, ... }, "B": {...}, "C": {...} } } }
// Stakes are dollars on the bankroll in slates.json. A missing id means a $0 stake.
//
// Everything here is exact: expected values are sums over all 2^n win/loss outcomes, no sampling.
// Node 18+, no packages.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const spec = JSON.parse(readFileSync(join(here, "slates.json"), "utf8"));
const { bankroll, kellyFraction, perBetCap, maxTotalExposure } = spec.request;

// Net payout per $1 staked on a win, from American odds.
const netOdds = (a) => (a > 0 ? a / 100 : 100 / -a);

// ---- exact outcome tables ----------------------------------------------------------------

function outcomeTable(bets) {
  const n = bets.length, m = 1 << n;
  const prob = new Float64Array(m);
  prob[0] = 1;
  for (let i = 0; i < n; i++) prob[0] *= 1 - bets[i].p;
  for (let mask = 1; mask < m; mask++) {
    const i = 31 - Math.clz32(mask);               // highest set bit
    const prev = mask ^ (1 << i);
    prob[mask] = (prob[prev] / (1 - bets[i].p)) * bets[i].p;
  }
  return { n, m, prob };
}

// Portfolio return for every outcome: R[mask] = sum_i s_i * (win ? b_i : -1).
function returns(bets, s, table) {
  const { n, m } = table;
  const R = new Float64Array(m);
  let base = 0;
  for (let i = 0; i < n; i++) base -= s[i];
  R[0] = base;
  for (let mask = 1; mask < m; mask++) {
    const i = 31 - Math.clz32(mask);
    R[mask] = R[mask ^ (1 << i)] + s[i] * (bets[i].b + 1);
  }
  return R;
}

// Expected log growth (gamma = 1) or CRRA utility (gamma > 1), and its gradient.
function evalObjective(bets, s, table, gamma, wantGrad) {
  const R = returns(bets, s, table);
  const { n, m, prob } = table;
  let value = 0;
  const weight = wantGrad ? new Float64Array(m) : null;
  for (let mask = 0; mask < m; mask++) {
    const w = 1 + R[mask];
    if (w <= 1e-12) return { value: -Infinity };
    if (gamma === 1) value += prob[mask] * Math.log(w);
    else value += prob[mask] * Math.pow(w, 1 - gamma) / (1 - gamma);
    if (wantGrad) weight[mask] = prob[mask] * Math.pow(w, -gamma);
  }
  if (!wantGrad) return { value };
  // d/ds_i = sum_o weight(o) * r_i(o) = b_i * S_i - (T - S_i), S_i = sum over outcomes where i wins.
  let T = 0;
  const S = new Float64Array(n);
  for (let mask = 0; mask < m; mask++) {
    const w = weight[mask];
    T += w;
    for (let i = 0; i < n; i++) if (mask & (1 << i)) S[i] += w;
  }
  const grad = Array.from(S, (Si, i) => bets[i].b * Si - (T - Si));
  return { value, grad };
}

// Projection onto { 0 <= s_i <= ub_i, sum s <= budget }.
function project(x, ub, budget) {
  const clip = (t) => x.map((v, i) => Math.min(Math.max(v - t, 0), ub[i]));
  let s = clip(0);
  if (s.reduce((a, v) => a + v, 0) <= budget) return s;
  let lo = 0, hi = Math.max(...x);
  for (let k = 0; k < 200; k++) {
    const mid = (lo + hi) / 2;
    if (clip(mid).reduce((a, v) => a + v, 0) > budget) lo = mid; else hi = mid;
  }
  return clip(hi);
}

// Projected gradient ascent with backtracking. Concave objective, convex set: converges to the optimum.
function maximize(bets, table, gamma, ub, budget, start) {
  let s = project(start ?? bets.map(() => 0), ub, budget);
  let cur = evalObjective(bets, s, table, gamma, true);
  // A start that stakes the whole bankroll makes the all-lose outcome log(0); shrink it until finite.
  while (!Number.isFinite(cur.value)) {
    s = s.map((v) => v * 0.5);
    cur = evalObjective(bets, s, table, gamma, true);
  }
  let step = 0.05;
  for (let it = 0; it < 4000; it++) {
    let moved = false;
    for (let tries = 0; tries < 60; tries++) {
      const cand = project(s.map((v, i) => v + step * cur.grad[i]), ub, budget);
      const next = evalObjective(bets, cand, table, gamma, true);
      if (next.value >= cur.value - 1e-18) {
        const delta = Math.max(...cand.map((v, i) => Math.abs(v - s[i])));
        s = cand; cur = next; moved = delta > 1e-13; step *= 1.5;
        break;
      }
      step /= 2;
    }
    if (!moved) break;
  }
  return s;
}

const singleKelly = (bet) => Math.max(0, (bet.b * bet.p - (1 - bet.p)) / bet.b);

// Scale stakes down proportionally if their total exceeds the limit (after clipping each to the cap).
function clipAndScale(s, cap, total) {
  const c = s.map((v) => Math.min(v, cap));
  const sum = c.reduce((a, v) => a + v, 0);
  return sum > total ? c.map((v) => (v * total) / sum) : c;
}

// ---- references ----------------------------------------------------------------------------

// R1, cap then scale: single-bet Kelly per bet, times the fraction, clip to the per-bet cap,
//   then scale every stake down by the same factor if the total is over the slate limit.
// R3, constrained optimum: maximize CRRA utility with risk aversion 1 / kellyFraction (4 for
//   quarter Kelly) subject to both limits, solved exactly over every outcome.
function references(bets) {
  const table = outcomeTable(bets);
  const r1 = clipAndScale(bets.map((b) => kellyFraction * singleKelly(b)), perBetCap, maxTotalExposure);
  const r3 = maximize(bets, table, 1 / kellyFraction, bets.map(() => perBetCap), maxTotalExposure, r1);
  return { table, refs: { R1: r1, R3: r3 } };
}

// ---- reporting -----------------------------------------------------------------------------

const money = (f) => (f * bankroll).toFixed(2);
const growthBps = (bets, table, s) => evalObjective(bets, s, table, 1, false).value * 1e4;

const slates = {};
for (const [name, raw] of Object.entries(spec.slates)) {
  const bets = raw.map((x) => ({ ...x, b: netOdds(x.odds) }));
  slates[name] = { bets, ...references(bets) };
}

console.log("Slate sizing benchmark: exact references");
console.log(`Request: $${bankroll} bankroll, ${kellyFraction} Kelly, ${perBetCap * 100}% per bet, ${maxTotalExposure * 100}% total\n`);
for (const [name, { bets, table, refs }] of Object.entries(slates)) {
  console.log(`Slate ${name} (${bets.length} bets)`);
  console.log("  id      odds      p        R1        R3");
  bets.forEach((b, i) => {
    console.log(`  ${b.id.padEnd(4)} ${String(b.odds).padStart(6)}  ${b.p.toFixed(3)}  ${money(refs.R1[i]).padStart(8)}  ${money(refs.R3[i]).padStart(8)}`);
  });
  const tot = (k) => money(refs[k].reduce((a, v) => a + v, 0)).padStart(8);
  console.log(`  total                ${tot("R1")}  ${tot("R3")}`);
  console.log(`  expected log growth, bps of bankroll per slate: R1 ${growthBps(bets, table, refs.R1).toFixed(3)}, R3 ${growthBps(bets, table, refs.R3).toFixed(3)}\n`);
}

// ---- scoring -------------------------------------------------------------------------------

const resultsPath = process.argv[2];
if (resultsPath) {
  const results = JSON.parse(readFileSync(resultsPath, "utf8"));
  console.log("Scoring");
  for (const [method, runs] of Object.entries(results)) {
    console.log(`\n== ${method}`);
    const byStake = {};
    for (const [run, ans] of Object.entries(runs)) {
      for (const name of Object.keys(slates)) {
        const { bets, table, refs } = slates[name];
        const got = ans[name];
        if (!got) { console.log(`  ${run} ${name}: no allocation`); continue; }
        const s = bets.map((b) => (got[b.id] ?? 0) / bankroll);
        const total = s.reduce((a, v) => a + v, 0);
        const capOk = s.every((v) => v <= perBetCap + 1e-9);
        const totOk = total <= maxTotalExposure + 1e-9;
        const g = growthBps(bets, table, s);
        const vs = (k) => {
          const pct = (g / growthBps(bets, table, refs[k]) - 1) * 100;
          return `${pct >= 0 ? "+" : ""}${pct.toFixed(1)}% vs ${k}`;
        };
        console.log(`  ${run} ${name}: total $${money(total)}, per-bet cap ${capOk ? "ok" : "EXCEEDED"}, slate limit ${totOk ? "ok" : "EXCEEDED"}, growth ${g.toFixed(3)} bps (${vs("R1")}, ${vs("R3")})`);
        (byStake[name] ??= []).push(bets.map((b) => got[b.id] ?? 0));
      }
    }
    for (const [name, vecs] of Object.entries(byStake)) {
      if (vecs.length < 2) continue;
      let worst = 0;
      for (let i = 0; i < vecs[0].length; i++) {
        const col = vecs.map((v) => v[i]);
        worst = Math.max(worst, Math.max(...col) - Math.min(...col));
      }
      console.log(`  repeatability ${name}: largest single-stake difference across ${vecs.length} runs $${worst.toFixed(2)}`);
    }
  }
}
