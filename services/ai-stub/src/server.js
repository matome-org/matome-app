import { createServer } from "node:http";

const SUPPORTED_MEDIA_TYPES = new Set(["audio", "meeting", "image", "document"]);

export function createAiStubServer(options = {}) {
  const config = {
    token: options.token ?? process.env.AI_ENGINE_TOKEN ?? "",
    callbackDelayMs: numberFromEnv("AI_STUB_CALLBACK_DELAY_MS", 25),
    probeMedia: booleanFromEnv("AI_STUB_PROBE_MEDIA"),
    forceFailure: booleanFromEnv("AI_STUB_FORCE_FAILURE"),
    fetchImpl: options.fetchImpl ?? globalThis.fetch,
    ...options
  };

  return createServer(async (req, res) => {
    try {
      if (req.method === "GET" && req.url === "/health") {
        sendJson(res, 200, { ok: true, service: "matome-ai-stub" });
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

      setTimeout(() => {
        postCallback(job, config).catch((error) => {
          console.error("AI stub callback failed", error);
        });
      }, config.callbackDelayMs);

      sendJson(res, 202, { job_id: job.job_id, accepted: true });
    } catch (error) {
      sendJson(res, 400, { error: error.message });
    }
  });
}

async function postCallback(job, config) {
  const mediaProbe = config.probeMedia ? await probeMedia(job.media.url, config.fetchImpl) : { ok: true };
  const failed = config.forceFailure || !SUPPORTED_MEDIA_TYPES.has(job.media_type) || !mediaProbe.ok;
  const body = failed ? failurePayload(job, mediaProbe) : successPayload(job);

  const response = await config.fetchImpl(job.callback.url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(config.token ? { authorization: `Bearer ${config.token}` } : {})
    },
    body: JSON.stringify(body)
  });

  if (!response.ok) {
    throw new Error(`callback returned HTTP ${response.status}`);
  }
}

function successPayload(job) {
  return {
    job_id: job.job_id,
    recording_id: job.recording_id,
    status: "done",
    title: `AI stub result ${job.recording_id}`,
    transcript: `Canned local transcript for recording ${job.recording_id}.`,
    summary: summaryFor(job),
    duration: 42,
    badge: "Inbox"
  };
}

function summaryFor(job) {
  if (job.media_type === "document") {
    // Stub only: the document is NOT parsed. Keep this clearly a placeholder.
    return `[PLACEHOLDER] AI stub summary for document recording ${job.recording_id}. No document content was processed.`;
  }

  return `Canned local summary for ${job.media_type} recording ${job.recording_id}.`;
}

function failurePayload(job, mediaProbe) {
  const unsupported = !SUPPORTED_MEDIA_TYPES.has(job.media_type);

  return {
    job_id: job.job_id,
    recording_id: job.recording_id,
    status: "failed",
    error: {
      code: unsupported ? "unsupported_media_type" : "media_fetch_failed",
      message: unsupported
        ? `Unsupported media_type: ${job.media_type}`
        : `Unable to fetch presigned media URL: ${mediaProbe.status ?? "request_failed"}`
    }
  };
}

async function probeMedia(url, fetchImpl) {
  try {
    const response = await fetchImpl(url, { method: "GET" });
    return { ok: response.ok, status: response.status };
  } catch (error) {
    return { ok: false, status: error.message };
  }
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

  for await (const chunk of req) {
    body += chunk;
  }

  return JSON.parse(body || "{}");
}

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function nonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

function booleanFromEnv(name) {
  return ["1", "true", "yes"].includes((process.env[name] ?? "").toLowerCase());
}

function numberFromEnv(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) ? value : fallback;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const host = process.env.AI_STUB_HOST ?? "127.0.0.1";
  const port = Number(process.env.AI_STUB_PORT ?? 7002);

  createAiStubServer().listen(port, host, () => {
    console.log(`Matome AI stub listening on http://${host}:${port}`);
  });
}
