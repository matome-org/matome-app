#!/usr/bin/env node
// The Web e2e suite: the e2e WASM build in Chromium against FakeCore, one
// fresh browser context per scenario, in two profiles (desktop: 1280×800
// mouse and keyboard; mobile: a Pixel-sized touch phone). Started by
// .scripts/e2e.sh, which builds what it needs and passes the paths:
//
//   MATOME_E2E_SITE      the e2e build (studio + probe)
//   MATOME_E2E_PRODUCT   the shipped build (7.5 boots it untouched)
//   MATOME_E2E_FAKECORE  .scripts/fakecore.sh (builds, then runs FakeCore)
//   MATOME_CHROMIUM      the browser (default /usr/bin/chromium)
//   MATOME_E2E_LOGS      where server logs and failure screenshots go
//
// Args: --profile desktop|mobile (repeatable; default both), --grep <regex>
// on "<id> <title>", --repeat <n>.
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { chromium, devices } = require("playwright");
const { Stack } = require("./lib/stack.cjs");
const { Core } = require("./lib/core.cjs");
const { Studio } = require("./lib/studio.cjs");

const PROFILES = {
  desktop: { viewport: { width: 1280, height: 800 }, isMobile: false, hasTouch: false },
  mobile: { ...devices["Pixel 7"] },
};
// Every context starts English, light, and animated unless a scenario says
// otherwise, so the machine running the suite never leaks in.
const CONTEXT = { locale: "en-US", colorScheme: "light", reducedMotion: "no-preference", acceptDownloads: true };

const SCENARIOS = ["auth", "navigation", "files", "interaction", "responsive", "look", "robustness"];

function parseArgs(argv) {
  const args = { profiles: [], grep: null, repeat: 1 };
  for (let i = 0; i < argv.length; ++i) {
    if (argv[i] === "--profile")
      args.profiles.push(argv[++i]);
    else if (argv[i] === "--grep")
      args.grep = new RegExp(argv[++i]);
    else if (argv[i] === "--repeat")
      args.repeat = Number(argv[++i]);
    else
      throw new Error(`unknown argument ${argv[i]}`);
  }
  if (args.profiles.length === 0)
    args.profiles = Object.keys(PROFILES);
  for (const name of args.profiles) {
    if (!PROFILES[name])
      throw new Error(`unknown profile ${name} (desktop|mobile)`);
  }
  return args;
}

function need(name) {
  const value = process.env[name];
  if (!value)
    throw new Error(`${name} is not set; run .scripts/e2e.sh`);
  return value;
}

// scenario(id, title, profiles, body, options): options.context adds
// browser-context options; options.load false leaves the page unloaded.
function collect() {
  const list = [];
  const scenario = (id, title, profiles, body, options = {}) =>
    list.push({ id, title, profiles, body, options });
  for (const file of SCENARIOS)
    require(`./scenarios/${file}.cjs`)(scenario);
  return list;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const logs = need("MATOME_E2E_LOGS");
  fs.mkdirSync(logs, { recursive: true });
  const stack = new Stack({ site: need("MATOME_E2E_SITE"), fakecore: need("MATOME_E2E_FAKECORE"), logDir: logs });
  const product = need("MATOME_E2E_PRODUCT");
  const core = new Core(stack);
  const scenarios = collect().filter((s) => !args.grep || args.grep.test(`${s.id} ${s.title}`));
  const started = Date.now();
  let failed = 0;
  let passed = 0;

  await stack.start();
  let browser = null;
  try {
    browser = await chromium.launch({
      executablePath: process.env.MATOME_CHROMIUM || "/usr/bin/chromium",
      args: ["--headless=new", "--no-sandbox", "--enable-webgl", "--ignore-gpu-blocklist", "--use-gl=angle"],
    });
    for (let round = 1; round <= args.repeat; ++round) {
      for (const profile of args.profiles) {
        for (const s of scenarios.filter((each) => each.profiles.includes(profile))) {
          const label = `${s.id} ${profile} ${s.title}`;
          const clock = Date.now();
          const context = await browser.newContext({ ...PROFILES[profile], ...CONTEXT, ...s.options.context });
          const page = await context.newPage();
          const studio = new Studio(page, stack, PROFILES[profile]);
          try {
            await core.reset();
            if (s.options.load !== false)
              await studio.load();
            await s.body({ studio, core, stack, page, context, product });
            if (studio.errors.length)
              throw new Error(`page errors: ${studio.errors.join("; ")}`);
            ++passed;
            console.log(`ok   ${label} (${((Date.now() - clock) / 1000).toFixed(1)}s)`);
          } catch (err) {
            ++failed;
            // Cells repeat across scenarios; the title tells their shots apart.
            const shot = path.join(logs, `${s.id}-${profile}-${s.title}`.replace(/[^\w.-]+/g, "_") + ".png");
            await page.screenshot({ path: shot }).catch(() => {});
            console.log(`FAIL ${label}\n     ${String(err && err.stack || err).split("\n").join("\n     ")}\n     screenshot ${shot}`);
          } finally {
            await context.close();
            // A scenario that stopped FakeCore gives it back to the next one.
            if (stack.core.exitCode !== null || stack.core.signalCode !== null)
              await stack.startCore(stack.corePort);
          }
        }
      }
    }
  } finally {
    if (browser)
      await browser.close();
    await stack.stop();
  }
  const seconds = ((Date.now() - started) / 1000).toFixed(0);
  console.log(`web e2e: ${passed} passed, ${failed} failed in ${seconds}s`);
  process.exit(failed ? 1 : 0);
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
});
