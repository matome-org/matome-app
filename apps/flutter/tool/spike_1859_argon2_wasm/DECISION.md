# Spike #1859 — Argon2id-WASM latency on web (frozen `argon2id-v1-portable`)

**Plan:** `p1-unified-login-encryption` (#131), Wave-0 de-risk gate for #1860
(web OPFS encrypted store). **Status: spike only — not wired into production
login.**

## Question

The `argon2id-v1-portable` profile (frozen in `.docs/internal/at-rest-key-flow.md`
Appendix A.3, task #1848: memory=19456 KiB / iterations=2 / parallelism=1 /
argon2 v19 / 32-byte output) is deliberately sized for the **weakest** platform
in the fleet — browser Argon2id-WASM — because `wrapped_dek_pw` is wrapped
once and must unwrap identically on every device. This spike measures whether
that profile is actually fast enough in a real browser, on a real WASM build,
before #1860 builds the web store against it.

## Method

- Library: [`hash-wasm`](https://www.npmjs.com/package/hash-wasm) v4.12.0 (npm,
  MIT, actively maintained, WASM Argon2 build) — a reputable, general-purpose
  choice, not the antelle/argon2-browser build named as an example in the AC
  (both wrap the same reference Argon2 C implementation compiled to WASM; we
  used hash-wasm because it ships a ready UMD bundle with a clean
  `argon2id({password, salt, iterations, parallelism, memorySize, hashLength})`
  API matching the frozen params 1:1 — see `node_modules/hash-wasm/dist/lib/argon2.d.ts`).
- Params under test, unchanged from the frozen spec: `memorySize=19456` KiB,
  `iterations=2`, `parallelism=1`, `hashLength=32`, fixed 16-byte salt (salt
  value doesn't affect Argon2id cost).
- Browser: real Chromium 149.0.7827.200 (`chromium` on this host), driven
  headfully via the `chrome-devtools` MCP (`new_page` / `navigate_page` /
  `emulate` / `wait_for` / `evaluate_script`) — not a mock, not jsdom.
- Harness: `bench.html` + `bench.js` load `hash-wasm`'s standalone
  `argon2.umd.min.js` bundle over `http://127.0.0.1:8973` (served by
  `server.mjs`, a throwaway static file server — WASM needs a real origin, not
  `file://`). One warm-up call (excludes WASM compile/instantiate time from
  the measured series), then 12 timed calls via `performance.now()`.
- Mid-tier device proxy: **no physical mid-tier phone was available on this
  host.** Approximated via chrome-devtools `emulate(cpuThrottlingRate)` at 4x
  and 6x. This is a CPU-cycle-count proxy, not a real device measurement —
  memory-bandwidth-bound behavior (which Argon2id's random access pattern is
  sensitive to) can differ from a real low-end SoC in ways a pure clock-rate
  throttle doesn't capture. Treat the throttled numbers as directional, not
  exact.
- A Node.js (V8, no browser tab/JS-engine overhead) run of the identical
  `hash-wasm` build is included as a sanity floor, not as the go/no-go number.

## Results (median of n=12 runs each; full raw arrays + browser UA in `results/*.json`)

| Scenario | Median | Min–Max | n |
|---|---|---|---|
| Node.js baseline (floor, no browser) | 25.6 ms | 24.5–34.1 ms | 15 |
| Chromium, no throttle | 55.75 ms | 52.7–61.8 ms | 12 |
| Chromium, CPU throttle 4x (mid-tier proxy) | 225.5 ms | 221.3–233.4 ms | 12 |
| Chromium, CPU throttle 6x (mid-tier proxy) | 343.4 ms | 338.4–359.2 ms | 12 |

Spread is tight in every scenario (max − min stays within ~10-20 ms), i.e. the
measurement is stable, not just a lucky run.

**Login cost implication** (per Appendix A.3): a real login performs *two*
independent Argon2id hashes at this profile (`auth_secret` from `salt_auth`,
password-KEK from `salt_enc`). Doubling the worst measured single-hash number
here (343.4 ms × 2 ≈ 687 ms, run serially) still lands under 1 second even at
6x throttle; run in parallel (two Web Workers, as Appendix A.3 already
recommends), the wall-clock cost stays ~343 ms.

## Decision

**Even the throttled (mid-tier-proxy) numbers stay a few hundred milliseconds
— nowhere near the "several seconds" scenario the task description warns
about**, and nowhere near the point where weakening memory would be tempting.
No param change, no profile revisit needed for #1848.

- **memory is NOT reduced.** The frozen 19 MiB / t=2 / p=1 profile stands
  as-is on the web path.
- Recommended mitigation for UX, not security: run both Argon2id calls
  (`auth_secret`, password-KEK) in a **Web Worker** so the ~55-350 ms cost
  never blocks the main/UI thread, and show a brief spinner during login/
  unlock. This is exactly what Appendix A.3 already calls for ("#1849 should
  compute them in parallel where the runtime allows — e.g. separate Web
  Workers"). Moving the same computation into a worker does not change the
  bytes fed into Argon2id or the derived KEK — it is format-safe, no
  `format_version` or `kdf_params.profile` bump required.

## GO / NO-GO

**GO** on password-KEK for web at the frozen `argon2id-v1-portable` params.
Proceed with #1860 (web OPFS encrypted store) using this profile unmodified.
Recommend #1849 (crypto core) implements the two Argon2id calls off the main
thread via Web Worker as noted above; this is a UX nicety, not a blocker for
#1860.

## Caveats / honesty notes

- CPU throttling is a proxy for "mid-tier device," not a measurement on real
  mid-tier hardware. If a real low-end/mid-tier phone or Chromebook becomes
  available later, re-running `bench.html` on it would be worth doing before
  a public launch, but nothing here suggests it would flip the verdict — 6x
  clock throttle already gives ~6x the un-throttled cost with no non-linear
  blowup, so a real device would have to be dramatically more constrained
  than a 6x slowdown to approach 1s per hash.
- Only one WASM Argon2id build (hash-wasm) was benchmarked. Different WASM
  builds (e.g. antelle/argon2-browser) could differ by some constant factor,
  but the margin here (343 ms vs. a ~1000 ms threshold) leaves headroom for
  that.
- This is a throwaway spike harness (local static server, fixed test salt/
  password, no error handling) — it must not be imported into or reused by
  production login code. #1849 should implement Argon2id-in-worker fresh
  against the real `/keybundle` contract.

## How to reproduce

```bash
cd apps/flutter/tool/spike_1859_argon2_wasm
npm install
node run_node_baseline.mjs 15        # Node floor baseline

node server.mjs &                     # serves bench.html on :8973
# then, via chrome-devtools MCP or by hand in a real browser:
#   open http://127.0.0.1:8973/bench.html?runs=12
#   (optionally apply chrome-devtools `emulate(cpuThrottlingRate=4|6)` first)
#   wait for "DONE", read the JSON blob printed on the page
```

## Files

- `package.json` — spike-only manifest, `hash-wasm` dependency
- `run_node_baseline.mjs` — Node floor baseline
- `server.mjs` — throwaway static file server for the browser bench page
- `bench.html`, `bench.js` — the browser benchmark (frozen params, 12 timed
  runs + 1 warm-up, auto-runs on load)
- `results/node_baseline.json.txt` — raw Node baseline output (n=15)
- `results/browser_unthrottled.json` — raw browser result, no throttle (n=12)
- `results/browser_throttle_4x.json` — raw browser result, 4x CPU throttle (n=12)
- `results/browser_throttle_6x.json` — raw browser result, 6x CPU throttle (n=12)
