import { createHash } from "node:crypto";
import { createReadStream, readFileSync, writeFileSync } from "node:fs";
import { request as httpRequest } from "node:http";
import { createSecureServer } from "node:http2";
import { pipeline } from "node:stream";

const host = "127.0.0.1";
const port = Number(process.env.WEB_UPLOAD_TEST_PORT ?? "17777");
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "PUT, OPTIONS",
  "access-control-allow-headers": "content-type, x-amz-checksum-sha256, x-amz-meta-sha256, x-matome-proxy-content-length, x-test-checksum",
  "access-control-expose-headers": "etag",
  "access-control-allow-private-network": "true",
};

const server = createSecureServer({
  allowHTTP1: true,
  cert: readFileSync(process.env.WEB_UPLOAD_TEST_CERT),
  key: readFileSync(process.env.WEB_UPLOAD_TEST_KEY),
}, (request, response) => {
  console.log(`${request.method} ${new URL(request.url, "https://localhost").pathname}`);
  for (const [name, value] of Object.entries(cors)) response.setHeader(name, value);
  if (request.method === "OPTIONS") {
    response.writeHead(204).end();
    return;
  }
  if (request.url === "/fixture" && request.method === "GET") {
    try {
      response.setHeader("content-type", "application/json");
      createReadStream(process.env.WEB_UPLOAD_LIVE_FIXTURE).pipe(response);
    } catch (_) {
      response.writeHead(404).end();
    }
    return;
  }

  if (request.url === "/result" && request.method === "POST") {
    const chunks = [];
    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => {
      writeFileSync(process.env.WEB_UPLOAD_LIVE_RESULT, Buffer.concat(chunks));
      response.writeHead(204).end();
    });
    return;
  }

  if (request.url === "/upload" && request.method === "PUT") {
    const digest = createHash("sha256");
    request.on("data", (chunk) => digest.update(chunk));
    request.on("end", () => {
      const actual = digest.digest("hex");
      const expected = request.headers["x-test-checksum"];
      response.setHeader("etag", `"${actual}"`);
      response.writeHead(actual === expected ? 200 : 422).end();
    });
    return;
  }

  const upstreamHeaders = Object.fromEntries(
    Object.entries(request.headers).filter(([name]) =>
      !name.startsWith(":") && name !== "x-matome-proxy-content-length"
    ),
  );
  const proxyLength = request.headers["x-matome-proxy-content-length"];
  if (proxyLength) upstreamHeaders["content-length"] = proxyLength;
  delete upstreamHeaders["transfer-encoding"];
  delete upstreamHeaders.te;
  upstreamHeaders.host = request.headers[":authority"];

  const upstream = httpRequest({
    hostname: "127.0.0.1",
    port: Number(process.env.WEB_UPLOAD_MINIO_PORT ?? "7021"),
    method: request.method,
    path: request.url,
    headers: upstreamHeaders,
  }, (upstreamResponse) => {
    const responseHeaders = Object.fromEntries(
      Object.entries(upstreamResponse.headers).filter(([name]) =>
        name !== "connection" && name !== "transfer-encoding"
      ),
    );
    response.writeHead(upstreamResponse.statusCode ?? 502, responseHeaders);
    if ((upstreamResponse.statusCode ?? 500) >= 400) {
      const chunks = [];
      upstreamResponse.on("data", (chunk) => chunks.push(chunk));
      upstreamResponse.on("end", () => {
        console.log(`upstream error=${Buffer.concat(chunks).toString()}`);
        response.end(Buffer.concat(chunks));
      });
    } else {
      pipeline(upstreamResponse, response, () => {});
    }
  });
  upstream.on("error", () => response.writeHead(502).end());
  pipeline(request, upstream, () => {});
});

server.listen(port, host);
setTimeout(() => server.close(), 180000).unref();
