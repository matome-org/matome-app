import assert from "node:assert/strict";
import { createServer } from "node:http";
import { test } from "node:test";
import { createAiStubServer } from "./server.js";

test("accepts a valid job and posts a canned success callback", async () => {
  const callbacks = [];
  const callbackServer = createServer(async (req, res) => {
    callbacks.push({
      method: req.method,
      url: req.url,
      authorization: req.headers.authorization,
      body: await readJson(req)
    });

    res.writeHead(204);
    res.end();
  });

  const callbackBaseUrl = await listen(callbackServer);
  const stubServer = createAiStubServer({ token: "test-token", callbackDelayMs: 0 });
  const stubBaseUrl = await listen(stubServer);

  try {
    const response = await fetch(`${stubBaseUrl}/v1/jobs`, {
      method: "POST",
      headers: {
        authorization: "Bearer test-token",
        "content-type": "application/json"
      },
      body: JSON.stringify(job(`${callbackBaseUrl}/internal/jobs/job-1/result`))
    });

    assert.equal(response.status, 202);
    assert.deepEqual(await response.json(), { job_id: "job-1", accepted: true });

    await waitFor(() => callbacks.length === 1);
    assert.equal(callbacks[0].method, "POST");
    assert.equal(callbacks[0].url, "/internal/jobs/job-1/result");
    assert.equal(callbacks[0].authorization, "Bearer test-token");
    assert.equal(callbacks[0].body.status, "done");
    assert.equal(callbacks[0].body.recording_id, 123);
    assert.match(callbacks[0].body.transcript, /Canned local transcript/);
  } finally {
    await close(stubServer);
    await close(callbackServer);
  }
});

test("rejects requests without the configured bearer token", async () => {
  const stubServer = createAiStubServer({ token: "test-token" });
  const stubBaseUrl = await listen(stubServer);

  try {
    const response = await fetch(`${stubBaseUrl}/v1/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(job("http://127.0.0.1/callback"))
    });

    assert.equal(response.status, 401);
  } finally {
    await close(stubServer);
  }
});

test("returns a failed callback for unsupported media types", async () => {
  const callbacks = [];
  const callbackServer = createServer(async (req, res) => {
    callbacks.push(await readJson(req));
    res.writeHead(204);
    res.end();
  });

  const callbackBaseUrl = await listen(callbackServer);
  const stubServer = createAiStubServer({ callbackDelayMs: 0 });
  const stubBaseUrl = await listen(stubServer);

  try {
    const response = await fetch(`${stubBaseUrl}/v1/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        ...job(`${callbackBaseUrl}/internal/jobs/job-1/result`),
        media_type: "video"
      })
    });

    assert.equal(response.status, 202);
    await waitFor(() => callbacks.length === 1);
    assert.equal(callbacks[0].status, "failed");
    assert.equal(callbacks[0].error.code, "unsupported_media_type");
  } finally {
    await close(stubServer);
    await close(callbackServer);
  }
});

test("processes document media types with a clearly placeholder summary", async () => {
  const callbacks = [];
  const callbackServer = createServer(async (req, res) => {
    callbacks.push(await readJson(req));
    res.writeHead(204);
    res.end();
  });

  const callbackBaseUrl = await listen(callbackServer);
  const stubServer = createAiStubServer({ callbackDelayMs: 0 });
  const stubBaseUrl = await listen(stubServer);

  try {
    const response = await fetch(`${stubBaseUrl}/v1/jobs`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        ...job(`${callbackBaseUrl}/internal/jobs/job-1/result`),
        media_type: "document"
      })
    });

    assert.equal(response.status, 202);
    await waitFor(() => callbacks.length === 1);
    assert.equal(callbacks[0].status, "done");
    assert.notEqual(callbacks[0].error?.code, "unsupported_media_type");
    // Summary must be clearly a placeholder and never imply the document was read.
    assert.match(callbacks[0].summary, /placeholder|stub/i);
    assert.doesNotMatch(callbacks[0].summary, /read|analy[sz]ed|extracted/i);
  } finally {
    await close(stubServer);
    await close(callbackServer);
  }
});

function job(callbackUrl) {
  return {
    job_id: "job-1",
    recording_id: 123,
    media_type: "audio",
    storage_key: "owners/42/recordings/123/media",
    media: {
      method: "GET",
      url: "http://127.0.0.1/media"
    },
    callback: {
      method: "POST",
      url: callbackUrl
    },
    metadata: {
      owner_id: 42,
      attempt: 1
    }
  };
}

async function readJson(req) {
  let body = "";

  for await (const chunk of req) {
    body += chunk;
  }

  return JSON.parse(body || "{}");
}

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolve(`http://${address.address}:${address.port}`);
    });
  });
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

async function waitFor(assertion, timeoutMs = 1000) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    if (assertion()) return;
    await new Promise((resolve) => setTimeout(resolve, 5));
  }

  throw new Error("timed out waiting for assertion");
}
