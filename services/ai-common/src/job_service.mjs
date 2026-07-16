import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, rename, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";

const MAX_JOB_BYTES = 1_048_576;
const DEFAULT_PRODUCTION_TOKENS = new Set([
  "dev-ai-dispatch-token",
  "test-dispatch-token"
]);

export class JobError extends Error {
  constructor(code, message, retryable) {
    super(message);
    this.code = code;
    this.retryable = retryable;
  }
}

export function createV1JobServer({ service, capabilities, execute, options = {} }) {
  const environment = options.environment ?? process.env;
  const production = options.production ?? environment.NODE_ENV === "production";
  const dispatchToken =
    options.dispatchToken ?? environment.AI_ENGINE_DISPATCH_TOKEN ?? "";
  const configuredDataDir = options.dataDir ?? environment.AI_JOB_DATA_DIR;
  const dataDir = configuredDataDir ?? join(tmpdir(), `${service}-jobs`);

  validateRuntimeConfig({ production, dispatchToken, configuredDataDir });

  const queue = new DurableJobQueue({
    dataDir,
    execute: (job) => execute(withCapability(job, capabilities)),
    fetchImpl: options.fetchImpl ?? globalThis.fetch,
    logger: options.logger ?? console,
    callbackDelayMs: finiteNumber(options.callbackDelayMs, 25),
    callbackRetryMs: finiteNumber(options.callbackRetryMs, 1_000),
    callbackRetryMaxMs: finiteNumber(options.callbackRetryMaxMs, 30_000),
    callbackTimeoutMs: finiteNumber(options.callbackTimeoutMs, 10_000)
  });

  const server = createServer(async (req, res) => {
    try {
      if (req.method === "GET" && req.url === "/health") {
        await queue.ready;
        sendJson(res, 200, { ok: true, service });
        return;
      }

      if (req.url !== "/v1/capabilities" && req.url !== "/v1/jobs") {
        sendError(res, new HttpError(404, "not_found", "Route not found."));
        return;
      }

      if (!isAuthorized(req, dispatchToken)) {
        sendError(res, new HttpError(401, "unauthorized", "Authorization failed."));
        return;
      }

      await queue.ready;

      if (req.method === "GET" && req.url === "/v1/capabilities") {
        sendJson(res, 200, capabilities);
        return;
      }

      if (req.method !== "POST" || req.url !== "/v1/jobs") {
        sendError(res, new HttpError(404, "not_found", "Route not found."));
        return;
      }

      const job = await readJson(req);
      validateJob(job, capabilities, { production, dispatchToken });
      const result = await queue.accept(job);

      if (result === "conflict") {
        sendError(
          res,
          new HttpError(
            409,
            "idempotency_conflict",
            "The idempotency identity was already accepted with different input."
          )
        );
        return;
      }

      sendJson(res, 202, acceptedResponse(job));
    } catch (error) {
      if (error instanceof HttpError) {
        sendError(res, error);
      } else {
        safeLog(options.logger ?? console, "error", "job.request_failed", {
          code: "durable_store_unavailable"
        });
        sendError(
          res,
          new HttpError(
            503,
            "durable_store_unavailable",
            "Durable accepted-job storage is unavailable.",
            true
          )
        );
      }
    }
  });

  server.on("listening", () => queue.start());
  server.on("close", () => queue.stop());
  return server;
}

export async function fetchVerifiedMedia(job, fetchImpl = globalThis.fetch) {
  const capabilityLimit = job.capability.max_bytes;
  let response;

  try {
    response = await fetchImpl(job.input.media.url, {
      method: "GET",
      signal: AbortSignal.timeout(30_000)
    });
  } catch (_error) {
    throw new JobError("input_fetch_failed", "Input could not be fetched.", true);
  }

  if (!response.ok) {
    const retryable = response.status === 408 || response.status === 429 || response.status >= 500;
    throw new JobError("input_fetch_failed", "Input could not be fetched.", retryable);
  }

  const chunks = [];
  const hash = createHash("sha256");
  let byteSize = 0;

  try {
    for await (const chunk of response.body) {
      const bytes = Buffer.from(chunk);
      byteSize += bytes.length;
      if (byteSize > capabilityLimit) {
        throw new JobError("input_too_large", "Input exceeded the advertised byte limit.", false);
      }
      chunks.push(bytes);
      hash.update(bytes);
    }
  } catch (error) {
    if (error instanceof JobError) throw error;
    throw new JobError("input_fetch_failed", "Input could not be fetched.", true);
  }

  if (
    byteSize !== job.input.media.byte_size ||
    hash.digest("hex") !== job.input.media.checksum_sha256
  ) {
    throw new JobError(
      "input_integrity_mismatch",
      "Input bytes did not match the declared integrity metadata.",
      false
    );
  }

  return Buffer.concat(chunks, byteSize);
}

function validateRuntimeConfig({ production, dispatchToken, configuredDataDir }) {
  if (!production) return;

  if (
    typeof dispatchToken !== "string" ||
    dispatchToken.length < 32 ||
    DEFAULT_PRODUCTION_TOKENS.has(dispatchToken)
  ) {
    throw new Error("A non-default production dispatch token of at least 32 bytes is required.");
  }

  if (!configuredDataDir) {
    throw new Error("AI_JOB_DATA_DIR is required in production for durable accepted jobs.");
  }
}

function validateJob(job, capabilities, { production, dispatchToken }) {
  requireExactKeys(
    job,
    [
      "callback",
      "contract_version",
      "input",
      "input_revision",
      "item_id",
      "job_id",
      "metadata",
      "requested_outputs",
      "run_id"
    ],
    "invalid_job"
  );

  if (job.contract_version !== "1") invalid("unsupported_contract");
  if (!boundedString(job.job_id, 255) || !boundedString(job.run_id, 255)) invalid();
  if (!Number.isInteger(job.item_id) || job.item_id <= 0) invalid();
  if (!Number.isInteger(job.input_revision) || job.input_revision <= 0) invalid();

  if (!job.input || typeof job.input !== "object" || Array.isArray(job.input)) invalid();
  const capability = capabilities.inputs[job.input.kind];
  if (!capability?.enabled) {
    throw new HttpError(422, "capability_mismatch", "The input kind is not advertised.");
  }

  if (
    !Array.isArray(job.requested_outputs) ||
    job.requested_outputs.length === 0 ||
    new Set(job.requested_outputs).size !== job.requested_outputs.length ||
    !job.requested_outputs.every((output) => capability.outputs.includes(output))
  ) {
    throw new HttpError(422, "capability_mismatch", "Requested outputs are not advertised.");
  }

  if (job.input.kind === "text") {
    requireExactKeys(job.input, ["body", "kind"]);
    if (typeof job.input.body !== "string") invalid();
    if ([...job.input.body].length > capability.max_characters) {
      throw new HttpError(413, "input_too_large", "Input exceeded the advertised character limit.");
    }
  } else {
    requireExactKeys(job.input, ["kind", "media"]);
    requireExactKeys(job.input.media, [
      "byte_size",
      "checksum_sha256",
      "content_type",
      "expires_at",
      "method",
      "url"
    ]);
    const media = job.input.media;
    if (media.method !== "GET" || !validUrl(media.url)) invalid();
    if (!boundedString(media.expires_at, 64)) invalid();
    if (!capability.content_types.includes(media.content_type)) {
      throw new HttpError(422, "capability_mismatch", "The input content type is not advertised.");
    }
    if (!Number.isInteger(media.byte_size) || media.byte_size < 0) invalid();
    if (media.byte_size > capability.max_bytes) {
      throw new HttpError(413, "input_too_large", "Input exceeded the advertised byte limit.");
    }
    if (!/^[0-9a-f]{64}$/.test(media.checksum_sha256)) invalid();
    if (production && !isHttps(media.url)) insecureEndpoint();
  }

  requireExactKeys(job.callback, ["deadline_at", "headers", "method", "url"]);
  requireExactKeys(job.callback.headers, ["authorization"]);
  const callbackAuthorization = job.callback.headers.authorization;
  if (
    job.callback.method !== "POST" ||
    !validUrl(job.callback.url) ||
    !boundedString(job.callback.deadline_at, 64) ||
    !boundedString(callbackAuthorization, 4_096) ||
    !callbackAuthorization.startsWith("Bearer ") ||
    callbackAuthorization === `Bearer ${dispatchToken}`
  ) {
    invalid();
  }
  if (production && !isHttps(job.callback.url)) insecureEndpoint();

  requireExactKeys(job.metadata, [], ["locale"]);
  if (job.metadata.locale !== undefined && !boundedString(job.metadata.locale, 35)) invalid();

  Object.defineProperty(job, "capability", {
    value: capability,
    enumerable: false
  });
}

class DurableJobQueue {
  constructor(config) {
    Object.assign(this, config);
    this.records = new Map();
    this.timers = new Map();
    this.running = new Set();
    this.pendingTerminals = new Map();
    this.active = false;
    this.acceptChain = Promise.resolve();
    this.writeChain = Promise.resolve();
    this.ready = this.load();
    // Requests still await the original rejected promise and fail closed. This
    // immediate observer only prevents a startup rejection from going unhandled
    // before the server begins listening.
    this.ready.catch(() => {});
  }

  async load() {
    await mkdir(this.dataDir, { recursive: true, mode: 0o700 });
    const files = (await readdir(this.dataDir)).filter((file) => file.endsWith(".json"));

    for (const file of files) {
      const record = JSON.parse(await readFile(join(this.dataDir, file), "utf8"));
      if (!validStoredRecord(record)) {
        throw new Error("Invalid durable AI job record.");
      }
      this.records.set(record.key, record);
    }
  }

  async start() {
    this.active = true;
    try {
      await this.ready;
      for (const record of this.records.values()) this.schedule(record.key, 0);
    } catch (_error) {
      safeLog(this.logger, "error", "job.store_unavailable", { code: "invalid_store" });
    }
  }

  stop() {
    this.active = false;
    for (const timer of this.timers.values()) clearTimeout(timer);
    this.timers.clear();
  }

  async accept(job) {
    const operation = this.acceptChain.then(() => this.acceptUnlocked(job));
    this.acceptChain = operation.catch(() => {});
    return operation;
  }

  async acceptUnlocked(job) {
    await this.ready;
    const key = idempotencyKey(job);
    const fingerprint = fingerprintJob(job);
    const existing = this.records.get(key);

    if (existing) {
      if (existing.fingerprint !== fingerprint) return "conflict";

      if (existing.state === "accepted") {
        const refreshedRecord = { ...existing, job };
        await this.serializedWrite(refreshedRecord);
        this.records.set(key, refreshedRecord);
      }
      return "replay";
    }

    const record = {
      version: 1,
      key,
      fingerprint,
      state: "accepted",
      callback_attempts: 0,
      job
    };

    await this.serializedWrite(record);
    this.records.set(key, record);
    safeLog(this.logger, "info", "job.accepted", identityFields(job));
    this.schedule(key, this.callbackDelayMs);
    return "accepted";
  }

  schedule(key, delayMs) {
    if (!this.active || this.timers.has(key) || this.running.has(key)) return;
    const timer = setTimeout(() => {
      this.timers.delete(key);
      this.run(key);
    }, delayMs);
    this.timers.set(key, timer);
  }

  async run(key) {
    if (!this.active || this.running.has(key)) return;
    let record = this.records.get(key);
    if (!record || record.state === "delivered") return;
    this.running.add(key);

    let retryDelay;
    try {
      if (record.state === "accepted") {
        const terminalPayload =
          this.pendingTerminals.get(key) ?? (await this.terminalPayload(record.job));
        this.pendingTerminals.set(key, terminalPayload);
        const terminalRecord = {
          ...record,
          state: "terminal",
          terminal_payload: terminalPayload
        };
        await this.serializedWrite(terminalRecord);
        this.records.set(key, terminalRecord);
        this.pendingTerminals.delete(key);
        record = terminalRecord;
      }

      if (this.active && record.state === "terminal") {
        retryDelay = await this.deliver(record);
      }
    } catch (_error) {
      safeLog(this.logger, "error", "job.store_write_retry", {
        ...identityFields(record.job),
        code: "durable_store_unavailable"
      });
      retryDelay = this.callbackRetryMs;
    } finally {
      this.running.delete(key);
      if (retryDelay !== undefined) this.schedule(key, retryDelay);
    }
  }

  async terminalPayload(job) {
    try {
      const outputs = await this.execute(job);
      return terminalEnvelope(job, { status: "done", outputs });
    } catch (error) {
      const failure =
        error instanceof JobError
          ? error
          : new JobError("processor_unavailable", "Processor temporarily unavailable.", true);
      return terminalEnvelope(job, {
        status: "failed",
        error: {
          code: failure.code,
          message: failure.message,
          retryable: failure.retryable
        }
      });
    }
  }

  async deliver(record) {
    const body = JSON.stringify(record.terminal_payload);
    let response;

    try {
      response = await this.fetchImpl(record.job.callback.url, {
        method: "POST",
        headers: {
          ...record.job.callback.headers,
          "content-type": "application/json"
        },
        body,
        signal: AbortSignal.timeout(this.callbackTimeoutMs)
      });
    } catch (_error) {
      response = null;
    }

    if (response?.ok) {
      const deliveredRecord = { ...record, state: "delivered" };
      await this.serializedWrite(deliveredRecord);
      this.records.set(record.key, deliveredRecord);
      safeLog(this.logger, "info", "job.callback_delivered", identityFields(record.job));
      return undefined;
    }

    const retryRecord = { ...record, callback_attempts: record.callback_attempts + 1 };
    await this.serializedWrite(retryRecord);
    this.records.set(record.key, retryRecord);
    safeLog(this.logger, "error", "job.callback_retry", {
      ...identityFields(record.job),
      code: "callback_delivery_failed"
    });
    return Math.min(
      this.callbackRetryMaxMs,
      this.callbackRetryMs * 2 ** Math.min(retryRecord.callback_attempts - 1, 10)
    );
  }

  serializedWrite(record) {
    const operation = this.writeChain.then(() => this.write(record));
    this.writeChain = operation.catch(() => {});
    return operation;
  }

  async write(record) {
    const path = join(this.dataDir, `${createHash("sha256").update(record.key).digest("hex")}.json`);
    const temporary = `${path}.${process.pid}.${Date.now()}.tmp`;
    await writeFile(temporary, JSON.stringify(record), { mode: 0o600 });
    await rename(temporary, path);
  }
}

function terminalEnvelope(job, terminal) {
  return {
    contract_version: "1",
    job_id: job.job_id,
    run_id: job.run_id,
    item_id: job.item_id,
    input_revision: job.input_revision,
    ...terminal
  };
}

function validStoredRecord(record) {
  if (
    record?.version !== 1 ||
    !record.job ||
    !["accepted", "terminal", "delivered"].includes(record.state) ||
    record.key !== idempotencyKey(record.job) ||
    record.fingerprint !== fingerprintJob(record.job) ||
    !Number.isInteger(record.callback_attempts) ||
    record.callback_attempts < 0
  ) {
    return false;
  }

  return record.state === "accepted" || Boolean(record.terminal_payload);
}

function withCapability(job, capabilities) {
  if (!Object.hasOwn(job, "capability")) {
    Object.defineProperty(job, "capability", {
      value: capabilities.inputs[job.input.kind],
      enumerable: false
    });
  }
  return job;
}

function acceptedResponse(job) {
  return {
    contract_version: "1",
    job_id: job.job_id,
    run_id: job.run_id,
    accepted: true
  };
}

function idempotencyKey(job) {
  return JSON.stringify([job.job_id, job.run_id, job.input_revision]);
}

function fingerprintJob(job) {
  const semanticJob = canonicalValue(job);
  if (semanticJob.input?.media) {
    delete semanticJob.input.media.url;
    delete semanticJob.input.media.expires_at;
  }
  return createHash("sha256").update(JSON.stringify(semanticJob)).digest("hex");
}

function canonicalValue(value) {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalValue(value[key])])
    );
  }
  return value;
}

function requireExactKeys(value, required, optional = [], code = "invalid_job") {
  if (!value || typeof value !== "object" || Array.isArray(value)) invalid(code);
  const keys = Object.keys(value).sort();
  const requiredKeys = [...required].sort();
  if (!requiredKeys.every((key) => keys.includes(key))) invalid(code);
  if (!keys.every((key) => required.includes(key) || optional.includes(key))) invalid(code);
}

function invalid(code = "invalid_job") {
  throw new HttpError(400, code, "The job envelope was invalid.");
}

function insecureEndpoint() {
  throw new HttpError(400, "insecure_endpoint", "Production job URLs must use HTTPS.");
}

function boundedString(value, maxBytes) {
  return typeof value === "string" && value.length > 0 && Buffer.byteLength(value) <= maxBytes;
}

function validUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch (_error) {
    return false;
  }
}

function isHttps(value) {
  return new URL(value).protocol === "https:";
}

function isAuthorized(req, token) {
  return token === "" || req.headers.authorization === `Bearer ${token}`;
}

async function readJson(req) {
  let body = "";
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_JOB_BYTES) {
      throw new HttpError(413, "job_too_large", "The job envelope exceeded its size limit.");
    }
    body += chunk;
  }

  try {
    return JSON.parse(body || "{}");
  } catch (_error) {
    throw new HttpError(400, "invalid_json", "The request body was not valid JSON.");
  }
}

function sendError(res, error) {
  sendJson(res, error.status, {
    error: { code: error.code, message: error.message, retryable: error.retryable }
  });
}

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function identityFields(job) {
  return {
    job_id: job.job_id,
    run_id: job.run_id,
    input_revision: job.input_revision
  };
}

function safeLog(logger, level, event, fields) {
  const method = typeof logger?.[level] === "function" ? logger[level].bind(logger) : null;
  if (method) method(event, fields);
}

function finiteNumber(value, fallback) {
  return Number.isFinite(value) && value >= 0 ? value : fallback;
}

class HttpError extends Error {
  constructor(status, code, message, retryable = false) {
    super(message);
    this.status = status;
    this.code = code;
    this.retryable = retryable;
  }
}
