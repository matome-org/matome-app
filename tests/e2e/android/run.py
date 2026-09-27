#!/usr/bin/env python3
"""Android e2e: every scenario against the installed APK on a booted
emulator, each from a clean install and a freshly seeded FakeCore.

Usage: run.py <fakecore launcher> [cell or title words ...]

Filters keep the scenarios matching any argument: a cell ("3.1"), a section
("3."), or a word of the title. The device settings a scenario changes are
put back before the next one and at the end; files pushed for the picker
are removed.
"""

from __future__ import annotations

import signal
import sys
import time
import traceback

import auth  # noqa: F401  (each module registers its scenarios)
import files  # noqa: F401
import interaction  # noqa: F401
import look  # noqa: F401
import navigation  # noqa: F401
import responsive  # noqa: F401
import robustness  # noqa: F401
from app import APP_DOWNLOADS, DOWNLOADS, PUSHED, SCENARIOS, App, Scenario
from device import ANIMATION_SCALES, PACKAGE, Device, Failure
from fakecore import Core


def baseline(device: Device) -> None:
    """Portrait, the hardware keyboard standing in for the soft one, the
    app's own language unset, animations at their defaults."""
    device.setting("system", "accelerometer_rotation", "0")
    device.setting("system", "user_rotation", "0")
    device.setting("secure", "show_ime_with_hard_keyboard", "0")
    for scale in ANIMATION_SCALES:
        device.setting("global", scale, "1")
    device.app_locales("")


def matches(s: Scenario, wanted: str) -> bool:
    if wanted.endswith("."):
        return any(cell.startswith(wanted) for cell in s.cells)
    return wanted in s.cells or wanted.lower() in s.title.lower()


def crashes(device: Device) -> str:
    return "\n".join(line for line in device.shell("logcat", "-d", "-b", "crash").splitlines()
                     if PACKAGE in line)


def main(argv: list[str]) -> int:
    # A stopped run still restores the device and stops Core (the finally below).
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    core = Core(argv[0])
    wanted = argv[1:]
    chosen = sorted((s for s in SCENARIOS if not wanted or any(matches(s, w) for w in wanted)),
                    key=lambda s: [int(part) for part in s.cells[0].split(".")])
    device = Device()
    app = App(device, core)
    results: list[tuple[str, str, float, str]] = []
    core.start()
    print(f"e2e-android: fakecore on {core.url}; {len(chosen)} scenarios")
    try:
        for s in chosen:
            label = f"{' '.join(s.cells)} {s.title}"
            baseline(device)
            device.shell("logcat", "-b", "crash", "-c")
            began = time.monotonic()
            try:
                s.run(app)
                crashed = crashes(device)
                if crashed:
                    raise Failure(f"the app crashed:\n{crashed}")
                outcome, detail = "ok", ""
            except Exception as err:  # noqa: BLE001 - a scenario's failure is reported, the run goes on
                outcome = "FAIL"
                detail = str(err) if isinstance(err, Failure) else traceback.format_exc()
                if core.process is None:
                    core.start()
            spent = time.monotonic() - began
            results.append((label, outcome, spent, detail))
            print(f"  {outcome:4} {spent:5.1f}s  {label}" + (f"\n{detail}" if detail else ""),
                  flush=True)
    finally:
        device.stop()
        device.close()
        device.shell("rm", "-rf", f"{DOWNLOADS}/{PUSHED}*", APP_DOWNLOADS, check=False)
        core.stop()
    failed = [r for r in results if r[1] != "ok"]
    total = sum(r[2] for r in results)
    print(f"e2e-android: {len(results) - len(failed)}/{len(results)} passed in {total / 60:.1f} min")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
