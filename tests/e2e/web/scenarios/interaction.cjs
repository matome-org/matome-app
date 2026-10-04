// 4 Interaction: selection, menus, focus order, the focus ring, the keymap
// and command sheet, tooltips, and what a screen reader is told.
"use strict";

const assert = require("node:assert/strict");
const { DESKTOP, EMAIL, REGIONS } = require("../lib/constants.cjs");

const SPACE = {
  organizations: [{
    name: "Acme",
    spaces: [{
      name: "Docs",
      folders: [{ name: "Contracts", folders: [{ name: "Signed" }] }],
      documents: [{ title: "Notes", content: "notes" }],
    }],
  }],
};

// Qt's accessibility layer stays off until assistive tech presses its
// first element, a visually hidden "Enable Screen Reader" button.
async function enableScreenReader(page) {
  const enable = page.locator("#qt-shadow-container button.hidden-visually-read-by-screen-reader");
  assert.equal(await enable.textContent(), "Enable Screen Reader");
  await enable.evaluate((button) => button.click());
}

// Every aria-label Qt's accessibility layer has put in the page.
async function labels(page) {
  return new Set(await page.evaluate(() => {
    const root = document.querySelector("#qt-shadow-container").shadowRoot;
    return [...root.querySelectorAll(".qt-window-a11y-container [aria-label]")]
      .map((node) => node.getAttribute("aria-label"));
  }));
}

// Whether a list of shown texts holds every one of `wanted`.
function shows(texts, ...wanted) {
  return wanted.every((text) => texts.includes(text));
}

module.exports = (scenario) => {
  scenario("4.1", "a click selects, a double click opens", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.click(studio.row("Notes"));
    await studio.untilProp(studio.row("Notes"), "selected", true);
    await studio.click(studio.row("Contracts"));
    await studio.untilProp(studio.row("Contracts"), "selected", true);
    assert.equal(await studio.prop(studio.row("Notes"), "selected"), false);
    assert.equal(await studio.here(), "Docs");
    await studio.dblclick(studio.row("Contracts"));
    await studio.untilHere("Contracts");
  });

  // A press would move the browser's focus off Qt's window, and Qt puts it
  // back only when its own focus item changes, which it does not here; the
  // page keeps presses on the studio from moving it.
  scenario("4.1", "a click on the row that already has focus keeps the keyboard", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await studio.select("Contracts");
      await studio.click(studio.row("Contracts"));
      await studio.untilKeyboard();
    });

  scenario("4.3", "the context menu opens by right click, Menu, and Shift+F10, and walks by keys", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await studio.openMenu("Notes");
      // The row's commands under its name, then the folder's under a divider.
      assert.deepEqual(await studio.menuIds(), ["open", "download", "rename", "access", "cut", "trash", "new", "upload", "refresh"]);
      assert.equal(await studio.focusName(), "menu_open");
      await studio.press("Escape");
      await studio.untilShown("contextMenuList", false);
      await studio.untilRegion("entryPane");

      await studio.press("ContextMenu");
      await studio.untilFocus("menu_open");
      await studio.press("ArrowDown");
      await studio.press("ArrowDown");
      await studio.untilProp("contextMenuList", "currentIndex", 3);
      await studio.untilFocus("menu_rename");
      assert.ok(shows(await studio.texts("menu_rename"), "Rename", "F2"));
      await studio.press("Escape");
      await studio.untilShown("contextMenuList", false);

      await studio.press("Shift+F10");
      await studio.pick("rename");
      await studio.untilFocus("rowEditor");
      assert.equal((await studio.focus()).text, "Notes");
      await studio.press("Escape");
      await studio.untilRegion("entryPane");

      const list = await studio.locate("entryList");
      await studio.page.mouse.click(list.x + list.w / 2, list.y + list.h - 20, { button: "right" });
      await studio.untilShown("contextMenuList");
      assert.deepEqual(await studio.menuIds(), ["new", "upload", "refresh"]);
      await studio.press("Escape");
      await studio.untilShown("contextMenuList", false);
    });

  scenario("4.4", "Tab reaches every region; F6 and Shift+F6 cycle them", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.open("Contracts");
    await studio.untilRegion("entryPane");
    const regions = new Set();
    const names = new Set();
    for (let i = 0; i < 40; ++i) {
      regions.add(await studio.region());
      names.add(await studio.focusName());
      await studio.press("Tab");
    }
    for (const region of REGIONS)
      assert.ok(regions.has(region), region);
    for (const name of ["homeLink", "backButton", "upButton", "crumb0", "crumb2", "filterField", "newButton",
      "uploadButton", "accountButton"])
      assert.ok(names.has(name), name);
    assert.ok(!names.has("forwardButton"));

    await studio.click(studio.row("Signed"));
    await studio.untilRegion("entryPane");
    // From the entry pane, F6 wraps to the status bar, then goes round.
    for (const region of [...REGIONS.slice(-1), ...REGIONS.slice(0, -1)]) {
      await studio.press("F6");
      await studio.untilRegion(region);
    }
    await studio.press("Shift+F6");
    await studio.untilRegion("toolbar");
    await studio.press("Control+f");
    await studio.untilFocus("filterField");
    await studio.press("F6");
    await studio.untilRegion("sidebar");
  });

  scenario("4.5", "the focus ring shows for the keyboard only", DESKTOP, async ({ studio }) => {
    const ring = (name) => studio.prop({ name, child: "focusRing" }, "visible");
    await studio.click("registerLink");
    await studio.untilProp("authScreen", "pane", "register");
    assert.equal(await studio.theme("focusVisible"), false);
    await studio.click("passwordField");
    await studio.press("Tab");
    await studio.untilFocus("submitButton");
    assert.equal(await studio.theme("focusVisible"), true);
    assert.equal(await ring("submitButton"), true);
    await studio.press("Shift");
    assert.equal(await studio.theme("focusVisible"), true);

    await studio.click("backToSignIn");
    await studio.untilProp("authScreen", "pane", "signIn");
    assert.equal(await studio.theme("focusVisible"), false);
    await studio.click("themeToggle");
    await studio.untilFocus("themeToggle");
    assert.equal(await ring("themeToggle"), false);
    await studio.press("Shift+Tab");
    await studio.untilFocus("language_ja");
    assert.equal(await studio.theme("focusVisible"), true);
    assert.equal(await ring("language_ja"), true);
    assert.equal(await ring("themeToggle"), false);
  });

  // The browser binds Ctrl+K to its address bar search; the studio takes it
  // (Qt cancels the default for keys it accepts), like ? and :.
  scenario("4.6", "? shows the keymap; :, Ctrl+K open the command sheet", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.press("?");
    await studio.untilShown("keymapSheet");
    assert.equal(await studio.prop("overlayTitle", "text"), "Keys");
    assert.ok((await studio.texts("keymapSheet")).includes("Ctrl+K"));
    await studio.press("a");
    await studio.untilShown("keymapSheet", false);
    await studio.untilRegion("entryPane");
    await studio.press("?");
    await studio.untilShown("keymapSheet");
    await studio.page.mouse.click(4, 400);
    await studio.untilShown("keymapSheet", false);

    await studio.press("Control+k");
    await studio.untilFocus("sheetQuery");
    assert.ok((await studio.texts("commandSheet")).includes("Commands"));
    await studio.press("Escape");
    await studio.untilShown("commandSheet", false);
    await studio.untilRegion("entryPane");

    await studio.runFromSheet("new");
    await studio.untilFocus("rowEditor");
    await studio.press("Escape");
    await studio.untilRegion("entryPane");
  });

  scenario("4.7", "icon buttons show a tooltip with their key, by pointer and by keyboard", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await studio.hover("refreshButton");
      await studio.until(async () => (await studio.shown("toolTip"))
        && shows(await studio.texts("toolTip"), "Refresh", "F5"), "the Refresh tooltip");
      await studio.page.mouse.move(640, 790);
      await studio.untilShown("toolTip", false);

      await studio.press("Shift+F6");
      await studio.untilFocus("newButton");
      await studio.press("Tab");
      await studio.untilFocus("uploadButton");
      await studio.until(async () => (await studio.shown("toolTip"))
        && shows(await studio.texts("toolTip"), "Upload file", "U"), "the Upload tooltip");
      const button = await studio.item("uploadButton");
      assert.deepEqual([button.a11y.name, button.a11y.role], ["Upload file", "Button"]);
    });

  scenario("4.8", "a screen reader hears every button and field by name", DESKTOP,
    async ({ studio, core, page }) => {
      await core.seed(SPACE);
      await enableScreenReader(page);
      await studio.until(async () => (await labels(page)).has("Sign in"), "the sign-in names");
      const signIn = await labels(page);
      for (const name of ["Sign in", "Create account", "Forgot password",
        "Show the Core server address", "Português", "English", "日本語", "Theme: System. Switch theme"])
        assert.ok(signIn.has(name), `${name} in ${[...signIn]}`);
      const email = await studio.item("emailField");
      assert.deepEqual([email.a11y.name, email.a11y.role], ["Email or username", "EditableText"]);

      await studio.enter("Acme", "Docs");
      await studio.until(async () => (await labels(page)).has(`Account, theme, and language: ${EMAIL}`),
        "the explorer names");
      const explorer = await labels(page);
      for (const name of ["Back", "Up one level", "Filter", "New folder", "Upload file", "Download", "Rename",
        "Delete folder", "Refresh"])
        assert.ok(explorer.has(name), `${name} in ${[...explorer]}`);
      const home = await studio.item("homeLink");
      assert.deepEqual([home.a11y.name, home.a11y.role], ["Matome", "Button"]);
      const node = await studio.item(studio.row("Contracts", "treeRow"));
      assert.deepEqual([node.a11y.name, node.a11y.role], ["Contracts, collapsed", "TreeItem"]);
    });

  // Qt's WASM accessibility renders no element for list and tree items, so
  // the rows stay silent in the browser (README, Tests); the mark and the
  // crumbs are buttons, which it does render.
  scenario("4.8", "a screen reader reaches the home mark and the crumbs", DESKTOP,
    async ({ studio, core, page }) => {
      await core.seed(SPACE);
      await enableScreenReader(page);
      await studio.enter("Acme", "Docs");
      await studio.until(async () => (await labels(page)).has("Upload file"), "the explorer names");
      const heard = await labels(page);
      for (const name of ["Matome", "Acme", "Docs"])
        assert.ok(heard.has(name), `${name} in ${[...heard]}`);
    });
};
