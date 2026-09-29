"""5 Responsive: the drawer, the floating button, rotation, Android Back,
and the soft keyboard."""

from __future__ import annotations

from app import ACME, App, scenario
from device import Screen, expect

LONG = {"organizations": [{"name": "Acme", "spaces": [{"name": "Inbox", "documents": [
    {"title": "Row", "repeat": 30}]}]}]}


@scenario("5.1", title="the drawer opens from its button and closes on the scrim and on Back")
def drawer(app: App) -> None:
    d = app.device
    app.inbox()
    screen = app.drawer()
    sidebar = screen.get("orgList")
    expect(sidebar.box[0] == 0 and sidebar.width < screen.get("entryList").width,
           "the drawer does not slide in over part of the list")
    d.tap(((sidebar.box[2] + d.screenshot().width) // 2, screen.get("entryList").center[1]))
    d.gone("orgList")
    app.here("Inbox")

    app.drawer()
    d.back()
    d.gone("orgList")
    app.here("Inbox")


@scenario("5.2", title="the floating button offers New, then Upload in a space, then Paste after a cut")
def floating_button(app: App) -> None:
    def offers(want: list[str], labels: list[str]) -> None:
        menu = app.button_menu("fabButton")
        expect(app.menu_items(menu) == want, f"the floating button offers {app.menu_items(menu)}")
        expect([menu.get(f"menu_{i}").label for i in want] == labels, "the floating menu's labels")
        app.dismiss(menu)

    app.start(ACME)
    offers(["new"], ["New organization"])
    app.open("Acme")
    offers(["new"], ["New space"])
    app.open("Inbox")
    offers(["new", "upload"], ["New folder", "Upload file"])
    app.menu("root.txt", "cut")
    offers(["new", "upload", "paste"], ["New folder", "Upload file", "Paste"])
    app.open("Docs")
    app.fab("paste")
    app.wait_rows(["Deep", "a.txt", "root.txt"])


def wide(screen: Screen) -> bool:
    return "orgList" in screen and "drawerButton" not in screen and "fabButton" not in screen \
        and "newButton" in screen


def narrow(screen: Screen) -> bool:
    return "orgList" not in screen and "drawerButton" in screen and "fabButton" in screen \
        and "newButton" not in screen


@scenario("5.4", title="rotation switches narrow and wide layouts and keeps the place")
def rotation(app: App) -> None:
    d = app.device
    app.inbox()
    app.open("Docs")
    d.tap("filterButton")
    d.focused("filterField")
    d.type("a")
    before = app.wait_rows(["a.txt"])
    expect(narrow(before), "portrait is not the narrow layout")
    typed = before.get("filterField").text

    d.setting("system", "user_rotation", "1")
    screen = d.wait(lambda s: s if s.rotation == 1 and wide(s) else None, "the wide landscape layout")
    expect(app.crumbs(screen) == ["Acme", "Inbox", "Docs"] and app.rows(screen) == ["a.txt"],
           "rotating lost the place or the filter")
    expect(screen.get("filterField").text == typed, "rotating lost the filter text")
    expect(app.rows(screen, "treeRow") == ["Inbox", "Docs, expanded", "Deep"], "the tree in the sidebar")

    d.setting("system", "user_rotation", "0")
    screen = d.wait(lambda s: s if s.rotation == 0 and narrow(s) else None, "the narrow portrait layout")
    expect(screen.get("locationTitle").label == "Docs" and app.rows(screen) == ["a.txt"]
           and screen.get("filterField").text == typed, "rotating back lost the place or the filter")


@scenario("5.5", title="Back closes the drawer, the menu, and the editor first, then goes up; "
                       "at the root it leaves")
def back_order(app: App) -> None:
    d = app.device
    app.inbox()
    app.open("Docs")

    def after_back(closes: str | None, place: str) -> None:
        """Back closes #closes (when given) and leaves the explorer at `place`."""
        d.back()
        if closes:
            d.gone(closes)
        app.here(place)

    app.drawer()
    after_back("orgList", "Docs")
    app.long_menu(app.row("a.txt"))
    after_back("contextMenuList", "Docs")
    app.menu("a.txt", "rename")
    d.showing("rowEditor")
    after_back("rowEditor", "Docs")
    app.row("a.txt")
    after_back(None, "Inbox")
    d.tap("homeLink")
    app.here("Matome")
    d.back()
    d.gone("homeLink")


@scenario("5.6", title="the soft keyboard never covers the field being edited")
def soft_keyboard(app: App) -> None:
    """Typing goes in with the hardware keyboard; then the soft one is let
    show and each field is focused again by a tap."""
    d = app.device

    def clear_of_keyboard(name: str) -> None:
        """Qt pans the window to the cursor, so the text line (the field's
        upper three quarters; the rest is padding) sits above the keyboard."""
        def above(s: Screen) -> Screen | None:
            top = d.keyboard_top()
            node = s.get(name)
            return s if top and node and node.focused and node.box[1] + node.height * 3 // 4 <= top else None
        d.wait(above, f"#{name} above the soft keyboard")

    app.start(LONG, signed_in=False)
    d.setting("secure", "show_ime_with_hard_keyboard", "1")
    # Bottom up: the window pans up for each, so the ones above stay reachable.
    # Each field is tapped once it holds still, not mid-pan.
    for name in ("apiField", "passwordField", "emailField"):
        d.tap(d.still(name))
        clear_of_keyboard(name)
    d.setting("secure", "show_ime_with_hard_keyboard", "0")
    app.sign_in()
    app.open("Acme", "Inbox")

    d.setting("secure", "show_ime_with_hard_keyboard", "1")
    d.tap("filterButton")
    clear_of_keyboard("filterField")
    # A tap on a row takes focus off the empty filter, which closes.
    d.tap(app.row("Row 001"))
    d.showing("filterButton")
    screen = d.dump()
    bottom = screen.get("entryList").box[3]
    rows = screen.prefixed("entryRow")
    lowest = [row for row in rows if row.box[3] <= bottom and row.height == rows[0].height][-1]
    app.menu(lowest.label, "rename")
    clear_of_keyboard("rowEditor")
