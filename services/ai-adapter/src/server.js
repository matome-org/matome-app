import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { readFile, writeFile, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

// The whisper API transcribes audio only. Core dispatches audio|image; image
// (OCR) has no counterpart on the audio API, so it is reported unsupported.
const AUDIO_MEDIA_TYPES = new Set(["audio", "meeting"]);

// Bridge: speaks the Core AI-engine dialect (async POST /v1/jobs → 202, then a
// callback POST to job.callback.url) on the front, and the synchronous whisper
// API (multipart POST → {text}) on the back. Fetches the presigned media URL,
// transcodes to 16k mono WAV (whisper's accepted format), transcribes, and
// posts {transcript} back to Core.
export function createAiAdapterServer(options = {}) {
  const config = {
    token: options.token ?? process.env.AI_ENGINE_TOKEN ?? "",
    audioApiEndpoint:
      options.audioApiEndpoint ??
      process.env.AUDIO_API_ENDPOINT ??
      "http://localhost:8000/api/v1/transcribe",
    fetchImpl: options.fetchImpl ?? globalThis.fetch,
    ...options
  };

  return createServer(async (req, res) => {
    try {
      if (req.method === "GET" && req.url === "/health") {
        sendJson(res, 200, { ok: true, service: "matome-ai-adapter" });
        return;
      }

      if (req.method !== "POST" || req.url !== "/v1/jobs") {
        sendJson(res, 404, { error: "not_found" });
        return;
      }

      if (!isAuthorized(req, config.token)) {
        sendJson(res, 401, { error: "unauthorized" });
        return;
      }

      const job = await readJson(req);
      const validationError = validateJob(job);

      if (validationError) {
        sendJson(res, 400, { error: validationError });
        return;
      }

      // Ack immediately (Core expects 202); the real work runs async and
      // reports back via the callback URL, exactly like the stub.
      processJob(job, config).catch((error) => {
        console.error("AI adapter job failed", error);
      });

      sendJson(res, 202, { job_id: job.job_id, accepted: true });
    } catch (error) {
      sendJson(res, 400, { error: error.message });
    }
  });
}

async function processJob(job, config) {
  try {
    if (!AUDIO_MEDIA_TYPES.has(job.media_type)) {
      await sendCallback(job, config, {
        status: "failed",
        error: {
          code: "unsupported_media_type",
          message: `adapter transcribes audio only, got ${job.media_type}`
        }
      });
      return;
    }

    const transcript = await transcribe(job.media.url, config);
    await sendCallback(job, config, { status: "done", transcript, summary: null });
  } catch (error) {
    await sendCallback(job, config, {
      status: "failed",
      error: { code: "transcription_failed", message: String(error?.message ?? error) }
    }).catch((cbError) => console.error("AI adapter failure callback failed", cbError));
  }
}

async function transcribe(mediaUrl, config) {
  const dir = await mkdtemp(join(tmpdir(), "matome-adapter-"));
  const src = join(dir, "src");
  const wav = join(dir, "audio.wav");

  try {
    const response = await config.fetchImpl(mediaUrl, { method: "GET" });
    if (!response.ok) throw new Error(`media fetch HTTP ${response.status}`);
    await writeFile(src, Buffer.from(await response.arrayBuffer()));

    await ffmpegToWav(src, wav);

    const wavBuffer = await readFile(wav);
    const form = new FormData();
    form.append("file", new Blob([wavBuffer], { type: "audio/wav" }), "audio.wav");

    const result = await config.fetchImpl(config.audioApiEndpoint, {
      method: "POST",
      body: form
    });
    if (!result.ok) throw new Error(`audio API HTTP ${result.status}`);

    const data = await result.json();
    if (typeof data.text !== "string") throw new Error("audio API response missing 'text'");
    return data.text;
  } finally {
    await rm(dir, { recursive: true, force: true }).catch(() => {});
  }
}

// Transcode any input Core hands us (m4a/webm/mp4/…) to 16 kHz mono WAV — the
// format whisper's endpoint accepts — regardless of the source container.
function ffmpegToWav(src, out) {
  return new Promise((resolve, reject) => {
    const ff = spawn("ffmpeg", ["-y", "-i", src, "-ar", "16000", "-ac", "1", out], {
      stdio: ["ignore", "ignore", "pipe"]
    });
    let stderr = "";
    ff.stderr.on("data", (chunk) => (stderr += chunk));
    ff.on("close", (code) =>
      code === 0 ? resolve() : reject(new Error(`ffmpeg exit ${code}: ${stderr.slice(-300)}`))
    );
    ff.on("error", reject);
  });
}

async function sendCallback(job, config, extra) {
  const body = { job_id: job.job_id, recording_id: job.recording_id, ...extra };

  const response = await config.fetchImpl(job.callback.url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(config.token ? { authorization: `Bearer ${config.token}` } : {})
    },
    body: JSON.stringify(body)
  });

  if (!response.ok) throw new Error(`callback returned HTTP ${response.status}`);
}

function validateJob(job) {
  if (!job || typeof job !== "object") return "body must be a JSON object";
  if (!nonEmptyString(job.job_id)) return "job_id is required";
  if (!Number.isInteger(job.recording_id)) return "recording_id must be an integer";
  if (!nonEmptyString(job.media_type)) return "media_type is required";
  if (!nonEmptyString(job.storage_key)) return "storage_key is required";
  if (job.media?.method !== "GET") return "media.method must be GET";
  if (!nonEmptyString(job.media?.url)) return "media.url is required";
  if (job.callback?.method !== "POST") return "callback.method must be POST";
  if (!nonEmptyString(job.callback?.url)) return "callback.url is required";
  return null;
}

function isAuthorized(req, token) {
  if (!token) return true;
  return req.headers.authorization === `Bearer ${token}`;
}

async function readJson(req) {
  let body = "";
  for await (const chunk of req) body += chunk;
  return JSON.parse(body || "{}");
}

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function nonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const host = process.env.AI_ADAPTER_HOST ?? "0.0.0.0";
  const port = Number(process.env.AI_ADAPTER_PORT ?? 7005);

  createAiAdapterServer().listen(port, host, () => {
    console.log(`Matome AI adapter listening on http://${host}:${port}`);
    console.log(`  → audio API: ${process.env.AUDIO_API_ENDPOINT ?? "http://localhost:8000/api/v1/transcribe"}`);
  });
}
