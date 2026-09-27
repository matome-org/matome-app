"""2 Navigation on a phone's narrow layout: rows, crumbs, the mark, up,
the drawer's lists and tree, the filter, refresh, and the location header."""

from __future__ import annotations

from app import ACME, EMPTY_FOLDER, ORGS, OWN_ORG, App, scenario
from device import Node, Screen, expect

TWO_ORGS = {"organizations": ACME["organizations"] + [{"name": "Beta", "spaces": [{"name": "Plans"}]}]}


def eyebrow(screen: Screen, text: str) -> None:
    """The gold line over the location title."""
    expect(screen.get("locationEyebrow").label == text, f"the eyebrow does not read {text!r}")


def place(app: App, title: str, crumbs: list[str], rows: list[str] | None, kind: str) -> Screen:
    """Where the explorer stands: header, crumbs, rows (None: the empty state)."""
    screen = app.here(title)
    expect(app.crumbs(screen) == crumbs, f"crumbs {app.crumbs(screen)} at {title}, not {crumbs}")
    if rows is None:
        expect(screen.get("emptyState").label == EMPTY_FOLDER, f"{title} is not shown empty")
    else:
        expect(app.rows(screen) == rows, f"rows {app.rows(screen)} at {title}, not {rows}")
    eyebrow(screen, kind)
    return screen


@scenario("2.1", "2.3", "2.4", "2.5", "2.10",
          title="open by tap, crumbs, the mark, up and Back, and the header at every level")
def browse(app: App) -> None:
    d = app.device
    app.start(ACME)
    screen = place(app, "Matome", [], ORGS, "Organizations")
    expect(not screen.get("upButton").enabled, "up is offered at the root")
    app.open("Acme")
    place(app, "Acme", ["Acme"], ["Inbox"], "Organization")
    app.open("Inbox")
    place(app, "Inbox", ["Acme", "Inbox"], ["Docs", "root.txt"], "Space · Acme")
    app.open("Docs")
    place(app, "Docs", ["Acme", "Inbox", "Docs"], ["Deep", "a.txt"], "Folder · Inbox")
    app.open("Deep")
    place(app, "Deep", ["Acme", "Inbox", "Docs", "Deep"], None, "Folder · Docs")

    d.tap("crumb1")
    place(app, "Inbox", ["Acme", "Inbox"], ["Docs", "root.txt"], "Space · Acme")
    d.tap("crumb0")
    place(app, "Acme", ["Acme"], ["Inbox"], "Organization")
    app.open("Inbox", "Docs")
    d.tap("homeLink")
    place(app, "Matome", [], ORGS, "Organizations")

    app.open("Acme", "Inbox", "Docs")
    for title in ("Inbox", "Acme", "Matome"):
        d.tap("upButton")
        app.here(title)
    app.open("Acme", "Inbox")
    d.back()
    app.here("Acme")


@scenario("2.2", title="create an organization, a space, and a folder from the floating button")
def create_by_fab(app: App) -> None:
    d = app.device
    app.start()
    menu = app.button_menu("fabButton")
    expect(app.menu_items(menu) == ["new"], f"the floating button at the root offers {app.menu_items(menu)}")
    app.run_item(d.label("menu_new", "New organization"))
    app.name_it("Beta")
    screen = app.here("Beta")
    expect(screen.get("emptyState").label == "No spaces yet.\nCreate one to continue.", "Beta is not empty")
    expect(app.core.organization("Beta"), "Core has no Beta")

    app.new("Plans", "New space")
    place(app, "Plans", ["Beta", "Plans"], None, "Space · Beta")
    space = app.core.space("Plans")
    app.new("Specs", "New folder")
    app.wait_rows(["Specs"])
    folder = app.core.folder("Specs")
    expect(folder and folder["space_id"] == space["id"] and folder["parent_id"] is None,
           f"Specs is not a top folder of Plans: {folder}")


def chevron(row: Node) -> tuple[int, int]:
    """The tree row's disclosure: EntryRow's inset, gap, indent per depth
    (the tree's folders sit one level in), then half an icon, in dp."""
    dp = row.height / 48
    return row.box[0] + round((8 + 8 + 12 + 8) * dp), row.center[1]


@scenario("2.6", "2.7", title="the drawer's tree folds and opens, and switches org and space")
def drawer_tree(app: App) -> None:
    d = app.device
    app.start(TWO_ORGS)
    app.open("Acme", "Inbox")
    screen = app.drawer()
    expect(app.rows(screen, "orgRow") == ["Acme", "Beta", OWN_ORG], "orgs in the drawer")
    expect(app.rows(screen, "spaceRow") == ["Inbox"], "spaces in the drawer")
    app.wait_rows(["Inbox", "Docs, collapsed"], "treeRow")
    d.tap(chevron(app.row("Docs, collapsed", "treeRow")))
    app.wait_rows(["Inbox", "Docs, expanded", "Deep"], "treeRow")
    d.tap(chevron(app.row("Docs, expanded", "treeRow")))
    app.wait_rows(["Inbox", "Docs, collapsed"], "treeRow")
    d.tap(chevron(app.row("Docs, collapsed", "treeRow")))
    d.tap(app.row("Deep", "treeRow"))
    d.gone("orgList")
    place(app, "Deep", ["Acme", "Inbox", "Docs", "Deep"], None, "Folder · Docs")

    app.drawer()
    d.tap(app.row("Beta", "orgRow"))
    d.gone("orgList")
    place(app, "Beta", ["Beta"], ["Plans"], "Organization")
    app.drawer()
    d.tap(app.row("Plans", "spaceRow"))
    d.gone("orgList")
    place(app, "Plans", ["Beta", "Plans"], None, "Space · Beta")
    app.drawer()
    d.tap(app.row("Acme", "orgRow"))
    d.gone("orgList")
    app.here("Acme")


@scenario("2.8", title="the filter narrows as you type, says when nothing matches, and clears")
def filter_rows(app: App) -> None:
    d = app.device
    app.inbox()
    d.tap("filterButton")
    screen = d.focused("filterField")
    expect("breadcrumb" not in screen, "the crumbs stay beside an open filter on a phone")
    d.type("root")
    app.wait_rows(["root.txt"])
    app.form({"filterField": "zzz"})
    d.label("emptyState", "Nothing here matches “zzz”.")
    app.form({"filterField": ""})
    app.wait_rows(["Docs", "root.txt"])
    d.tap(app.blank())
    d.wait(lambda s: s if "filterButton" in s and "breadcrumb" in s else None, "the filter to close")


@scenario("2.9", title="refresh from the menu, on a row and on the blank list")
def refresh(app: App) -> None:
    app.start(ACME)
    app.wait_rows(ORGS)
    app.core.seed({"organizations": [{"name": "Gamma"}]})
    app.menu("Acme", "refresh")
    app.wait_rows(ORGS + ["Gamma"])
    app.core.seed({"organizations": [{"name": "Delta"}]})
    menu = app.long_menu(app.blank())
    expect(app.menu_items(menu) == ["new", "refresh"], f"the blank menu offers {app.menu_items(menu)}")
    app.run_item(menu.get("menu_refresh"))
    app.wait_rows(ORGS + ["Gamma", "Delta"])
