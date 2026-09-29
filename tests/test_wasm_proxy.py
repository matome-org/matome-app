"""Check web preview caching and compressed Core responses."""

from contextlib import contextmanager
import gzip
import importlib.util
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread
from tempfile import TemporaryDirectory
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


@contextmanager
def running_server(handler):
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield server
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


class ProxyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).resolve().parents[1] / ".scripts/wasm-serve.py"
        spec = importlib.util.spec_from_file_location("wasm_serve", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        cls.module = module

    def test_preserves_compressed_success_and_error_responses(self):
        with running_server(CoreHandler) as core:
            self.module.CORE = f"http://127.0.0.1:{core.server_port}"
            with running_server(self.module.Handler) as proxy:
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

    def test_revalidates_versioned_build_assets(self):
        with TemporaryDirectory() as scratch:
            self.module.ROOT = scratch
            files = {
                "matome-studio.js?v=new-build": "no-cache",
                "qtloader.js?v=new-build": "no-cache",
                "matome-studio.wasm": "no-cache",
                "font.ttf": "public, max-age=86400",
            }
            for name in files:
                Path(scratch, name.split("?")[0]).write_bytes(b"asset")
            with running_server(self.module.Handler) as proxy:
                for name, cache in files.items():
                    with self.subTest(asset=name):
                        with urlopen(f"http://127.0.0.1:{proxy.server_port}/{name}", timeout=5) as response:
                            self.assertEqual(response.headers["Cache-Control"], cache)
                            self.assertEqual(response.read(), b"asset")


if __name__ == "__main__":
    unittest.main()
