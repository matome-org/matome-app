import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createAiAdapterServer } from "./server.js";

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address();
      resolve(`http://127.0.0.1:${port}`);
    });
  });
}

function collectJson(req) {
  return new Promise((resolve) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => resolve(JSON.parse(body || "{}")));
  });
}

// Real 1s WAV via ffmpeg — exercises the actual transcode path.
async function makeWav() {
  const dir = await mkdtemp(join(tmpdir(), "adapter-test-"));
  const path = join(dir, "tone.wav");
  await new Promise((resolve, reject) => {
    const ff = spawn("ffmpeg", [
      "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
      "-ar", "16000", "-ac", "1", path
    ], { stdio: "ignore" });
    ff.on("close", (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg exit ${code}`))));
    ff.on("error", reject);
  });
  return { dir, bytes: await readFile(path) };
}

function job(mediaUrl, callbackUrl, overrides = {}) {
  return {
    job_id: "item:1:file_blob:2",
    recording_id: 1,
    media_type: "audio",
    storage_key: "media/rec-1.m4a",
    media: { method: "GET", url: mediaUrl },
    callback: { method: "POST", url: callbackUrl },
    ...overrides
  };
}

test("bridges a job: fetch media → transcode → whisper → transcript callback", async () => {
  const wav = await makeWav();
  const mediaServer = createServer((req, res) => {
    res.writeHead(200, { "content-type": "audio/wav" });
    res.end(wav.bytes);
  });
  const mediaBase = await listen(mediaServer);

  // Fake whisper API — assert it received a multipart file, return canned text.
  let gotUpload = false;
  const audioApi = createServer((req, res) => {
    gotUpload = (req.headers["content-type"] || "").includes("multipart/form-data");
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ text: "bridge transcript ok", language: "en", duration_sec: 1 }));
  });
  const audioBase = await listen(audioApi);

  const callbacks = [];
  const core = createServer(async (req, res) => {
    callbacks.push({ auth: req.headers.authorization, body: await collectJson(req) });
    res.writeHead(204);
    res.end();
  });
  const coreBase = await listen(core);

  const adapter = createAiAdapterServer({
    token: "test-token",
    audioApiEndpoint: `${audioBase}/api/v1/transcribe`
  });
  const adapterBase = await listen(adapter);

  try {
    const res = await fetch(`${adapterBase}/v1/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: "Bearer test-token" },
      body: JSON.stringify(job(`${mediaBase}/rec.wav`, `${coreBase}/internal/jobs/item:1:file_blob:2/result`))
    });
    assert.equal(res.status, 202);
    assert.deepEqual(await res.json(), { job_id: "item:1:file_blob:2", accepted: true });

    await waitFor(() => callbacks.length === 1);
    assert.equal(gotUpload, true, "whisper API should receive a multipart upload");
    assert.equal(callbacks[0].auth, "Bearer test-token");
    assert.equal(callbacks[0].body.status, "done");
    assert.equal(callbacks[0].body.job_id, "item:1:file_blob:2");
    assert.equal(callbacks[0].body.transcript, "bridge transcript ok");
  } finally {
    adapter.close(); core.close(); audioApi.close(); mediaServer.close();
    await rm(wav.dir, { recursive: true, force: true });
  }
});

test("rejects a job without the configured bearer token", async () => {
  const adapter = createAiAdapterServer({ token: "test-token" });
  const base = await listen(adapter);
  try {
    const res = await fetch(`${base}/v1/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(job("http://127.0.0.1/x", "http://127.0.0.1/cb"))
    });
    assert.equal(res.status, 401);
  } finally {
    adapter.close();
  }
});

test("posts a failed callback for a non-audio media type", async () => {
  const callbacks = [];
  const core = createServer(async (req, res) => {
    callbacks.push(await collectJson(req));
    res.writeHead(204); res.end();
  });
  const coreBase = await listen(core);

  const adapter = createAiAdapterServer({ token: "test-token", audioApiEndpoint: "http://127.0.0.1:1/x" });
  const base = await listen(adapter);
  try {
    const res = await fetch(`${base}/v1/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: "Bearer test-token" },
      body: JSON.stringify(job("http://127.0.0.1/x", `${coreBase}/cb`, { media_type: "image" }))
    });
    assert.equal(res.status, 202);
    await waitFor(() => callbacks.length === 1);
    assert.equal(callbacks[0].status, "failed");
    assert.equal(callbacks[0].error.code, "unsupported_media_type");
  } finally {
    adapter.close(); core.close();
  }
});

test("posts a failed callback when the media URL is unreachable", async () => {
  const callbacks = [];
  const core = createServer(async (req, res) => {
    callbacks.push(await collectJson(req));
    res.writeHead(204); res.end();
  });
  const coreBase = await listen(core);

  const adapter = createAiAdapterServer({ token: "test-token", audioApiEndpoint: "http://127.0.0.1:1/x" });
  const base = await listen(adapter);
  try {
    const res = await fetch(`${base}/v1/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: "Bearer test-token" },
      body: JSON.stringify(job("http://127.0.0.1:1/missing.wav", `${coreBase}/cb`))
    });
    assert.equal(res.status, 202);
    await waitFor(() => callbacks.length === 1);
    assert.equal(callbacks[0].status, "failed");
    assert.equal(callbacks[0].error.code, "transcription_failed");
  } finally {
    adapter.close(); core.close();
  }
});

function waitFor(pred, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const tick = () => {
      if (pred()) return resolve();
      if (Date.now() - start > timeoutMs) return reject(new Error("timeout waiting for condition"));
      setTimeout(tick, 20);
    };
    tick();
  });
}
