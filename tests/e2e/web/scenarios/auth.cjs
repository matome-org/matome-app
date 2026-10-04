// 1 Auth: the sign-in screen and its panes, against FakeCore through the
// page server's proxy.
"use strict";

const assert = require("node:assert/strict");
const { BOTH, DESKTOP, EMAIL, PASSWORD, OWN_ORG, MESSAGES } = require("../lib/constants.cjs");

const MISSING = "Fill every required field.";
const TAKEN = "Use a valid email address with no account yet.";
// Nothing listens on the discard port.
const UNREACHABLE_URL = "http://127.0.0.1:9";

module.exports = (scenario) => {
  scenario("1.1", "sign in by Enter, then by the button", BOTH, async ({ studio, core }) => {
    await studio.signIn();
    assert.equal(await studio.prop("accountButton", "text"), EMAIL);
    assert.equal((await core.state()).user, EMAIL);
    await studio.signOut();

    await studio.fill("passwordField", PASSWORD);
    await studio.activate("submitButton");
    await studio.untilSignedIn();
    assert.deepEqual(await studio.names(), [OWN_ORG]);
  });

  scenario("1.2", "a wrong password says so and marks both fields", BOTH, async ({ studio, core }) => {
    await studio.useServer();
    await studio.submit({ password: "wrong" });
    await studio.untilProp("statusMessage", "text", MESSAGES.wrongPassword);
    assert.equal(await studio.session("signedIn"), false);
    assert.equal(await studio.prop("emailField", "invalid"), true);
    assert.equal(await studio.prop("passwordField", "invalid"), true);
    assert.equal(await studio.prop("statusMessage", "color"), await studio.theme("failed"));
    assert.equal((await core.state()).user, "");
  });

  scenario("1.3", "an unreachable Core is a network error and opens Server", BOTH, async ({ studio }) => {
    await studio.useServer(UNREACHABLE_URL);
    await studio.activate("serverToggle");
    await studio.untilShown("apiField", false);
    await studio.submit();
    await studio.untilProp("statusMessage", "text", MESSAGES.unreachable);
    await studio.untilShown("apiField");
    assert.equal(await studio.prop("emailField", "invalid"), false);
    assert.equal(await studio.session("signedIn"), false);
  });

  scenario("1.4", "empty fields name what is missing on every pane", DESKTOP, async ({ studio, core }) => {
    await studio.useServer();
    await studio.fill("emailField", "");
    await studio.fill("passwordField", "");
    await studio.press("Enter");
    await studio.untilProp("statusMessage", "text", MISSING);
    assert.equal(await studio.prop("emailField", "invalid"), true);
    assert.equal(await studio.prop("passwordField", "invalid"), true);

    await studio.fill("emailField", "new@localhost");
    await studio.press("Enter");
    await studio.untilProp("emailField", "invalid", false);
    assert.equal(await studio.prop("passwordField", "invalid"), true);
    assert.equal(await studio.prop("emailField", "text"), "new@localhost");

    await studio.click("registerLink");
    await studio.click("submitButton");
    await studio.untilProp("statusMessage", "text", MISSING);
    assert.equal(await studio.prop("passwordField", "invalid"), true);

    await studio.press("Escape");
    await studio.click("forgotLink");
    await studio.fill("emailField", "");
    await studio.press("Enter");
    await studio.untilProp("emailField", "invalid", true);

    assert.equal(await studio.prop("statusMessage", "text"), MISSING);
    assert.equal((await core.state()).hits, 0);
  });

  scenario("1.5", "create and confirm an account; a taken email is refused", DESKTOP, async ({ studio, core }) => {
    await studio.useServer();
    await studio.click("registerLink");
    await studio.untilProp("paneTitle", "text", "Create account");
    await studio.submit({ email: EMAIL });
    await studio.untilProp("statusMessage", "text", TAKEN);
    assert.equal(await studio.session("signedIn"), false);
    assert.equal(await studio.prop("statusMessage", "color"), await studio.theme("failed"));
    assert.equal(await studio.prop("emailField", "invalid"), true);
    assert.equal(await studio.prop("passwordField", "invalid"), false);

    await studio.fill("emailField", "new@localhost");
    await studio.press("Enter");
    await studio.untilProp("authScreen", "pane", "confirm");
    assert.equal(await studio.session("signedIn"), false);
    await studio.click("backToSignIn");
    await studio.untilProp("authScreen", "pane", "signIn");
    await studio.submit({ email: "new@localhost" });
    await studio.untilProp("authScreen", "pane", "confirm");
    await studio.click("resendConfirmation");
    await studio.untilProp("statusMessage", "text",
      "A new confirmation link was sent to new@localhost. Open it in your browser, then return to sign in.");
    await core.confirmEmail("new@localhost");
    await studio.click("backToSignIn");
    await studio.submit({ email: "new@localhost" });
    await studio.untilSignedIn();
    assert.ok((await core.state()).users.includes("new@localhost"));
    assert.equal(await studio.prop("accountButton", "text"), "new@localhost");
  });

  scenario("1.6", "forgot, browser reset, then sign in with the new password", DESKTOP, async ({ studio, core }) => {
    await studio.useServer();
    await studio.click("forgotLink");
    await studio.untilProp("paneTitle", "text", "Forgot password");
    assert.equal(await studio.shown("passwordField"), false);
    await studio.fill("emailField", EMAIL);
    await studio.press("Enter");
    await studio.untilProp("statusMessage", "text",
      "If that account exists, a password reset link was sent. Open it in your browser, then sign in with your new password.");

    await core.resetPassword(EMAIL, "fresh-pass1");
    await studio.click("backToSignIn");
    await studio.signInAgain("fresh-pass1");

    await studio.signOut();
    await studio.signInAgain("fresh-pass1");
  });

  scenario("1.7", "Esc and Back return to sign in from every pane", DESKTOP, async ({ studio }) => {
    for (const [link, title] of [["registerLink", "Create account"], ["forgotLink", "Forgot password"]]) {
      await studio.click(link);
      await studio.untilProp("paneTitle", "text", title);
      await studio.press("Escape");
      await studio.untilProp("authScreen", "pane", "signIn");
      assert.equal(await studio.focusName(), "emailField");

      await studio.click(link);
      await studio.untilProp("paneTitle", "text", title);
      await studio.click("backToSignIn");
      await studio.untilProp("authScreen", "pane", "signIn");
    }
  });

  scenario("1.8", "the Server disclosure changes the Core address", DESKTOP, async ({ studio, stack, core }) => {
    assert.equal(await studio.shown("apiField"), false);
    assert.equal(await studio.prop("apiField", "text"), process.env.MATOME_TEST_DEFAULT_SERVER);
    await studio.click("serverToggle");
    await studio.untilShown("apiField");
    await studio.press("Tab");
    await studio.untilFocus("apiField");
    await studio.press("Shift+Tab");
    await studio.untilFocus("serverToggle");
    await studio.press("Enter");
    await studio.untilShown("apiField", false);
    await studio.press("Space");
    await studio.untilShown("apiField");

    await studio.signIn();
    assert.equal(await studio.session("apiBaseUrl"), stack.webUrl);
    assert.ok((await core.state()).hits > 0);
  });

  scenario("1.9", "sign out from the account menu and the command sheet", BOTH, async ({ studio }) => {
    await studio.signIn();
    await studio.activate("accountButton");
    await studio.untilShown("contextMenuList");
    await studio.press("End");
    await studio.untilFocus("menu_sign-out");
    await studio.press("Enter");
    await studio.untilShown("authScreen");
    await studio.untilFocus("emailField");
    assert.equal(await studio.prop("emailField", "text"), EMAIL);
    assert.equal(await studio.prop("apiField", "text"), studio.stack.webUrl);

    await studio.signInAgain();
    await studio.signOut();
    await studio.untilFocus("emailField");
    assert.equal(await studio.session("signedIn"), false);
  });

  scenario("1.9", "signing out by mouse leaves focus in the email field", DESKTOP, async ({ studio }) => {
    await studio.signIn();
    await studio.click("accountButton");
    await studio.untilShown("contextMenuList");
    await studio.click("menu_sign-out");
    await studio.untilShown("authScreen");
    await studio.untilFocus("emailField");
  });

  scenario("1.10", "an expired token refreshes quietly; a refused refresh ends the session", DESKTOP,
    async ({ studio, core }) => {
      await core.seed({ organizations: [{ name: "Acme", spaces: [{ name: "Docs" }] }] });
      await studio.signIn();
      const orgs = "^/api/v1/organizations$";
      await core.fail({ method: "GET", path: orgs, mode: "expire" });
      await core.seed({ organizations: [{ name: "Guests" }] });
      await studio.press("F5");
      await studio.untilNames(["Acme", OWN_ORG, "Guests"]);
      assert.equal(await studio.session("signedIn"), true);
      assert.equal(await studio.statusText(), "");
      assert.deepEqual((await core.state()).faults, []);

      await studio.open("Acme");
      const spaces = "^/api/v1/organizations/[^/]+/spaces$";
      await core.fail({ method: "GET", path: spaces, mode: "expire" });
      await core.fail({ method: "POST", path: "^/api/auth/refresh$", status: 401, error: "invalid_refresh_token" });
      await studio.press("Control+r");
      await studio.untilShown("authScreen");
      await studio.untilProp("statusMessage", "text", "Your session ended. Sign in again.");
      assert.equal(await studio.prop("emailField", "invalid"), false);
      await studio.untilFocus("emailField");
      await studio.signInAgain();
      await studio.untilHere("Acme");
    });

  scenario("1.11", "a reload remembers email, server, organization, theme, and language", DESKTOP,
    async ({ studio, core, stack, page }) => {
      await core.seed({ organizations: [{ name: "Acme", spaces: [{ name: "Docs" }] }] });
      await studio.enter("Acme");
      await studio.click("accountButton");
      await studio.pick("theme-dark");
      await studio.click("accountButton");
      await studio.pick("lang-ja");
      await studio.untilProp("locationEyebrow", "text", "組織");
      const saved = Object.keys(await page.evaluate(() => ({ ...localStorage })));
      for (const key of ["session/identifier", "session/apiBaseUrl", "session/lastOrgId", "theme/mode", "theme/language"])
        assert.ok(saved.some((name) => name.endsWith(key)), `${key} in ${saved}`);

      await studio.reload();
      assert.equal(await studio.theme("mode"), "dark");
      assert.equal(await studio.theme("dark"), true);
      assert.equal(await studio.theme("language"), "ja");
      assert.equal(await studio.prop("emailField", "text"), EMAIL);
      assert.equal(await studio.prop("apiField", "text"), stack.webUrl);
      assert.equal(await studio.prop("submitButton", "text"), "サインイン");
      await studio.signInAgain();
      await studio.untilHere("Acme");
    });

  scenario("1.12", "an accepted browser invitation appears after refreshing organizations", BOTH,
    async ({ studio, core }) => {
      await studio.signIn();
      assert.deepEqual(await studio.names(), [OWN_ORG]);
      await core.acceptInvitation(EMAIL, "Invited");
      await studio.press("F5");
      await studio.until(async () => (await studio.names()).includes("Invited"), "the accepted invitation");
    });
};
