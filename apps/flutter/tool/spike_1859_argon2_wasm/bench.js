// Spike #1859 — real-browser Argon2id-WASM latency bench.
// Frozen params (task #1848, Appendix A.3, `argon2id-v1-portable`) — do NOT
// change these values in this file. If you conclude they're too slow, that is
// a finding for #1848 (new profile + format bump), not something to patch
// here.
const PARAMS = Object.freeze({
  memorySize: 19456, // KiB (19 MiB)
  iterations: 2,
  parallelism: 1,
  hashLength: 32,
  outputType: 'hex',
});

const DEFAULT_RUNS = 12;

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

async function runBench(runs = DEFAULT_RUNS) {
  const statusEl = document.getElementById('status');
  const outEl = document.getElementById('output');
  const times = [];
  const salt = new Uint8Array(16).fill(7);
  const password = 'correct horse battery staple spike-1859';

  statusEl.textContent = `running (0/${runs})...`;

  // one warm-up run so WASM compilation isn't counted in the measured series
  await window.hashwasm.argon2id({ password, salt, ...PARAMS });

  for (let i = 0; i < runs; i++) {
    const t0 = performance.now();
    // eslint-disable-next-line no-await-in-loop
    await window.hashwasm.argon2id({ password, salt, ...PARAMS });
    const t1 = performance.now();
    times.push(t1 - t0);
    statusEl.textContent = `running (${i + 1}/${runs})...`;
  }

  const result = {
    label: window.__BENCH_LABEL__ || 'browser',
    userAgent: navigator.userAgent,
    hardwareConcurrency: navigator.hardwareConcurrency,
    params: PARAMS,
    raw_ms: times,
    stats: stats(times),
  };

  statusEl.textContent = 'DONE';
  outEl.textContent = JSON.stringify(result, null, 2);
  window.__BENCH_RESULT__ = result;
  return result;
}

window.runBench = runBench;
// Auto-run so a plain page load (or chrome-devtools `wait_for` on "DONE") is
// enough to drive the whole thing without a manual click.
runBench(Number(new URLSearchParams(location.search).get('runs')) || DEFAULT_RUNS);
