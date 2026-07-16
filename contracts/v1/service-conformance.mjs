import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { createServer as createHttpServer } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";

const fixtures = JSON.parse(
  await readFile(new URL("./fixtures/canonical.json", import.meta.url), "utf8")
);

const dispatchToken = "test-dispatch-token";
const callbackToken = "test-callback-token";

export function registerV1ServiceConformance({
  test,
  createServer,
  capabilities,
  makeMediaBytes,
  startProcessor = async () => ({ options: {}, close: async () => {} }),
  productionOptions = {},
  assertOutputs = () => {}
}) {
  const kinds = Object.entries(capabilities.inputs)
    .filter(([, input]) => input.enabled)
    .map(([kind]) => kind);

  test("v1 conformance: advertises authenticated capabilities", async () => {
    await withService({ createServer }, async ({ baseUrl }) => {
      const unauthorized = await fetch(`${baseUrl}/v1/capabilities`);
      assert.equal(unauthorized.status, 401);

      const response = await fetch(`${baseUrl}/v1/capabilities`, {
        headers: { authorization: `Bearer ${dispatchToken}` }
      });

      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), capabilities);
    });
  });

  test("v1 conformance: accepts canonical jobs for every advertised input kind", async () => {
    const media = await startMediaServer(kinds, makeMediaBytes);
    const processor = await startProcessor();
    const callbacks = [];
    const callbackServer = createHttpServer(async (req, res) => {
      callbacks.push({
        authorization: req.headers.authorization,
        body: await readJson(req)
      });
      res.writeHead(204);
      res.end();
    });
    const callbackBaseUrl = await listen(callbackServer);

    try {
      await withService(
        { createServer, options: processor.options },
        async ({ baseUrl }) => {
          for (const kind of kinds) {
            const job = canonicalJob(kind, {
              callbackBaseUrl,
              mediaBaseUrl: media.baseUrl,
              mediaBytes: media.bytes[kind],
              capability: capabilities.inputs[kind]
            });

            const response = await postJob(baseUrl, job);
            assert.equal(response.status, 202);
            assert.deepEqual(await response.json(), {
              contract_version: "1",
              job_id: job.job_id,
              run_id: job.run_id,
              accepted: true
            });
          }

          await waitFor(() => callbacks.length === kinds.length);

          for (const kind of kinds) {
            const job = fixtures.ai.jobs[kind];
            const callback = callbacks.find((candidate) => candidate.body.job_id === job.job_id);
            assert.equal(callback.authorization, `Bearer ${callbackToken}`);
            assert.equal(callback.body.contract_version, "1");
            assert.equal(callback.body.job_id, job.job_id);
            assert.equal(callback.body.run_id, job.run_id);
            assert.equal(callback.body.item_id, job.item_id);
            assert.equal(callback.body.input_revision, job.input_revision);
            assert.equal(callback.body.status, "done");
            assert.deepEqual(
              callback.body.outputs.map((output) => output.type),
              capabilities.inputs[kind].outputs
            );
            assertOutputs(kind, callback.body.outputs);
          }
        }
      );
    } finally {
      await close(callbackServer);
      await processor.close();
      await media.close();
    }
  });

  test("v1 conformance: enforces capability, declared bounds, and media integrity", async () => {
    const kind = kinds.find((candidate) => candidate !== "text") ?? kinds[0];
    const media = await startMediaServer([kind], makeMediaBytes);
    const processor = await startProcessor();
    const callbacks = [];
    const callbackServer = createHttpServer(async (req, res) => {
      callbacks.push(await readJson(req));
      res.writeHead(204);
      res.end();
    });
    const callbackBaseUrl = await listen(callbackServer);

    try {
      await withService(
        { createServer, options: processor.options },
        async ({ baseUrl }) => {
          const job = canonicalJob(kind, {
            callbackBaseUrl,
            mediaBaseUrl: media.baseUrl,
            mediaBytes: media.bytes[kind],
            capability: capabilities.inputs[kind]
          });

          const mismatch = structuredClone(job);
          mismatch.input.kind = "video";
          const mismatchResponse = await postJob(baseUrl, mismatch);
          assert.equal(mismatchResponse.status, 422);
          assert.equal((await mismatchResponse.json()).error.code, "capability_mismatch");

          const tooLarge = structuredClone(job);
          if (kind === "text") {
            tooLarge.input.body = "x".repeat(capabilities.inputs[kind].max_characters + 1);
          } else {
            tooLarge.input.media.byte_size = capabilities.inputs[kind].max_bytes + 1;
          }
          tooLarge.job_id += "_large";
          tooLarge.run_id += "_large";
          const tooLargeResponse = await postJob(baseUrl, tooLarge);
          assert.equal(tooLargeResponse.status, 413);
          assert.equal((await tooLargeResponse.json()).error.code, "input_too_large");

          if (kind !== "text") {
            const corrupt = structuredClone(job);
            corrupt.job_id += "_corrupt";
            corrupt.run_id += "_corrupt";
            corrupt.input.media.checksum_sha256 = "f".repeat(64);

            const accepted = await postJob(baseUrl, corrupt);
            assert.equal(accepted.status, 202);
            await waitFor(() => callbacks.length === 1);
            assert.equal(callbacks[0].status, "failed");
            assert.deepEqual(callbacks[0].error, {
              code: "input_integrity_mismatch",
              message: "Input bytes did not match the declared integrity metadata.",
              retryable: false
            });
          }

          if (capabilities.inputs.text?.enabled) {
            const text = canonicalJob("text", {
              callbackBaseUrl,
              mediaBaseUrl: media.baseUrl,
              mediaBytes: Buffer.alloc(0),
              capability: capabilities.inputs.text
            });
            text.input.body = "x".repeat(capabilities.inputs.text.max_characters + 1);
            const textResponse = await postJob(baseUrl, text);
            assert.equal(textResponse.status, 413);
            assert.equal((await textResponse.json()).error.code, "input_too_large");
          }
        }
      );
    } finally {
      await close(callbackServer);
      await processor.close();
      await media.close();
    }
  });

  test("v1 conformance: accepted work survives restart and replay is deterministic", async () => {
    const kind = kinds[0];
    const dataDir = await mkdtemp(join(tmpdir(), "matome-ai-conformance-"));
    const media = await startMediaServer([kind], makeMediaBytes);
    const processor = await startProcessor();
    const callbacks = [];
    const callbackServer = createHttpServer(async (req, res) => {
      callbacks.push(await readJson(req));
      res.writeHead(204);
      res.end();
    });
    const callbackBaseUrl = await listen(callbackServer);
    const job = canonicalJob(kind, {
      callbackBaseUrl,
      mediaBaseUrl: media.baseUrl,
      mediaBytes: media.bytes[kind],
      capability: capabilities.inputs[kind]
    });

    try {
      const first = createServer({
        dispatchToken,
        dataDir,
        callbackDelayMs: 60_000,
        ...processor.options
      });
      const firstBaseUrl = await listen(first);
      const accepted = await postJob(firstBaseUrl, job);
      assert.equal(accepted.status, 202);
      await close(first);

      const restarted = createServer({
        dispatchToken,
        dataDir,
        callbackDelayMs: 0,
        callbackRetryMs: 10,
        ...processor.options
      });
      const restartedBaseUrl = await listen(restarted);

      try {
        await waitFor(() => callbacks.length === 1);

        const renewed = structuredClone(job);
        if (renewed.input.kind !== "text") {
          renewed.input.media.url = `${media.baseUrl}/${kind}?signature=renewed`;
          renewed.input.media.expires_at = "2026-07-15T12:45:00Z";
        }

        const replay = await postJob(restartedBaseUrl, renewed);
        assert.equal(replay.status, 202);
        assert.deepEqual(await replay.json(), await accepted.json());
        await new Promise((resolve) => setTimeout(resolve, 30));
        assert.equal(callbacks.length, 1);

        const conflict = structuredClone(job);
        conflict.metadata = { locale: "ja" };
        const conflictResponse = await postJob(restartedBaseUrl, conflict);
        assert.equal(conflictResponse.status, 409);
        assert.equal((await conflictResponse.json()).error.code, "idempotency_conflict");
      } finally {
        await close(restarted);
      }
    } finally {
      await close(callbackServer);
      await processor.close();
      await media.close();
      await rm(dataDir, { recursive: true, force: true });
    }
  });

  test("v1 conformance: concurrent idempotency conflicts accept exactly one payload", async () => {
    const kind = kinds[0];
    const media = await startMediaServer([kind], makeMediaBytes);
    const callbackServer = createHttpServer((_req, res) => {
      res.writeHead(204);
      res.end();
    });
    const callbackBaseUrl = await listen(callbackServer);

    try {
      await withService(
        { createServer, options: { callbackDelayMs: 60_000 } },
        async ({ baseUrl }) => {
          const first = canonicalJob(kind, {
            callbackBaseUrl,
            mediaBaseUrl: media.baseUrl,
            mediaBytes: media.bytes[kind],
            capability: capabilities.inputs[kind]
          });
          const conflicting = structuredClone(first);
          conflicting.metadata = { locale: "ja" };

          const responses = await Promise.all([
            postJob(baseUrl, first),
            postJob(baseUrl, conflicting)
          ]);
          assert.deepEqual(
            responses.map((response) => response.status).sort(),
            [202, 409]
          );
        }
      );
    } finally {
      await close(callbackServer);
      await media.close();
    }
  });

  test("v1 conformance: callback retries preserve the exact terminal payload", async () => {
    const kind = kinds[0];
    const media = await startMediaServer([kind], makeMediaBytes);
    const processor = await startProcessor();
    const callbackBodies = [];
    const callbackServer = createHttpServer(async (req, res) => {
      callbackBodies.push(await readBody(req));
      res.writeHead(callbackBodies.length === 1 ? 503 : 204);
      res.end();
    });
    const callbackBaseUrl = await listen(callbackServer);

    try {
      await withService(
        { createServer, options: { callbackRetryMs: 10, ...processor.options } },
        async ({ baseUrl }) => {
          const job = canonicalJob(kind, {
            callbackBaseUrl,
            mediaBaseUrl: media.baseUrl,
            mediaBytes: media.bytes[kind],
            capability: capabilities.inputs[kind]
          });

          const response = await postJob(baseUrl, job);
          assert.equal(response.status, 202);
          await waitFor(() => callbackBodies.length === 2);
          assert.equal(callbackBodies[0], callbackBodies[1]);
        }
      );
    } finally {
      await close(callbackServer);
      await processor.close();
      await media.close();
    }
  });

  test("v1 conformance: logs exclude content, credentials, and presigned URLs", async () => {
    const kind = kinds[0];
    const mediaBytes = await makeMediaBytes(kind);
    const processor = await startProcessor();
    const entries = [];
    const logger = {
      info(event, fields) {
        entries.push({ event, fields });
      },
      error(event, fields) {
        entries.push({ event, fields });
      }
    };
    let failureCallback;
    const callbackServer = createHttpServer(async (req, res) => {
      failureCallback = await readJson(req);
      res.writeHead(503);
      res.end();
    });
    const callbackBaseUrl = await listen(callbackServer);

    try {
      await withService(
        { createServer, options: { logger, callbackRetryMs: 10, ...processor.options } },
        async ({ baseUrl }) => {
          const job = canonicalJob(kind, {
            callbackBaseUrl: `${callbackBaseUrl}/presigned-callback-secret`,
            mediaBaseUrl: "http://127.0.0.1:1/presigned-media-secret",
            mediaBytes,
            capability: capabilities.inputs[kind]
          });
          job.callback.headers.authorization = "Bearer callback-secret-value";
          if (kind === "text") job.input.body = "private text content";

          const response = await postJob(baseUrl, job);
          assert.equal(response.status, 202);
          await waitFor(() => entries.some((entry) => entry.event === "job.callback_retry"));

          assert.deepEqual(failureCallback.error, {
            code: "input_fetch_failed",
            message: "Input could not be fetched.",
            retryable: true
          });

          const serialized = JSON.stringify(entries);
          assert.doesNotMatch(serialized, /private text content/);
          assert.doesNotMatch(serialized, /callback-secret-value/);
          assert.doesNotMatch(serialized, /presigned-(callback|media)-secret/);
          assert.doesNotMatch(serialized, /test-dispatch-token/);
        }
      );
    } finally {
      await close(callbackServer);
      await processor.close();
    }
  });

  test("v1 conformance: production rejects default credentials and insecure job URLs", async () => {
    const dataDir = await mkdtemp(join(tmpdir(), "matome-ai-production-"));

    try {
      assert.throws(
        () =>
          createServer({
            production: true,
            dataDir,
            dispatchToken: "dev-ai-dispatch-token",
            ...productionOptions
          }),
        /production dispatch token/
      );

      assert.throws(
        () =>
          createServer({
            production: true,
            environment: { NODE_ENV: "production" },
            dispatchToken: "p".repeat(32),
            ...productionOptions
          }),
        /AI_JOB_DATA_DIR/
      );

      const server = createServer({
        production: true,
        dataDir,
        dispatchToken: "p".repeat(32),
        ...productionOptions
      });
      const baseUrl = await listen(server);

      try {
        const kind = kinds[0];
        const bytes = await makeMediaBytes(kind);
        const job = canonicalJob(kind, {
          callbackBaseUrl: "http://core.invalid",
          mediaBaseUrl: "http://storage.invalid",
          mediaBytes: bytes,
          capability: capabilities.inputs[kind]
        });
        const response = await postJob(baseUrl, job, "p".repeat(32));
        assert.equal(response.status, 400);
        assert.equal((await response.json()).error.code, "insecure_endpoint");
      } finally {
        await close(server);
      }
    } finally {
      await rm(dataDir, { recursive: true, force: true });
    }
  });

  test("v1 conformance: unavailable durable storage fails closed before acceptance", async () => {
    const parent = await mkdtemp(join(tmpdir(), "matome-ai-broken-store-"));
    const dataDir = join(parent, "not-a-directory");
    await writeFile(dataDir, "occupied");
    const server = createServer({
      dispatchToken,
      dataDir,
      logger: { info() {}, error() {} }
    });
    const baseUrl = await listen(server);

    try {
      const response = await fetch(`${baseUrl}/v1/capabilities`, {
        headers: { authorization: `Bearer ${dispatchToken}` }
      });
      assert.equal(response.status, 503);
      assert.deepEqual((await response.json()).error, {
        code: "durable_store_unavailable",
        message: "Durable accepted-job storage is unavailable.",
        retryable: true
      });
    } finally {
      await close(server);
      await rm(parent, { recursive: true, force: true });
    }
  });
}

function canonicalJob(kind, { callbackBaseUrl, mediaBaseUrl, mediaBytes, capability }) {
  const job = structuredClone(fixtures.ai.jobs[kind]);
  job.callback.url = `${callbackBaseUrl}/internal/v1/jobs/${job.job_id}/result`;
  job.callback.headers.authorization = `Bearer ${callbackToken}`;
  job.requested_outputs = capability.outputs;

  if (kind !== "text") {
    job.input.media.url = `${mediaBaseUrl}/${kind}?signature=private`;
    job.input.media.byte_size = mediaBytes.length;
    job.input.media.checksum_sha256 = createHash("sha256").update(mediaBytes).digest("hex");
  }

  return job;
}

async function withService({ createServer, options = {} }, callback) {
  const dataDir = await mkdtemp(join(tmpdir(), "matome-ai-conformance-"));
  const server = createServer({
    dispatchToken,
    dataDir,
    callbackDelayMs: 0,
    callbackRetryMs: 10,
    ...options
  });
  const baseUrl = await listen(server);

  try {
    await callback({ baseUrl, server, dataDir });
  } finally {
    await close(server);
    await rm(dataDir, { recursive: true, force: true });
  }
}

async function startMediaServer(kinds, makeMediaBytes) {
  const bytes = Object.fromEntries(
    await Promise.all(kinds.map(async (kind) => [kind, await makeMediaBytes(kind)]))
  );
  const server = createHttpServer((req, res) => {
    const kind = new URL(req.url, "http://media.invalid").pathname.slice(1);
    const body = bytes[kind];
    if (!body) {
      res.writeHead(404);
      res.end();
      return;
    }
    res.writeHead(200, { "content-type": "application/octet-stream" });
    res.end(body);
  });

  return { bytes, baseUrl: await listen(server), close: () => close(server) };
}

function postJob(baseUrl, job, token = dispatchToken) {
  return fetch(`${baseUrl}/v1/jobs`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json"
    },
    body: JSON.stringify(job)
  });
}

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      server.removeListener("error", reject);
      const address = server.address();
      resolve(`http://127.0.0.1:${address.port}`);
    });
  });
}

function close(server) {
  if (!server.listening) return Promise.resolve();
  return new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

async function readJson(req) {
  return JSON.parse((await readBody(req)) || "{}");
}

async function readBody(req) {
  let body = "";
  for await (const chunk of req) body += chunk;
  return body;
}

async function waitFor(assertion, timeoutMs = 5_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (assertion()) return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error("timed out waiting for assertion");
}
