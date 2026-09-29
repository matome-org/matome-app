"""Check that the preview proxy preserves compressed Core responses."""

import gzip
import importlib.util
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
import unittest
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class CoreHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        status = 422 if self.path == "/api/error" else 200
        payload = gzip.compress(json.dumps({"status": status}).encode())
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *_args):
        pass


class ProxyTests(unittest.TestCase):
    def test_preserves_compressed_success_and_error_responses(self):
        path = Path(__file__).resolve().parents[1] / ".scripts/wasm-serve.py"
        spec = importlib.util.spec_from_file_location("wasm_serve", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        core = ThreadingHTTPServer(("127.0.0.1", 0), CoreHandler)
        module.CORE = f"http://127.0.0.1:{core.server_port}"
        proxy = ThreadingHTTPServer(("127.0.0.1", 0), module.Handler)
        servers = [core, proxy]
        threads = [Thread(target=server.serve_forever, daemon=True) for server in servers]
        for thread in threads:
            thread.start()
        try:
            for path, status in [("/api/success", 200), ("/api/error", 422)]:
                with self.subTest(status=status):
                    request = Request(
                        f"http://127.0.0.1:{proxy.server_port}{path}",
                        data=b"{}",
                        headers={"Content-Type": "application/json", "Accept-Encoding": "gzip"},
                        method="POST",
                    )
                    try:
                        response = urlopen(request, timeout=5)
                    except HTTPError as error:
                        response = error
                    with response:
                        payload = response.read()
                        self.assertEqual(response.status, status)
                        self.assertEqual(response.headers["Content-Encoding"], "gzip")
                        self.assertEqual(int(response.headers["Content-Length"]), len(payload))
                        self.assertEqual(json.loads(gzip.decompress(payload)), {"status": status})
        finally:
            for server in servers:
                server.shutdown()
                server.server_close()
            for thread in threads:
                thread.join()


if __name__ == "__main__":
    unittest.main()
