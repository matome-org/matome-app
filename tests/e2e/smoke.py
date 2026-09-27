#!/usr/bin/env python3
"""Real-binary smoke: the built matome-studio, offscreen, against fakecore.

Proves main.cpp's wiring that the in-process suite cannot: the bundled
fonts are registered, the saved language's translator is installed, the
window icon is set, saved settings come back, and the window signs in and
lists. The probe plugin (tests/probe) reads the live window and prints one
"probe {json}" line.

Usage: smoke.py <matome-studio> <fakecore or .scripts/fakecore.sh> <probe plugin dir>
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from fakecore import Core

ORG = "Smoke 煙"


def main() -> int:
    studio, fakecore, plugins = (Path(arg).resolve() for arg in sys.argv[1:4])
    core = Core(str(fakecore))
    core.start()
    try:
        url = core.url
        state = core.seed({"organizations": [{"name": ORG, "spaces": [{"name": "Inbox"}]}]})
        org = next(o["id"] for o in state["organizations"] if o["name"] == ORG)

        with tempfile.TemporaryDirectory(prefix="matome-smoke-") as home:
            config = Path(home, "config", "matome")
            config.mkdir(parents=True)
            (config / "matome-studio.conf").write_text(
                "[session]\n"
                "email=ok@localhost\n"
                f"apiBaseUrl={url}\n"
                f"lastOrgId={org}\n"
                "\n[theme]\n"
                "mode=dark\n"
                "language=ja\n")
            env = {
                **os.environ,
                "HOME": home,
                "XDG_CONFIG_HOME": str(Path(home, "config")),
                "XDG_STATE_HOME": str(Path(home, "state")),
                "OMARCHY_PATH": str(Path(home, "omarchy")),
                "QT_QPA_PLATFORM": "offscreen",
                "QT_QPA_PLATFORMTHEME": "",
                "QT_PLUGIN_PATH": str(plugins),
                "QT_QPA_GENERIC_PLUGINS": "matomeprobe",
                "MATOME_PROBE_PASSWORD": "secret12",
            }
            run = subprocess.run([str(studio)], env=env, capture_output=True, text=True,
                                 timeout=60)
        lines = [line for line in run.stdout.splitlines() if line.startswith("probe ")]
        if not lines:
            raise SystemExit(f"smoke: no probe report (exit {run.returncode})\n{run.stderr}")
        seen = json.loads(lines[-1][len("probe "):])
        checks = {
            "exit 0": run.returncode == 0,
            "bundled fonts": {"Inter", "Newsreader", "Cormorant Garamond", "Noto Sans JP",
                              "Noto Serif JP"} <= set(seen.get("fonts", [])),
            "window icon": seen.get("icon") is True,
            "application name": seen.get("application") == "matome-studio"
            and seen.get("organization") == "matome",
            "saved theme": seen.get("mode") == "dark" and seen.get("dark") is True
            and seen.get("windowColor") == seen.get("background"),
            "saved language and its translator": seen.get("language") == "ja"
            and seen.get("submitText") == "サインイン",
            "saved email and server": seen.get("email") == "ok@localhost"
            and seen.get("emailField") == "ok@localhost" and seen.get("apiBaseUrl") == url,
            "signs in": seen.get("signedIn") is True,
            "reopens the saved organization": seen.get("currentOrgId") == org
            and seen.get("childKind") == "space" and seen.get("entries") == ["Inbox"],
            "lists organizations": ORG in seen.get("organizations", []),
        }
        failed = [name for name, ok in checks.items() if not ok]
        if failed:
            raise SystemExit(f"smoke: failed {failed}\nprobe {json.dumps(seen, ensure_ascii=False)}"
                             f"\n{run.stderr}")
        print(f"e2e smoke: {len(checks)} checks on {studio.name} against {url}")
        return 0
    finally:
        core.stop()


if __name__ == "__main__":
    sys.exit(main())
