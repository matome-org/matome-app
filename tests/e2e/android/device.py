"""The emulator, driven through adb: uiautomator dumps, touch, keys, settings.

Qt names each accessible item after its objectName chain, so a node's
resource-id ends in the objectName (`...languageSwitcher.language_en`);
`Node.name` is that last segment. Accessible.name lands in content-desc.
Every wait polls the dump until its condition holds; nothing sleeps a fixed
time except where a gesture itself takes time (documented there).
"""

from __future__ import annotations

import re
import struct
import subprocess
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Callable, TypeVar

PACKAGE = "org.matome.studio"
ACTIVITY = "org.qtproject.qt.android.bindings.QtActivity"
TIMEOUT = 30.0
# The developer options' three animation scales (global settings).
ANIMATION_SCALES = ("animator_duration_scale", "transition_animation_scale", "window_animation_scale")

T = TypeVar("T")


class Failure(AssertionError):
    pass


def expect(ok: object, what: str) -> None:
    """Fails the scenario with `what` unless `ok`."""
    if not ok:
        raise Failure(what)


@dataclass(frozen=True)
class Node:
    rid: str
    desc: str
    text: str
    cls: str
    package: str
    checked: bool
    enabled: bool
    focused: bool
    clickable: bool
    box: tuple[int, int, int, int]

    @property
    def name(self) -> str:
        return self.rid.rsplit(".", 1)[-1]

    @property
    def label(self) -> str:
        return self.desc or self.text

    @property
    def center(self) -> tuple[int, int]:
        left, top, right, bottom = self.box
        return (left + right) // 2, (top + bottom) // 2

    @property
    def width(self) -> int:
        return self.box[2] - self.box[0]

    @property
    def height(self) -> int:
        return self.box[3] - self.box[1]


class Screen:
    """One uiautomator dump."""

    def __init__(self, xml: str, rotation: int):
        self.rotation = rotation
        self.nodes: list[Node] = []
        root = ET.fromstring(xml)
        for el in root.iter("node"):
            a = el.attrib
            m = re.match(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]", a.get("bounds", ""))
            box = tuple(int(v) for v in m.groups()) if m else (0, 0, 0, 0)
            self.nodes.append(Node(
                rid=a.get("resource-id", ""), desc=a.get("content-desc", ""),
                text=a.get("text", ""), cls=a.get("class", ""), package=a.get("package", ""),
                checked=a.get("checked") == "true", enabled=a.get("enabled") == "true",
                focused=a.get("focused") == "true", clickable=a.get("clickable") == "true",
                box=box))  # type: ignore[arg-type]

    def all(self, name: str) -> list[Node]:
        return [n for n in self.nodes if n.name == name]

    def get(self, name: str) -> Node | None:
        found = self.all(name)
        return found[0] if found else None

    def __contains__(self, name: str) -> bool:
        return self.get(name) is not None

    def prefixed(self, prefix: str) -> list[Node]:
        """Nodes whose objectName is `prefix` and a number, in index order."""
        pattern = re.compile(re.escape(prefix) + r"(\d+)$")
        hits = [(int(m.group(1)), n) for n in self.nodes if (m := pattern.match(n.name))]
        return [n for _, n in sorted(hits, key=lambda hit: hit[0])]

    def labelled(self, label: str) -> Node | None:
        return next((n for n in self.nodes if label in (n.desc, n.text)), None)

    def packages(self) -> set[str]:
        return {n.package for n in self.nodes}

    def summary(self) -> str:
        return " | ".join(f"{n.name or n.cls.rsplit('.', 1)[-1]}={n.label!r}"
                          for n in self.nodes if n.rid or n.label)[:3000]


class Image:
    """A raw `screencap` frame: RGBA, row-major."""

    def __init__(self, raw: bytes):
        width, height, _fmt = struct.unpack_from("<III", raw)
        # API 28+ adds a colour-space word to the 12-byte header.
        header = len(raw) - width * height * 4
        self.width, self.height, self.pixels = width, height, raw[header:]

    def pixel(self, x: int, y: int) -> tuple[int, int, int]:
        at = (y * self.width + x) * 4
        return self.pixels[at], self.pixels[at + 1], self.pixels[at + 2]

    def crop(self, box: tuple[int, int, int, int]) -> bytes:
        left, top, right, bottom = box
        return b"".join(self.pixels[(y * self.width + left) * 4:(y * self.width + right) * 4]
                        for y in range(top, bottom))


def near(a: tuple[int, int, int], b: tuple[int, int, int], tolerance: int = 12) -> bool:
    return all(abs(x - y) <= tolerance for x, y in zip(a, b))


class Device:
    def __init__(self) -> None:
        self._restore: dict[tuple[str, str], str] = {}

    # -- adb -----------------------------------------------------------------

    def adb(self, *args: str, check: bool = True, binary: bool = False,
            timeout: float = 60) -> subprocess.CompletedProcess:
        result = subprocess.run(["adb", *args], capture_output=True, text=not binary, timeout=timeout)
        if check and result.returncode != 0:
            raise Failure(f"adb {' '.join(args)}: {result.stderr or result.stdout}")
        return result

    def shell(self, *args: str, check: bool = True) -> str:
        return self.adb("shell", *args, check=check).stdout

    # -- settings, restored at the end of the run ----------------------------

    def setting(self, namespace: str, key: str, value: str | None) -> None:
        """Sets a device setting; `close` puts back what the run found."""
        if (namespace, key) not in self._restore:
            self._restore[(namespace, key)] = self.shell("settings", "get", namespace, key).strip()
        if value is None:
            self.shell("settings", "delete", namespace, key)
        else:
            self.shell("settings", "put", namespace, key, value)

    def close(self) -> None:
        for (namespace, key), value in self._restore.items():
            if value == "null":
                self.shell("settings", "delete", namespace, key, check=False)
            else:
                self.shell("settings", "put", namespace, key, value, check=False)
        self._restore.clear()
        self.app_locales("")

    def app_locales(self, tags: str) -> None:
        """The app's own language (Android 13 per-app locales); "" follows
        the device again."""
        self.shell("cmd", "locale", "set-app-locales", PACKAGE, "--locales", tags)

    # -- the app ---------------------------------------------------------------

    def stop(self) -> None:
        self.shell("am", "force-stop", PACKAGE)

    def clear(self) -> None:
        self.shell("pm", "clear", PACKAGE)

    def launch(self) -> None:
        self.shell("am", "start", "-W", "-n", f"{PACKAGE}/{ACTIVITY}")

    # -- reading the screen ----------------------------------------------------

    def dump(self) -> Screen:
        for _ in range(5):
            out = self.adb("exec-out", "uiautomator", "dump", "/dev/tty", check=False).stdout
            end = out.rfind("</hierarchy>")
            if end >= 0:
                xml = out[out.find("<?xml"):end + len("</hierarchy>")]
                rotation = int(re.search(r'rotation="(\d)"', xml).group(1))  # type: ignore[union-attr]
                return Screen(xml, rotation)
        raise Failure(f"uiautomator dump failed: {out[-300:]}")

    def wait(self, check: Callable[[Screen], T], what: str, timeout: float = TIMEOUT) -> T:
        deadline = time.monotonic() + timeout
        while True:
            screen = self.dump()
            result = check(screen)
            if result:
                return result
            if time.monotonic() > deadline:
                raise Failure(f"timed out waiting for {what}\nscreen: {screen.summary()}")

    def showing(self, name: str, timeout: float = TIMEOUT) -> Screen:
        """Waits for a screen with #name on it."""
        return self.wait(lambda s: s if name in s else None, f"#{name}", timeout)

    def node(self, name: str, timeout: float = TIMEOUT) -> Node:
        return self.wait(lambda s: s.get(name), f"#{name}", timeout)

    def still(self, name: str) -> Node:
        """Waits for #name to rest in one place across two dumps: laid out
        and done moving (a form panning for the soft keyboard)."""
        last: list[Node | None] = [None]

        def resting(s: Screen) -> Node | None:
            node, previous = s.get(name), last[0]
            last[0] = node
            return node if node and previous and node.box == previous.box else None
        return self.wait(resting, f"#{name} to rest")

    def gone(self, name: str, timeout: float = TIMEOUT) -> Screen:
        return self.wait(lambda s: s if name not in s else None, f"#{name} to go", timeout)

    def focused(self, name: str) -> Screen:
        """Waits for a screen whose #name has the focus."""
        return self.wait(lambda s: s if (n := s.get(name)) and n.focused else None, f"#{name} focused")

    def label(self, name: str, want: str | Callable[[str], bool], timeout: float = TIMEOUT) -> Node:
        """Waits for #name whose content-desc/text is `want` (or satisfies it)."""
        test = want if callable(want) else (lambda label: label == want)
        return self.wait(lambda s: next((n for n in s.all(name) if test(n.label)), None),
                         f"#{name} labelled {want!r}", timeout)

    def screenshot(self) -> Image:
        return Image(self.adb("exec-out", "screencap", binary=True).stdout)

    # -- touch and keys --------------------------------------------------------

    def tap(self, target: Node | str | tuple[int, int]) -> None:
        x, y = self._point(target)
        self.shell("input", "tap", str(x), str(y))

    def long_press(self, target: Node | str | tuple[int, int]) -> None:
        # A swipe that stays put for 900 ms is Android's long press; Qt's
        # TapHandler fires at 800 ms (its long-press threshold).
        x, y = self._point(target)
        self.shell("input", "swipe", str(x), str(y), str(x), str(y), "900")

    def swipe(self, start: tuple[int, int], end: tuple[int, int], ms: int = 300) -> None:
        self.shell("input", "swipe", *map(str, (*start, *end, ms)))

    def key(self, *codes: str) -> None:
        self.shell("input", "keyevent", *codes)

    def back(self) -> None:
        """Android's Back, with the soft keyboard out of the way: while the
        input method counts as shown (it does after focusing a field, even
        with the hardware keyboard standing in), Back only closes it."""
        deadline = time.monotonic() + TIMEOUT
        while "mInputShown=true" in self.shell("dumpsys", "input_method"):
            if time.monotonic() > deadline:
                raise Failure("the soft keyboard would not close")
            self.key("KEYCODE_BACK")
        self.key("KEYCODE_BACK")

    def enter(self) -> None:
        self.key("KEYCODE_ENTER")

    def type(self, text: str) -> None:
        # One injection per field: Qt's Android input method leaves the first
        # of several injected characters composing, so focus loss would move
        # it to the end. `input text` takes %s for a space.
        self.shell("input", "text", text.replace(" ", "%s"))

    def fill(self, field: Node, text: str) -> None:
        """Replaces the text of `field`: tap, select all, delete, type. Touch
        and keys reach Qt in order, so the tap has focused it by the time
        the keys land; callers read the result back from a dump."""
        self.tap(field)
        self.shell("input", "keycombination", "KEYCODE_CTRL_LEFT", "KEYCODE_A")
        self.key("KEYCODE_DEL")
        if text:
            self.type(text)

    def _point(self, target: Node | str | tuple[int, int]) -> tuple[int, int]:
        if isinstance(target, tuple):
            return target
        node = self.node(target) if isinstance(target, str) else target
        return node.center
