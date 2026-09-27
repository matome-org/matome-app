"""1 Auth: sign in, errors, accounts, passwords, panes, server, session."""

from __future__ import annotations

import socket
import os
from urllib.parse import urlsplit

from app import (
    ACME,
    DARK,
    EMAIL,
    LIGHT,
    ORGS,
    OWN_ORG,
    PASSWORD,
    UNREACHABLE,
    App,
    count,
    scenario,
)
from device import Image, Node, expect

MISSING = "Fill every required field."
TAKEN = "Use a valid email address with no account yet."
SENT = "If that account exists, a password reset link was sent. Open it in your browser, then sign in with your new password."


def closed_port() -> int:
    """A loopback port nothing listens on."""
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def underlined(image: Image, field: Node, colour: tuple[int, int, int]) -> bool:
    """The hairline under a form field is drawn in `colour`."""
    left, _, right, bottom = field.box
    return count(image, (left, bottom - 5, right, bottom), colour, step=1) > field.width // 2


def fields_marked(app: App) -> None:
    """Both sign-in fields are underlined in the theme's `failed`."""
    screen, image = app.device.dump(), app.device.screenshot()
    for name in ("emailField", "passwordField"):
        expect(underlined(image, screen.get(name), LIGHT["failed"]), f"#{name} is not marked invalid")


def back_in_acme(app: App) -> None:
    """Signs in again from a form that kept the email and server, and lands
    in Acme."""
    app.form({"passwordField": PASSWORD})
    app.device.enter()
    app.here("Acme")


@scenario("1.1", "1.9", title="sign in by tap and by Enter, sign out from the account menu")
def sign_in_and_out(app: App) -> None:
    d = app.device
    app.start(ACME, signed_in=False)
    app.form({"passwordField": PASSWORD, "emailField": EMAIL})
    d.tap("submitButton")
    app.wait_rows(ORGS)
    expect(app.core.state()["user"] == EMAIL, "Core did not sign ok@localhost in")

    app.account("sign-out")
    screen = d.showing("submitButton")
    expect(screen.get("emailField").text == EMAIL, "the email is not remembered after signing out")
    expect(screen.get("passwordField").text == "", "the password survived signing out")

    app.sign_in()
    app.wait_rows(ORGS)


@scenario("1.2", title="a wrong password says so and marks the fields")
def wrong_password(app: App) -> None:
    d = app.device
    app.start(signed_in=False)
    app.form({"passwordField": "not-it", "emailField": EMAIL})
    d.enter()
    d.label("statusMessage", "That email or password is wrong.")
    fields_marked(app)

    app.sign_in()
    d.gone("statusMessage")


@scenario("1.3", "1.8", title="an unreachable Core opens the server field; a new URL signs in")
def unreachable_core(app: App) -> None:
    d = app.device
    screen = app.open_server(app.fresh())
    expect(screen.get("apiField").text == os.environ["MATOME_TEST_DEFAULT_SERVER"], "the default Core URL changed")
    app.core.reset()
    test_host = urlsplit(app.core.emulator_url).hostname
    screen = app.form({"apiField": f"http://{test_host}:{closed_port()}", "passwordField": PASSWORD,
                       "emailField": EMAIL})
    d.tap(screen.get("serverToggle"))
    d.gone("apiField")
    d.tap("submitButton")
    d.label("statusMessage", UNREACHABLE)
    d.node("apiField")

    app.sign_in(apiField=app.core.emulator_url)
    expect(app.core.state()["user"] == EMAIL, "the new Core URL was not used")


@scenario("1.4", title="empty fields say what is missing in every pane, and nothing is sent")
def empty_fields(app: App) -> None:
    d = app.device
    app.start(signed_in=False)
    app.form({"emailField": "", "passwordField": ""})
    d.enter()
    d.label("statusMessage", MISSING)
    fields_marked(app)

    for link, submit in (("registerLink", "Create account"), ("forgotLink", "Send reset")):
        app.pane(link)
        d.tap(d.label("submitButton", submit))
        d.label("statusMessage", MISSING)
    expect(app.core.state()["hits"] == 0, "an empty form reached Core")


@scenario("1.5", title="create and confirm an account, and a taken email is refused")
def create_account(app: App) -> None:
    d = app.device
    app.start(signed_in=False)
    d.tap("registerLink")
    d.label("submitButton", "Create account")
    app.form({"emailField": EMAIL, "passwordField": "secret99"})
    d.tap("submitButton")
    d.label("statusMessage", TAKEN)
    expect(app.core.state()["user"] != EMAIL, "a taken email signed in")

    app.form({"emailField": "new@localhost", "passwordField": "secret99"})
    d.enter()
    d.label("statusMessage", "Open the confirmation link sent to new@localhost in your browser, then return to sign in.")
    d.gone("homeLink")
    app.core.confirm_email("new@localhost")
    d.tap("backToSignIn")
    app.form({"passwordField": "secret99"})
    d.enter()
    app.wait_rows(["new organization"])
    state = app.core.state()
    expect("new@localhost" in state["users"] and state["user"] == "new@localhost",
           "the account was not created")


@scenario("1.6", title="forgot password, then browser reset allows sign-in")
def forgot_and_reset(app: App) -> None:
    d = app.device
    app.start(signed_in=False)
    d.tap("forgotLink")
    d.label("submitButton", "Send reset")
    expect("passwordField" not in d.dump(), "the forgot pane asks for a password")
    app.form({"emailField": EMAIL})
    d.enter()
    d.label("statusMessage", SENT)

    app.core.reset_password(EMAIL, "secret34")
    d.tap("backToSignIn")
    app.form({"passwordField": "secret34"})
    d.enter()
    app.wait_rows([OWN_ORG])


@scenario("1.7", title="back from each pane by its link and by Android Back")
def back_from_panes(app: App) -> None:
    d = app.device
    app.start(signed_in=False)
    for link, field in (("registerLink", "emailField"), ("forgotLink", "emailField")):
        d.tap(link)
        d.node(field)
        d.tap("backToSignIn")
        d.label("submitButton", "Sign in")
        d.gone("backToSignIn")

    for link in ("registerLink", "forgotLink"):
        d.tap(link)
        d.node("backToSignIn")
        d.back()
        d.label("submitButton", "Sign in")
        d.gone("backToSignIn")
    # On the sign-in pane Back is Android's own: the app leaves, without a crash.
    d.back()
    d.gone("submitButton")


@scenario("1.10", title="an expired token refreshes mid-use; a refused refresh ends the session")
def expired_token(app: App) -> None:
    d = app.device
    app.start(ACME)
    app.open("Acme")
    spaces = "^/api/v1/organizations/[^/]+/spaces$"
    app.core.fail(spaces, method="GET", mode="expire")
    app.menu("Inbox", "refresh")
    d.wait(lambda s: s if not app.core.state()["faults"] else None, "the expired request")
    app.here("Acme")
    screen = d.dump()
    expect(app.rows(screen) == ["Inbox"] and "homeLink" in screen, "the refresh lost the session")

    app.core.fail(spaces, method="GET", mode="expire")
    app.core.fail("^/api/auth/refresh$", method="POST", status=401, error="invalid_refresh_token")
    app.menu("Inbox", "refresh")
    d.label("statusMessage", "Your session ended. Sign in again.")
    screen = d.dump()
    expect(screen.get("emailField").text == EMAIL, "the email was forgotten with the session")
    back_in_acme(app)


@scenario("1.11", title="a relaunch remembers email, server, last org, theme, and language")
def relaunch_remembers(app: App) -> None:
    d = app.device
    app.start(ACME)
    app.open("Acme")
    app.account("theme-dark")
    app.account("lang-ja")
    d.label("accountButton", lambda label: label.startswith("アカウント"))

    screen = app.relaunch("submitButton")
    expect(screen.get("submitButton").label == "サインイン", "the language was not kept")
    expect(screen.get("language_ja").checked, "the switcher does not mark 日本語")
    expect(screen.get("themeToggle").label.startswith("テーマ：ダーク"), "the theme was not kept")
    expect(screen.get("emailField").text == EMAIL, "the email was not kept")
    app.background(DARK)
    screen = app.open_server(screen)
    expect(screen.get("apiField").text == app.core.emulator_url, "the server was not kept")
    back_in_acme(app)


@scenario("1.12", title="an invitation accepted in the browser appears after refresh")
def accepted_invitation(app: App) -> None:
    app.start()
    app.wait_rows([OWN_ORG])
    app.core.accept_invitation(EMAIL, "Invited")
    app.menu(None, "refresh")
    app.wait_rows([OWN_ORG, "Invited"])
