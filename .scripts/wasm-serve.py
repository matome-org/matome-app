#!/usr/bin/env python3
"""Serve the WASM studio and proxy Core so the browser needs no CORS."""

from __future__ import annotations

import mimetypes
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import unquote, urlsplit
from urllib.request import Request, urlopen

ROOT = os.path.abspath(os.environ.get("MATOME_WASM_ROOT", ""))
CORE = os.environ.get("MATOME_CORE", "http://127.0.0.1:7001").rstrip("/")
PORT = int(os.environ.get("MATOME_WASM_PORT", "7002"))
STATIC_EXT = {
    ".css",
    ".data",
    ".html",
    ".ico",
    ".js",
    ".json",
    ".map",
    ".png",
    ".svg",
    ".ttf",
    ".wasm",
    ".woff",
    ".woff2",
}
CACHEABLE = {".css", ".js", ".wasm", ".svg", ".png", ".ttf", ".woff", ".woff2", ".map"}
# Hop-by-hop headers: they describe one connection and never pass through.
HOP = {"connection", "transfer-encoding"}
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("font/ttf", ".ttf")


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def is_static(self) -> bool:
        path = urlsplit(self.path).path
        if path == "/":
            return True
        ext = os.path.splitext(path)[1].lower()
        return ext in STATIC_EXT

    def do_GET(self):
        if self.is_static():
            return self.serve_static()
        self.proxy()

    def do_HEAD(self):
        if self.is_static():
            return self.serve_static(body=False)
        self.proxy()

    def do_POST(self):
        self.proxy()

    def do_PUT(self):
        self.proxy()

    def do_PATCH(self):
        self.proxy()

    def do_DELETE(self):
        self.proxy()

    def do_OPTIONS(self):
        self.proxy()

    def serve_static(self, body=True):
        path = unquote(urlsplit(self.path).path)
        if path in ("/", "/index.html"):
            path = "/matome-studio.html"
        full = os.path.normpath(os.path.join(ROOT, path.lstrip("/")))
        if not full.startswith(ROOT + os.sep):
            self.send_error(400, "bad path")
            return
        if not os.path.isfile(full):
            self.send_error(404, "file not found")
            return
        ctype = self.guess_type(full)
        ext = os.path.splitext(full)[1].lower()
        gz = full + ".gz"
        # Do not gzip .wasm: WebAssembly.instantiateStreaming requires a raw
        # application/wasm body. A Content-Encoding wrapper breaks the compile.
        use_gzip = (
            ext in {".js", ".css", ".svg", ".html"}
            and "gzip" in (self.headers.get("Accept-Encoding") or "")
            and os.path.isfile(gz)
        )
        payload_path = gz if use_gzip else full
        length = os.path.getsize(payload_path)
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(length))
        self.send_header("Vary", "Accept-Encoding")
        if use_gzip:
            self.send_header("Content-Encoding", "gzip")
        if ext == ".wasm":
            # Never reused unasked: a rebuild replaces the module under the
            # same name, and a stale copy would not load the new studio.
            self.send_header("Cache-Control", "no-cache")
        elif ext in CACHEABLE:
            self.send_header("Cache-Control", "public, max-age=86400")
        else:
            self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if body:
            with open(payload_path, "rb") as handle:
                self.wfile.write(handle.read())

    def proxy(self):
        url = CORE + self.path
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else None
        headers = {}
        for key, value in self.headers.items():
            if key.lower() in HOP | {"host", "content-length"}:
                continue
            headers[key] = value
        req = Request(url, data=body, headers=headers, method=self.command)
        try:
            with urlopen(req, timeout=120) as resp:
                self.forward(resp.status, resp.headers, resp.read())
        except HTTPError as err:
            self.forward(err.code, err.headers, err.read())
        except URLError as err:
            msg = ("core is not reachable at %s: %s\n" % (CORE, err.reason)).encode()
            self.send_response(502)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def forward(self, status, headers, payload):
        """Hand Core's answer, success or error, back to the browser."""
        self.send_response(status)
        for key, value in headers.items():
            if key.lower() in HOP | {"content-encoding"}:
                continue
            self.send_header(key, value)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)


def main():
    if not ROOT or not os.path.isdir(ROOT):
        raise SystemExit("MATOME_WASM_ROOT is missing")
    httpd = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    # Port 0 takes any free port; this first line says which.
    port = httpd.server_address[1]
    print("wasm http://127.0.0.1:%s  (core %s, root %s)" % (port, CORE, ROOT), flush=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
