"""The studio on the emulator: the scenario registry, the per-scenario
fixture, and the gestures scenarios share (sign in, open by tap, menus, the
system file picker, pixel probes)."""

from __future__ import annotations

import hashlib
import os
import tempfile
from dataclasses import dataclass
from typing import Callable

from device import PACKAGE, Device, Failure, Image, Node, Screen, expect, near
from fakecore import Core

EMAIL = "ok@localhost"
PASSWORD = "secret12"
PICKER = "com.google.android.documentsui"
# Files the picker offers live in the public Download folder, named so the
# run can sweep them afterwards.
DOWNLOADS = "/sdcard/Download"
PUSHED = "matome-e2e-"
# The app's own download folder (QStandardPaths::DownloadLocation).
APP_DOWNLOADS = f"/sdcard/Android/data/{PACKAGE}/files/Download"

# Theme.cpp's Eva palettes, for pixel probes.
LIGHT = {"background": (0xF6, 0xF4, 0xEF), "failed": (0xB2, 0x3A, 0x2E), "accent": (0xE1, 0xB3, 0x46)}
DARK = {"background": (0x1A, 0x17, 0x14)}

# One organization with a space, a folder tree two deep, and documents
# with and without stored bytes. ok@localhost also owns "ok organization".
ACME = {"organizations": [{"name": "Acme", "spaces": [{
    "name": "Inbox",
    "folders": [{"name": "Docs", "folders": [{"name": "Deep"}],
                 "documents": [{"title": "a.txt", "content": "alpha"}]}],
    "documents": [{"title": "root.txt", "content": "root bytes"}]}]}]}
OWN_ORG = "ok organization"
ORGS = ["Acme", OWN_ORG]
EMPTY_FOLDER = "This folder is empty.\nCreate a folder or drop files here."
SERVER = "Core could not complete that request."
UNREACHABLE = "Could not reach Core at that URL."
CYCLE = "A folder cannot move into itself."

@dataclass
class Scenario:
    cells: tuple[str, ...]
    title: str
    run: Callable[["App"], None]


SCENARIOS: list[Scenario] = []


def scenario(*cells: str, title: str):
    """Registers a scenario covering matrix `cells`."""
    def register(run: Callable[["App"], None]) -> Callable[["App"], None]:
        SCENARIOS.append(Scenario(cells, title, run))
        return run
    return register


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


@dataclass
class App:
    device: Device
    core: Core

    # -- lifecycle -------------------------------------------------------------

    def start(self, seed: dict | None = None, signed_in: bool = True) -> Screen:
        """A clean Core (seeded) and a clean install pointed at it; signed in
        as ok@localhost with the keyboard's Enter unless told otherwise."""
        self.core.reset()
        if seed:
            self.core.seed(seed)
        self.open_server(self.fresh())
        if signed_in:
            return self.sign_in(apiField=self.core.emulator_url)
        return self.form({"apiField": self.core.emulator_url})

    def fresh(self) -> Screen:
        """Force-stops the app, wipes its data, and opens the sign-in form."""
        self.device.stop()
        self.device.clear()
        return self.launch("submitButton")

    def relaunch(self, expect: str) -> Screen:
        """Force-stops and starts the app again; waits for #expect."""
        self.device.stop()
        return self.launch(expect)

    def launch(self, expect: str) -> Screen:
        self.device.launch()
        return self.device.showing(expect)

    def inbox(self) -> Screen:
        """Signed in to a clean ACME, in Acme › Inbox."""
        self.start(ACME)
        return self.open("Acme", "Inbox")

    # -- sign-in form ----------------------------------------------------------

    def open_server(self, screen: Screen) -> Screen:
        """Shows the Core address field if it is hidden."""
        if "apiField" not in screen:
            self.device.tap(screen.get("serverToggle") or self.device.node("serverToggle"))
            screen = self.device.showing("apiField")
        return screen

    def form(self, values: dict[str, str]) -> Screen:
        """Fills each field #name with its text, then reads them all back
        (a password reads as one dot a character). Each field is found
        where it rests: focusing one brings up the soft keyboard, and the
        form moves for it."""
        for name, text in values.items():
            self.device.fill(self.device.still(name), text)

        def landed(s: Screen) -> Screen | None:
            for name, text in values.items():
                node = s.get(name)
                if node is None or node.text not in (text, "●" * len(text)):
                    return None
            return s
        return self.device.wait(landed, f"fields {values}")

    def pane(self, link: str) -> Screen:
        """Opens the pane named by link, returning to sign-in first if needed."""
        d = self.device
        if "backToSignIn" in d.dump():
            d.tap("backToSignIn")
            d.gone("backToSignIn")
        d.tap(link)
        return d.showing("backToSignIn")

    def sign_in(self, email: str = EMAIL, password: str = PASSWORD, **fields: str) -> Screen:
        """Types the credentials (and any other `fields`), then submits with
        the keyboard's Enter from the email field."""
        self.form({**fields, "passwordField": password, "emailField": email})
        self.device.enter()
        return self.device.showing("homeLink")

    # -- explorer ----------------------------------------------------------------

    @staticmethod
    def rows(screen: Screen, prefix: str = "entryRow") -> list[str]:
        return [n.label for n in screen.prefixed(prefix)]

    def wait_rows(self, want: list[str], prefix: str = "entryRow") -> Screen:
        return self.device.wait(lambda s: s if self.rows(s, prefix) == want else None,
                                f"{prefix} rows {want}")

    def row(self, title: str, prefix: str = "entryRow") -> Node:
        return self.device.wait(
            lambda s: next((n for n in s.prefixed(prefix) if n.label == title), None),
            f"{prefix} {title!r}")

    def here(self, title: str) -> Screen:
        """Waits until the location header names `title` and the list has
        settled: rows, or an empty state that is not the spinner."""
        def settled(s: Screen) -> Screen | None:
            header = s.get("locationTitle")
            empty = s.get("emptyState")
            if not header or header.label != title or (empty and empty.label == "Loading…"):
                return None
            return s if s.prefixed("entryRow") or empty else None
        return self.device.wait(settled, f"location {title!r}")

    @staticmethod
    def crumbs(screen: Screen) -> list[str]:
        return [n.label for n in screen.prefixed("crumb")]

    def open(self, first: str, *more: str) -> Screen:
        """Taps each row in turn: on a phone a tap opens."""
        for title in (first, *more):
            self.device.tap(self.row(title))
            screen = self.here(title)
        return screen

    def long_menu(self, target: Node | tuple[int, int]) -> Screen:
        """Long-presses `target` and waits for its menu."""
        self.device.long_press(target)
        return self.device.showing("contextMenuList")

    def button_menu(self, button: str) -> Screen:
        """Taps #button and waits for its menu."""
        self.device.tap(button)
        return self.device.showing("contextMenuList")

    def dismiss(self, menu: Screen) -> None:
        """A tap outside the menu, on the location title, closes it."""
        self.device.tap(menu.get("locationTitle"))
        self.device.gone("contextMenuList")

    def menu(self, title: str | None, command: str) -> None:
        """Long-presses the row titled `title` (or the list's blank space
        under the rows) and picks `command` from the menu."""
        self.long_menu(self.row(title) if title else self.blank())
        self.run_item(self.device.node(f"menu_{command}"))

    def run_item(self, item: Node) -> None:
        """Taps the open menu's `item` and waits for the menu to close."""
        self.device.tap(item)
        self.device.gone("contextMenuList")

    def blank(self) -> tuple[int, int]:
        """A point in the list under the last row, clear of the floating button."""
        screen = self.device.dump()
        listed = screen.get("entryList")
        if listed is None:
            raise Failure("no entry list")
        rows = screen.prefixed("entryRow")
        top = rows[-1].box[3] if rows else listed.box[1]
        return listed.box[0] + listed.width // 3, (top + listed.box[3]) // 2

    def choose(self, button: str, command: str, title: str | None = None) -> None:
        """Picks `command` (the item reading `title`, when given) from
        #button's menu."""
        self.button_menu(button)
        item = f"menu_{command}"
        self.run_item(self.device.label(item, title) if title else self.device.node(item))

    def fab(self, command: str) -> None:
        self.choose("fabButton", command)

    def account(self, command: str) -> None:
        self.choose("accountButton", command)

    @staticmethod
    def menu_items(screen: Screen) -> list[str]:
        return [n.name.removeprefix("menu_") for n in screen.nodes if n.name.startswith("menu_")]

    def new(self, name: str, title: str | None = None) -> None:
        """New from the floating button (its menu item reading `title`, when
        given), named in place, Enter."""
        self.choose("fabButton", "new", title)
        self.name_it(name)

    def name_it(self, name: str) -> None:
        """Types `name` into the row editor New opened, and Enter."""
        self.device.node("rowEditor")
        self.device.type(name)
        self.device.enter()
        self.device.gone("rowEditor")

    def drawer(self) -> Screen:
        """Opens the narrow layout's drawer."""
        self.device.tap("drawerButton")
        return self.device.showing("orgList")

    def until_held(self) -> None:
        """Waits until Core holds an answer back (a "hold" fault): the app
        stays in the state that answer would end until `core.release`."""
        self.device.wait(lambda s: self.core.state()["held"] == 1, "Core to hold an answer")

    def status(self, text: str) -> None:
        """The status line reads `text`."""
        self.device.label("explorerStatus", text)

    # -- the system file picker ------------------------------------------------

    def push(self, name: str, data: bytes) -> str:
        """Puts a file in the device's Download folder; answers its name."""
        name = PUSHED + name
        with tempfile.NamedTemporaryFile(delete=False) as local:
            local.write(data)
        try:
            self.device.adb("push", local.name, f"{DOWNLOADS}/{name}")
        finally:
            os.unlink(local.name)
        return name

    def pick(self, *names: str) -> None:
        """Chooses `names` in DocumentsUI's Downloads: a tap for one file, a
        long press, taps, and Select for several."""
        screen = self.device.wait(lambda s: s if PICKER in s.packages() else None, "the picker")
        if not any(n.rid.endswith("breadcrumb_text") and n.label == "Downloads" for n in screen.nodes):
            self.device.tap(self.device.wait(lambda s: s.labelled("Show roots"), "roots button"))
            self.device.tap(self.device.wait(
                lambda s: next((n for n in s.nodes if n.rid == "android:id/title"
                                and n.label == "Downloads"), None), "Downloads root"))

        def item(name: str) -> Node:
            return self.device.wait(
                lambda s: next((n for n in s.nodes if n.rid == "android:id/title" and n.label == name),
                               None), f"{name} in the picker")
        if len(names) == 1:
            self.device.tap(item(names[0]))
        else:
            self.device.long_press(item(names[0]))
            for name in names[1:]:
                self.device.tap(item(name))
            self.device.wait(lambda s: s.labelled(f"{len(names)} selected"), "the selection")
            self.device.tap(self.device.wait(lambda s: s.labelled("Select"), "Select"))
        self.device.wait(lambda s: s if PICKER not in s.packages() and "homeLink" in s else None,
                         "back in the studio")

    # -- pixels ----------------------------------------------------------------

    def status_ink(self, colour: tuple[int, int, int]) -> bool:
        """Some text in the status line (left of the account link) is drawn
        in `colour`."""
        account = self.device.node("accountButton")
        box = (0, account.box[1], account.box[0], account.box[3])
        return count(self.device.screenshot(), box, colour) > 10

    def failed(self, text: str) -> None:
        """The status line shows the error `text`, in the theme's `failed`."""
        self.device.wait(lambda s: self.status_ink(LIGHT["failed"]), "an error in the status line")
        self.status(text)

    def background(self, colours: dict) -> None:
        """The window's plain background (the left edge, mid-height) shows
        `colours`' background; waits out the theme's crossfade."""
        d = self.device
        d.wait(lambda s: near((image := d.screenshot()).pixel(4, image.height // 2), colours["background"]),
               f"the background to turn {colours['background']}")


def count(image: Image, box: tuple[int, int, int, int], colour: tuple[int, int, int],
          tolerance: int = 10, step: int = 2) -> int:
    """How many pixels in `box` (every `step`th row and column) are `colour`."""
    left, top, right, bottom = box
    return sum(1 for y in range(top, bottom, step) for x in range(left, right, step)
               if near(image.pixel(x, y), colour, tolerance))


def japanese(d: Device, screen: Screen) -> None:
    """日本語 in the switcher is drawn as three different glyphs, not
    three identical missing-glyph boxes."""
    mark = screen.get("language_ja")
    image = d.screenshot()
    paper = image.pixel(mark.box[0] + 1, mark.box[1] + 1)
    ink = [x for x in range(mark.box[0], mark.box[2])
           if any(not near(image.pixel(x, y), paper, 60) for y in range(mark.box[1], mark.box[3]))]
    expect(len(ink) > mark.width // 3, "日本語 is not drawn")
    left, right = ink[0], ink[-1] + 1
    third = (right - left) // 3
    glyphs = [image.crop((left + i * third, mark.box[1], left + (i + 1) * third, mark.box[3]))
              for i in range(3)]
    expect(len(set(glyphs)) == 3, "日本語 renders as identical boxes")
