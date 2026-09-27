#!/usr/bin/env python3
"""Generate the client build configuration from app.toml."""

import json
import os
import pathlib
import sys
import tomllib
from urllib.parse import urlsplit


def origin(value: object) -> str:
    if not isinstance(value, str) or value != value.strip():
        raise SystemExit("default_server must be a URL string")
    try:
        parsed = urlsplit(value)
        parsed.port
    except ValueError as error:
        raise SystemExit("default_server must be an HTTP(S) origin") from error
    if (
        parsed.scheme not in ("http", "https")
        or not parsed.hostname
        or parsed.username
        or parsed.password
        or parsed.path not in ("", "/")
        or parsed.query
        or parsed.fragment
        or any(char.isspace() for char in parsed.netloc)
    ):
        raise SystemExit("default_server must be an HTTP(S) origin")
    return value.rstrip("/")


def main() -> None:
    targets = {"android", "web", "linux", "macos", "windows"}
    if (
        len(sys.argv) not in (4, 5)
        or sys.argv[3] not in targets
        or (len(sys.argv) == 5 and sys.argv[4] != "--test")
    ):
        raise SystemExit("usage: generate-build-config.py app.toml output.h platform [--test]")
    source = pathlib.Path(sys.argv[1])
    output = pathlib.Path(sys.argv[2])
    target = sys.argv[3]
    test_build = len(sys.argv) == 5
    with source.open("rb") as handle:
        config = tomllib.load(handle)
    if "default_server" not in config or set(config) - {"default_server", "platform"}:
        raise SystemExit("app.toml requires default_server and optional platform overrides")
    platforms = config.get("platform", {})
    if not isinstance(platforms, dict) or set(platforms) - targets:
        raise SystemExit("app.toml has an invalid platform")
    for options in platforms.values():
        if not isinstance(options, dict) or set(options) != {"default_server"}:
            raise SystemExit("platform overrides may contain only default_server")
    default = origin(config["default_server"])
    overrides = {name: origin(options["default_server"]) for name, options in platforms.items()}
    server = origin(os.environ.get("MATOME_TEST_DEFAULT_SERVER")) if test_build else overrides.get(target, default)
    if test_build and urlsplit(server).hostname not in ("localhost", "127.0.0.1", "10.0.2.2"):
        raise SystemExit("test default_server must use localhost, 127.0.0.1, or 10.0.2.2")
    output.parent.mkdir(parents=True, exist_ok=True)
    contents = f"#pragma once\n#define MATOME_DEFAULT_SERVER {json.dumps(server, ensure_ascii=True)}\n"
    if not output.exists() or output.read_text() != contents:
        output.write_text(contents)


if __name__ == "__main__":
    main()
