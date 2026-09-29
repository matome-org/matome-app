"""6 Look and language: themes, pills, motion, the logo, languages, the
device locale, Japanese glyphs, and the empty, loading, and error states."""

from __future__ import annotations

import time

from app import ACME, DARK, EMPTY_FOLDER, LIGHT, SERVER, App, japanese, scenario
from device import ANIMATION_SCALES, Device, Failure, Image, Screen, expect, near


@scenario("6.1", title="the theme cycles from the sign-in toggle and from the account menu")
def theme_cycle(app: App) -> None:
    d = app.device
    app.start(signed_in=False)
    d.label("themeToggle", "Theme: System. Switch theme")
    app.background(LIGHT)
    for mode, colours in (("Light", LIGHT), ("Dark", DARK), ("System", LIGHT)):
        d.tap("themeToggle")
        d.label("themeToggle", f"Theme: {mode}. Switch theme")
        app.background(colours)

    app.sign_in()
    for mode, colours in (("dark", DARK), ("light", LIGHT)):
        app.account(f"theme-{mode}")
        app.background(colours)
        menu = app.button_menu("accountButton")
        checked = [name for name in app.menu_items(menu) if menu.get(f"menu_{name}").checked]
        expect(checked == [f"theme-{mode}", "lang-en"], f"the account menu marks {checked}")
        app.run_item(menu.get(f"menu_theme-{mode}"))


@scenario("6.4", title="buttons are pills and the floating button is round (no Omarchy here)")
def pills(app: App) -> None:
    d = app.device
    screen = app.start(signed_in=False)
    image = d.screenshot()
    submit = screen.get("submitButton")
    left, top, right, bottom = submit.box
    radius = submit.height // 2
    mid = (top + bottom) // 2
    expect(near(image.pixel(left + 2, top + 2), LIGHT["background"]), "the sign-in button has square corners")
    for x in (left + radius // 2, right - radius // 2):
        expect(near(image.pixel(x, mid), LIGHT["accent"]), "the sign-in button's ends are not filled gold")

    app.sign_in()
    fab = d.node("fabButton")
    image = d.screenshot()
    left, top, right, bottom = fab.box
    expect(near(image.pixel(left + 4, top + 4), LIGHT["background"]), "the floating button has corners")
    expect(near(image.pixel(left + fab.width // 8, (top + bottom) // 2), LIGHT["accent"]),
           "the floating button's rim is not gold")


def logo_frames(d: Device) -> list[bytes]:
    """Launches the app and grabs the band the logo lives in (between the
    language bar and the wordmark), frame after frame from the first one
    that is painted until it holds still. Sampling time is the point here:
    frames come as fast as screencap (about 5 a second) and it stops once
    three painted frames in a row match. A first launch shows where things
    sit after a launch."""
    d.stop()
    d.launch()
    screen = d.showing("submitButton")
    wordmark = screen.labelled("Matome")
    band = (0, screen.get("languageSwitcher").box[3], wordmark.box[2], wordmark.box[1])
    reference = d.screenshot()
    left, top, right, bottom = wordmark.box
    ink = next(((x, y) for y in range(top, bottom, 2) for x in range(left, right, 2)
                if near(reference.pixel(x, y), LIGHT["textPrimary"])), None)
    expect(ink is not None, "the wordmark is not painted")
    d.stop()
    d.launch()
    painted: list[bytes] = []
    deadline = time.monotonic() + 15
    while len(painted) < 3 or len(set(painted[-3:])) > 1:
        if time.monotonic() > deadline:
            raise Failure("the logo never held still")
        image: Image = d.screenshot()
        if near(image.pixel(*ink), LIGHT["textPrimary"]):
            painted.append(image.crop(band))
    return painted


@scenario("6.6", title="the logo writes itself when the sign-in form opens")
def logo_writes(app: App) -> None:
    app.start(signed_in=False)
    frames = logo_frames(app.device)
    expect(len(set(frames)) > 2, "the logo did not write itself stroke by stroke")


@scenario("6.5", title="Android's Remove animations shows the logo whole")
def reduced_motion(app: App) -> None:
    d = app.device
    for scale in ANIMATION_SCALES:
        d.setting("global", scale, "0")
    app.start(signed_in=False)
    frames = logo_frames(d)
    expect(len(set(frames)) == 1, "the logo still animates")


def switched(d: Device, code: str, submit: str) -> Screen:
    d.tap(f"language_{code}")
    screen = d.wait(lambda s: s if s.get("submitButton").label == submit else None, f"the form in {code}")
    marks = {n.name for n in screen.nodes if n.name.startswith("language_") and n.checked}
    expect(marks == {f"language_{code}"}, f"the switcher marks {marks}")
    return screen


@scenario("6.7", "6.9", title="PT, EN, and 日本語 switch live, persist, and Japanese renders")
def languages(app: App) -> None:
    d = app.device
    app.start(signed_in=False)
    switched(d, "pt-BR", "Entrar")
    switched(d, "ja", "サインイン")
    screen = switched(d, "en", "Sign in")
    expect(screen.get("emailField").label.startswith("Email"), "the fields stayed in Japanese")
    switched(d, "pt-BR", "Entrar")
    app.sign_in()
    d.label("accountButton", lambda label: label.startswith("Conta"))
    app.account("lang-ja")
    d.label("accountButton", lambda label: label.startswith("アカウント"))

    screen = app.relaunch("submitButton")
    expect(screen.get("submitButton").label == "サインイン", "Japanese was not kept")
    japanese(d, screen)


@scenario("6.8", title="the first language follows the device's, then the saved choice wins")
def device_language(app: App) -> None:
    d = app.device
    for tags, code, submit in (("ja-JP", "ja", "サインイン"), ("pt-BR", "pt-BR", "Entrar"),
                               ("fr-FR", "en", "Sign in")):
        d.stop()
        d.clear()
        d.app_locales(tags)
        screen = app.launch("submitButton")
        expect(screen.get("submitButton").label == submit, f"a {tags} device does not start in {code}")
        expect(screen.get(f"language_{code}").checked, f"a {tags} device does not mark {code}")
    switched(d, "ja", "サインイン")
    screen = app.relaunch("submitButton")
    expect(screen.get("submitButton").label == "サインイン", "the saved language lost to the device's")


@scenario("6.10", title="empty, loading, and error states in the list")
def list_states(app: App) -> None:
    d = app.device
    app.start(ACME)
    app.open("Acme", "Inbox", "Docs", "Deep")
    d.label("emptyState", EMPTY_FOLDER)
    app.core.fail("/documents$", method="GET", mode="hold")
    app.menu(None, "refresh")
    d.label("emptyState", "Loading…")
    app.until_held()
    app.core.release()
    d.label("emptyState", EMPTY_FOLDER)
    app.core.fail("/documents$", method="GET")
    app.menu(None, "refresh")
    d.label("emptyState", SERVER)
    app.menu(None, "refresh")
    d.label("emptyState", EMPTY_FOLDER)
