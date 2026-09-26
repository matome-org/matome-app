"""FakeCore, the e2e backend: its process and its /__e2e/ control API, for
the desktop smoke and the Android runner.

The run owns the process so a scenario can kill Core and bring it back on the
same port. It binds 127.0.0.1; the emulator reaches the host's loopback as
10.0.2.2, and FakeCore signs storage URLs with the Host it was reached by.
"""

from __future__ import annotations

import json
import subprocess
import urllib.request


class Core:
    def __init__(self, launcher: str):
        self.launcher = launcher
        self.port = 0
        self.process: subprocess.Popen | None = None

    @property
    def url(self) -> str:
        return f"http://127.0.0.1:{self.port}"

    @property
    def emulator_url(self) -> str:
        return f"http://10.0.2.2:{self.port}"

    def start(self) -> None:
        """Starts on any free port the first time, the same port after `stop`."""
        self.process = subprocess.Popen([self.launcher, "--port", str(self.port)],
                                        stdout=subprocess.PIPE, text=True)
        ready = self.process.stdout.readline().split()  # type: ignore[union-attr]
        if ready[:1] != ["fakecore"]:
            raise RuntimeError(f"fakecore did not start: {ready}")
        self.port = int(ready[1].rsplit(":", 1)[1])

    def stop(self) -> None:
        if self.process and self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=10)
        self.process = None

    def _call(self, method: str, route: str, body: dict | None = None) -> dict:
        data = json.dumps(body or {}).encode() if method == "POST" else None
        request = urllib.request.Request(f"{self.url}/__e2e/{route}", data=data, method=method,
                                         headers={"content-type": "application/json"})
        with urllib.request.urlopen(request, timeout=10) as reply:
            return json.loads(reply.read())

    def reset(self) -> dict:
        return self._call("POST", "reset")

    def seed(self, spec: dict) -> dict:
        return self._call("POST", "seed", spec)

    def fail(self, path: str, method: str = "", count: int = 1, mode: str = "status",
             status: int = 500, error: str = "server_error") -> dict:
        """The next `count` matching requests fail as `mode` says (status,
        drop, expire); "hold" answers them but parks the answers until
        `release`."""
        return self._call("POST", "fail", {"path": path, "method": method, "count": count,
                                           "mode": mode, "status": status, "error": error})

    def release(self) -> dict:
        return self._call("POST", "release")

    def state(self) -> dict:
        return self._call("GET", "state")

    def _find(self, kind: str, key: str, value: str) -> dict | None:
        return next((item for item in self.state()[kind] if item[key] == value), None)

    def document(self, title: str) -> dict | None:
        return self._find("documents", "title", title)

    def folder(self, name: str) -> dict | None:
        return self._find("folders", "name", name)

    def space(self, name: str) -> dict | None:
        return self._find("spaces", "name", name)

    def organization(self, name: str) -> dict | None:
        return self._find("organizations", "name", name)
