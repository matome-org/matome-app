#!/usr/bin/env python3
"""Line coverage of the core and studio sources. Test-only files are ignored.

The gate holds the total and every listed file to the minimum."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


SOURCES = (
    "src/core/Client.cpp",
    "src/gui/Session.cpp",
    "src/gui/SessionActions.cpp",
    "src/gui/OrgModel.cpp",
    "src/gui/SpaceModel.cpp",
    "src/gui/FolderModel.cpp",
    "src/gui/DocumentModel.cpp",
    "src/gui/ViewModel.cpp",
    "src/gui/EntryModel.cpp",
    "src/gui/FolderTreeModel.cpp",
    "src/gui/Theme.cpp",
)


def gcov_report(scratch: Path, gcda: Path, source: Path) -> str:
    # gcov writes *.gcov next to cwd even with -n (GCC 16, included headers).
    # Keep that junk under the shadow build, never the source tree.
    scratch.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["gcov", "-n", "-o", str(gcda.parent), str(source)],
        check=True,
        capture_output=True,
        text=True,
        cwd=scratch,
    )
    return result.stdout + result.stderr


def lines_for(blob: str, source: Path) -> tuple[int, int]:
    take = False
    executed = 0
    total = 0
    for line in blob.splitlines():
        if line.startswith("File "):
            take = source.name in line
            continue
        if take and "Lines executed:" in line:
            percent, _, count = line.split("Lines executed:", 1)[1].strip().partition("% of ")
            total = int(count.split()[0])
            executed = round(float(percent) * total / 100.0)
    return executed, total


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min", type=float, default=90.0)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    scratch = root / "build-tests" / "coverage"
    executed = 0
    total = 0
    rows = []
    gcdas = list((root / "build-tests").rglob("*.gcda"))
    for rel in SOURCES:
        source = root / rel
        matched = [path for path in gcdas if path.stem == source.stem]
        if not matched:
            print(f"coverage: no gcda for {rel}", file=sys.stderr)
            return 1
        file_exec = 0
        file_total = 0
        best = -1.0
        for gcda in matched:
            blob = gcov_report(scratch, gcda, source)
            exec_n, total_n = lines_for(blob, source)
            score = 0 if total_n == 0 else exec_n / total_n
            if score > best:
                best = score
                file_total = total_n
                file_exec = exec_n
        rows.append((rel, file_exec, file_total))
        executed += file_exec
        total += file_total

    rows.append(("total", executed, total))
    below = []
    for rel, file_exec, file_total in rows:
        percent = 0 if file_total == 0 else 100.0 * file_exec / file_total
        print(f"{rel}: {percent:.1f}% ({file_exec}/{file_total})")
        if percent + 1e-9 < args.min:
            below.append(f"{rel} {percent:.1f}%")
    if below:
        print(f"coverage: below {args.min:.0f}%: {', '.join(below)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
