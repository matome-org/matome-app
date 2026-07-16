import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { registerV1ServiceConformance } from "../../../contracts/v1/service-conformance.mjs";
import { createAiAdapterServer } from "./server.js";

const capabilities = {
  contract_version: "1",
  service: "matome-ai-audio-adapter",
  inputs: {
    audio: {
      enabled: true,
      max_bytes: 2_147_483_648,
      content_types: ["audio/wav", "audio/mpeg", "application/octet-stream"],
      outputs: ["transcript"]
    }
  }
};

let wavPromise;

registerV1ServiceConformance({
  test,
  createServer: createAiAdapterServer,
  capabilities,
  makeMediaBytes: () => (wavPromise ??= makeWav()),
  productionOptions: { audioApiEndpoint: "https://processor.invalid/transcribe" },
  startProcessor: async () => {
    const server = createServer((req, res) => {
      req.resume();
      res.writeHead(200, { "content-type": "application/json" });
      res.end(JSON.stringify({ text: "Fixture audio transcript." }));
    });
    const baseUrl = await listen(server);
    return {
      options: { audioApiEndpoint: `${baseUrl}/api/v1/transcribe` },
      close: () => close(server)
    };
  }
});

test("audio adapter production config requires a secure transcription endpoint", () => {
  assert.throws(
    () =>
      createAiAdapterServer({
        production: true,
        dataDir: "/tmp/matome-ai-adapter-test",
        dispatchToken: "p".repeat(32),
        audioApiEndpoint: "http://processor.internal/transcribe"
      }),
    /HTTPS audio API endpoint/
  );
});

test.after(async () => {
  const wav = await wavPromise;
  if (wav?.dir) await rm(wav.dir, { recursive: true, force: true });
});

async function makeWav() {
  const dir = await mkdtemp(join(tmpdir(), "adapter-test-"));
  const path = join(dir, "tone.wav");
  await new Promise((resolve, reject) => {
    const ffmpeg = spawn(
      "ffmpeg",
      [
        "-y",
        "-f",
        "lavfi",
        "-i",
        "sine=frequency=440:duration=0.1",
        "-ar",
        "16000",
        "-ac",
        "1",
        path
      ],
      { stdio: "ignore" }
    );
    ffmpeg.on("close", (code) =>
      code === 0 ? resolve() : reject(new Error(`ffmpeg exit ${code}`))
    );
    ffmpeg.on("error", reject);
  });
  const bytes = await readFile(path);
  bytes.dir = dir;
  return bytes;
}

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      resolve(`http://127.0.0.1:${server.address().port}`);
    });
  });
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}
