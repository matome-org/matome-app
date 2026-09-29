"""7 Robustness: Core dying, server errors at every level, a long list,
long and Japanese names, and the APK booting from the launcher."""

from __future__ import annotations

from app import (
    ACME,
    DARK,
    EMPTY_FOLDER,
    LIGHT,
    ORGS,
    SERVER,
    UNREACHABLE,
    App,
    count,
    japanese,
    scenario,
)
from device import ACTIVITY, PACKAGE, Node, expect, near


def recovered(app: App) -> None:
    app.device.wait(lambda s: not app.status_ink(LIGHT["failed"]), "the error to clear")


@scenario("7.1", title="Core dies mid-use: the studio says so, keeps what it shows, and recovers")
def core_dies(app: App) -> None:
    d = app.device
    app.inbox()
    app.core.stop()
    app.menu(None, "refresh")
    app.failed(UNREACHABLE)
    expect(app.rows(d.dump()) == ["Docs", "root.txt"], "the rows went with Core")
    app.open("Docs")
    d.tap(app.row("Deep"))
    d.wait(lambda s: s if s.get("locationTitle").label == "Deep" else None, "Deep")
    d.label("emptyState", UNREACHABLE)

    app.core.start()
    app.core.seed(ACME)
    app.menu(None, "refresh")
    d.label("emptyState", EMPTY_FOLDER)
    d.tap("upButton")
    app.wait_rows(["Deep", "a.txt"])
    recovered(app)


@scenario("7.2", title="a server error at every level says so, and a refresh recovers")
def server_errors(app: App) -> None:
    d = app.device
    app.start(ACME)
    for path, where in (("^/api/v1/organizations$", None), ("/spaces$", "Acme"), ("/folders$", "Inbox")):
        if where:
            app.open(where)
        rows = app.rows(d.dump())
        app.core.fail(path, method="GET")
        app.menu(None, "refresh")
        app.failed(SERVER)
        expect(app.rows(d.dump()) == rows, f"the rows went with the error at {where or 'the root'}")
        app.menu(None, "refresh")
        recovered(app)
    app.open("Docs", "Deep")
    app.core.fail("/documents$", method="GET")
    app.menu(None, "refresh")
    d.label("emptyState", SERVER)
    app.menu(None, "refresh")
    d.label("emptyState", EMPTY_FOLDER)

    d.tap("homeLink")
    app.wait_rows(ORGS)
    app.core.fail("^/api/v1/organizations$", method="POST")
    app.new("Beta")
    app.failed(SERVER)
    expect(app.core.organization("Beta") is None, "Beta was made anyway")


def visible(app: App) -> list[Node]:
    screen = app.device.dump()
    top, bottom = screen.get("entryList").box[1], screen.get("entryList").box[3]
    return [row for row in screen.prefixed("entryRow") if row.box[1] >= top and row.box[3] <= bottom]


@scenario("7.3", title="a list of 200 scrolls by swipe to its end and back")
def long_list(app: App) -> None:
    d = app.device
    app.start({"organizations": [{"name": "Acme", "spaces": [{"name": "Inbox", "documents": [
        {"title": "Row", "repeat": 200}]}]}]})
    app.open("Acme", "Inbox")
    rows = visible(app)
    expect(rows[0].label == "Row 001", f"the list starts at {rows[0].label}")
    listed = d.dump().get("entryList")
    left = listed.box[0] + listed.width // 3
    for direction, end in ((1, "Row 200"), (-1, "Row 001")):
        first = rows[0].label
        for _ in range(60):
            if any(row.label == end for row in rows):
                break
            low, high = listed.box[3] - listed.height // 6, listed.box[1] + listed.height // 6
            d.swipe((left, low if direction > 0 else high), (left, high if direction > 0 else low))
            rows = visible(app)
            expect((rows[0].label > first) if direction > 0 else (rows[0].label < first),
                   f"a swipe did not move the list past {first}")
            first = rows[0].label
        expect(any(row.label == end for row in rows), f"the swipes never reached {end}")


LONG_NAMES = ["Quarterly planning notes for the whole organization and every team in it.txt",
              "とても長い日本語の文書名はこの行の幅に収まらないので省略されるべきです.txt"]


def elided(app: App, row: Node) -> bool:
    """The title stops before the size column with room to spare: the
    8 dp between them (EntryRow: 16 dp margin, 104 dp size, 8 dp spacing)
    holds no ink, and the title runs up to it."""
    dp = row.height / 48
    image = app.device.screenshot()
    paper = image.pixel(row.box[0] + 2, row.box[1] + 2)
    size_left = row.box[2] - round((16 + 104) * dp)
    title_right = size_left - round(8 * dp)
    band = (row.box[1] + row.height // 4, row.box[3] - row.height // 4)

    def ink(x: int) -> bool:
        return any(not near(image.pixel(x, y), paper, 60) for y in range(*band))
    gap = not any(ink(x) for x in range(title_right + 2, size_left - 2))
    reaches = any(ink(x) for x in range(title_right - round(16 * dp), title_right))
    return gap and reaches


@scenario("7.4", title="long English and Japanese names elide inside their rows")
def long_names(app: App) -> None:
    d = app.device
    app.start({"organizations": [{"name": "Acme", "spaces": [{"name": "Inbox", "documents": [
        {"title": "a.txt"}] + [{"title": name, "content": "x"} for name in LONG_NAMES]}]}]})
    app.open("Acme", "Inbox")
    app.wait_rows(["a.txt", *LONG_NAMES])
    for name in LONG_NAMES:
        expect(elided(app, app.row(name)), f"{name[:12]}… runs past its row")
    title = d.node("locationTitle")
    expect(title.box[2] <= d.screenshot().width, "the location title runs off screen")


@scenario("7.5", title="the launcher icon boots the APK into its saved language, theme, and fonts")
def launcher(app: App) -> None:
    d = app.device
    resolved = d.shell("cmd", "package", "resolve-activity", "--brief", "-a", "android.intent.action.MAIN",
                       "-c", "android.intent.category.LAUNCHER", PACKAGE).split()
    expect(resolved[-1:] == [f"{PACKAGE}/{ACTIVITY}"],
           f"no launcher entry: {resolved}")
    app.start(signed_in=False)
    d.tap("language_ja")
    d.label("submitButton", "サインイン")
    d.tap("themeToggle")
    d.tap(d.label("themeToggle", lambda label: "ライト" in label))
    d.label("themeToggle", lambda label: "ダーク" in label)
    d.stop()

    d.key("KEYCODE_HOME")
    icon = None
    for _ in range(4):
        icon = next((n for n in d.dump().nodes if n.label == "Matome" and n.package != PACKAGE),
                    None)
        if icon:
            break
        width = d.screenshot().width
        d.swipe((width // 2, 1900), (width // 2, 500))
    expect(icon, "Matome is not in the launcher")
    image = d.screenshot()
    art = (icon.box[0], icon.box[1], icon.box[2], icon.box[1] + icon.width)
    expect(count(image, art, DARK["background"], step=1) > 100 and count(image, art, LIGHT["accent"], step=1) > 10,
           "the launcher shows no マ icon (dark tile with the gold fold)")
    d.tap(icon)
    screen = app.launch("submitButton")
    expect(screen.get("submitButton").label == "サインイン", "it did not boot in Japanese")
    d.hide_keyboard()
    app.background(DARK)
    japanese(d, d.dump())
