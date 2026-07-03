// Spike #1859 — Node.js floor baseline for Argon2id-WASM at the frozen
// `argon2id-v1-portable` params (see .docs/internal/at-rest-key-flow.md
// Appendix A.3). This is NOT the number that matters for the go/no-go (that's
// the real-browser measurement in bench.html) — it's a floor/sanity check run
// on the same WASM binary outside a browser's JS engine + tab throttling, so
// we can tell a slow browser number apart from a slow WASM build.
import { argon2id } from 'hash-wasm';

const PARAMS = {
  // frozen argon2id-v1-portable (task #1848 Appendix A.3) — DO NOT weaken here
  memorySize: 19456, // KiB (19 MiB)
  iterations: 2,
  parallelism: 1,
  hashLength: 32,
  outputType: 'hex',
};

const ITERATIONS = Number(process.argv[2] ?? 15);

function median(arr) {
  const s = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function stats(arr) {
  const s = [...arr].sort((a, b) => a - b);
  return {
    n: s.length,
    min: s[0],
    max: s[s.length - 1],
    median: median(s),
    mean: s.reduce((a, b) => a + b, 0) / s.length,
    p90: s[Math.floor(s.length * 0.9)] ?? s[s.length - 1],
  };
}

const times = [];
const salt = new Uint8Array(16).fill(7); // fixed salt fine for a latency spike (not a real key)
const password = 'correct horse battery staple spike-1859';

console.log(`Node baseline: argon2id, memorySize=${PARAMS.memorySize}KiB iterations=${PARAMS.iterations} parallelism=${PARAMS.parallelism}, ${ITERATIONS} iterations`);

for (let i = 0; i < ITERATIONS; i++) {
  const t0 = performance.now();
  // eslint-disable-next-line no-await-in-loop
  await argon2id({ password, salt, ...PARAMS });
  const t1 = performance.now();
  const ms = t1 - t0;
  times.push(ms);
  console.log(`  iter ${i + 1}/${ITERATIONS}: ${ms.toFixed(1)} ms`);
}

const s = stats(times);
console.log('\n--- Node baseline result (floor, no browser/tab throttling) ---');
console.log(JSON.stringify({ label: 'node-baseline', params: PARAMS, raw_ms: times, stats: s }, null, 2));
