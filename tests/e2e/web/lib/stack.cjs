// The processes one run owns: FakeCore and the WASM page server in front of
// it, each on a free port. FakeCore can die and come back on the same port
// (7.1); nothing here touches a process it did not start.
"use strict";

const { spawn } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");
const readline = require("node:readline");

const root = path.resolve(__dirname, "../../../..");

// Starts `command` and resolves with it and its first stdout line, the
// readiness signal both servers print; rejects if it exits first.
function launch(command, args, env, log) {
  const child = spawn(command, args, {
    env: { ...process.env, ...env },
    stdio: ["ignore", "pipe", log],
  });
  return new Promise((resolve, reject) => {
    const lines = readline.createInterface({ input: child.stdout });
    const failed = (code) => reject(new Error(`${path.basename(command)} exited (${code}) before it was ready`));
    child.once("exit", failed);
    lines.once("line", (line) => {
      child.off("exit", failed);
      resolve({ child, line });
    });
  });
}

function stop(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null)
    return Promise.resolve();
  return new Promise((resolve) => {
    child.once("exit", resolve);
    child.kill("SIGTERM");
  });
}

class Stack {
  constructor({ site, fakecore, logDir }) {
    this.site = site;
    this.fakecore = fakecore;
    this.log = fs.openSync(path.join(logDir, "servers.log"), "a");
    this.servers = [];
    this.sites = new Map();
  }

  async start() {
    await this.startCore(0);
    this.webUrl = await this.serve(this.site);
  }

  // A page server for `site` on a free port, proxying FakeCore; its URL.
  // One per site for the whole run.
  async serve(site) {
    if (!this.sites.has(site)) {
      this.sites.set(site, launch("python3", [path.join(root, ".scripts/wasm-serve.py")], {
        MATOME_WASM_ROOT: site,
        MATOME_CORE: this.coreUrl,
        MATOME_WASM_PORT: "0",
      }, this.log).then(({ child, line }) => {
        this.servers.push(child);
        return line.split(/\s+/)[1];
      }));
    }
    return this.sites.get(site);
  }

  // FakeCore on `port` (0: any free one); a restart keeps the port so the
  // page server's proxy and the studio find it again.
  async startCore(port) {
    const { child, line } = await launch(this.fakecore, ["--port", String(port)], {}, this.log);
    this.core = child;
    this.coreUrl = line.split(/\s+/)[1];
    this.corePort = Number(new URL(this.coreUrl).port);
  }

  stopCore() {
    return stop(this.core);
  }

  async stop() {
    await Promise.all([...this.servers, this.core].map(stop));
    fs.closeSync(this.log);
  }
}

module.exports = { Stack };
