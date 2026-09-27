"""4 Interaction by touch: tap and long press, the menus, the keymap and
command sheet from the account menu, and every control's accessible name."""

from __future__ import annotations

import re

from app import ACME, DARK, ORGS, App, scenario
from device import PACKAGE, Screen, expect

ROW_MENU = {"download": "Download", "rename": "Rename", "cut": "Cut", "trash": "Move to trash",
            "new": "New folder", "upload": "Upload file", "refresh": "Refresh"}


@scenario("4.2", "4.3", title="a tap opens, a long press opens a menu that is picked by touch")
def tap_and_long_press(app: App) -> None:
    d = app.device
    app.inbox()
    screen = app.long_menu(app.row("root.txt"))
    items = app.menu_items(screen)
    expect(items == list(ROW_MENU), f"a document's menu offers {items}")
    expect([screen.get(f"menu_{i}").label for i in items] == list(ROW_MENU.values()), "the menu's labels")
    app.dismiss(screen)
    expect(app.rows(app.here("Inbox")) == ["Docs", "root.txt"] and "rowEditor" not in d.dump(),
           "closing the menu did something")

    screen = app.long_menu(app.row("Docs"))
    items = app.menu_items(screen)
    expect(items == [i for i in ROW_MENU if i != "download"], f"a folder's menu offers {items}")
    expect(screen.get("menu_trash").label == "Delete folder", "a folder's menu does not delete it for good")
    app.run_item(screen.get("menu_new"))
    app.name_it("Fresh")
    app.wait_rows(["Docs", "Fresh", "root.txt"])
    expect(app.core.folder("Fresh"), "the folder made from the menu is not in Core")

    screen = app.long_menu(app.blank())
    expect(app.menu_items(screen) == ["new", "upload", "refresh"],
           f"the blank list's menu offers {app.menu_items(screen)}")
    app.dismiss(screen)
    d.tap(app.row("Docs"))
    app.here("Docs")


@scenario("4.6", title="the keymap and the command sheet open from the account menu")
def keymap_and_sheet(app: App) -> None:
    d = app.device
    app.start(ACME)
    app.account("keymap")
    keys = d.wait(lambda s: s.labelled("Keys"), "the keymap")
    d.tap((keys.center[0], keys.box[3] + (d.screenshot().height - keys.box[3]) // 2))
    d.wait(lambda s: s if s.labelled("Keys") is None else None, "the keymap to close")

    app.account("sheet")
    d.focused("sheetQuery")
    d.type("dark")
    screen = d.wait(lambda s: s if s.labelled("Theme dark") and not s.labelled("Refresh") else None,
                    "the sheet filtered to Theme dark")
    d.tap(screen.labelled("Theme dark"))
    d.gone("sheetQuery")
    app.background(DARK)


CONTROLS = ("android.widget.Button", "android.widget.ToggleButton", "android.widget.EditText",
            "android.widget.CheckBox")


def nameless(screen: Screen) -> list[str]:
    """Qt nodes a finger can act on (buttons, fields, rows, menu items)
    without an accessible name."""
    return [n.rid for n in screen.nodes
            if n.package == PACKAGE and n.rid.startswith("QGuiApplication")
            and (n.clickable or n.cls in CONTROLS or re.search(r"Row\d+$", n.name)
                 or n.name.startswith("menu_"))
            and not n.label.strip()]


@scenario("4.8", title="every control a finger reaches has an accessible name")
def accessible_names(app: App) -> None:
    d = app.device
    seen: dict[str, Screen] = {}
    screen = app.start(ACME, signed_in=False)
    seen["sign in"] = screen
    for link in ("registerLink", "forgotLink"):
        screen = seen[link] = app.pane(link)
    d.tap(screen.get("backToSignIn"))
    d.gone("backToSignIn")
    app.sign_in()
    seen["organizations"] = app.wait_rows(ORGS)
    seen["files"] = app.open("Acme", "Inbox")
    seen["row menu"] = app.long_menu(app.row("root.txt"))
    app.dismiss(seen["row menu"])
    seen["account menu"] = app.button_menu("accountButton")
    app.dismiss(seen["account menu"])
    d.tap("drawerButton")
    seen["drawer"] = d.showing("folderTree")
    d.tap("drawerButton")
    d.gone("folderTree")
    app.account("sheet")
    seen["sheet"] = d.showing("sheetQuery")

    for where, shown in seen.items():
        expect(not nameless(shown), f"{where}: nameless controls {nameless(shown)}")
    expect(all(s.get("locationEyebrow").label for s in (seen["organizations"], seen["files"]))
           and seen["sign in"].get("paneTitle").label, "headings without names")
