// 2 Navigation: organizations, spaces, and folders by pointer, touch, and
// keyboard, and where the explorer says it is.
"use strict";

const assert = require("node:assert/strict");
const { BOTH, DESKTOP, OWN_ORG } = require("../lib/constants.cjs");

// Acme › Docs holds Archive (with Old inside) and Contracts; Acme also has
// Media, and the user owns a second organization, Beta.
const TREE = {
  organizations: [
    {
      name: "Acme",
      spaces: [
        { name: "Docs", folders: [{ name: "Archive", folders: [{ name: "Old" }] }, { name: "Contracts" }] },
        { name: "Media" },
      ],
    },
    { name: "Beta", spaces: [{ name: "Plans" }] },
  ],
};

module.exports = (scenario) => {
  scenario("2.1", "organizations, spaces, then folders open by pointer and by Enter", BOTH,
    async ({ studio, core }) => {
      await core.seed(TREE);
      await studio.signIn();
      assert.deepEqual(await studio.names(), ["Acme", "Beta", OWN_ORG]);
      await studio.open("Acme");
      assert.equal(await studio.level(), "spaces");
      assert.deepEqual(await studio.names(), ["Docs", "Media"]);
      await studio.open("Docs");
      assert.equal(await studio.level(), "files");
      assert.deepEqual(await studio.names(), ["Archive", "Contracts"]);
      await studio.open("Archive");
      assert.deepEqual(await studio.names(), ["Old"]);

      await studio.press("Backspace");
      await studio.untilHere("Docs");
      await studio.untilFocus("entryRow0");
      await studio.press("ArrowDown");
      await studio.untilFocus("entryRow1");
      await studio.press("Enter");
      await studio.untilHere("Contracts");
    });

  scenario("2.2", "N and the toolbar create an organization, a space, and a folder inline and enter it", DESKTOP,
    async ({ studio, core }) => {
      await studio.signIn();
      await studio.press("n");
      await studio.untilFocus("rowEditor");
      await studio.type("Guild");
      await studio.press("Enter");
      await studio.untilHere("Guild");
      assert.ok((await core.state()).organizations.some((org) => org.name === "Guild"));
      assert.equal(await studio.prop("newButton", "text"), "New space");

      await studio.click("newButton");
      await studio.untilFocus("newSpaceName");
      await studio.type("Inbox");
      await studio.press("Enter");
      await studio.untilLevel("files");
      await studio.untilHere("Inbox");
      assert.ok((await core.state()).spaces.some((space) => space.name === "Inbox" && space.visibility === "private"));

      // A folder is created once the new space's level has loaded.
      await studio.untilIdle();
      await studio.press("n");
      await studio.untilFocus("rowEditor");
      await studio.type("Contracts");
      await studio.press("Enter");
      await studio.untilNames(["Contracts"]);
      await studio.untilFocus("entryRow0");
      await studio.click("newButton");
      await studio.untilFocus("rowEditor");
      await studio.type("Dropped");
      await studio.press("Escape");
      await studio.untilRegion("entryPane");
      const { folders } = await core.state();
      assert.deepEqual(folders.map((folder) => folder.name), ["Contracts"]);
    });

  scenario("2.3", "breadcrumb crumbs open their location", DESKTOP, async ({ studio, core }) => {
    await core.seed(TREE);
    await studio.enter("Acme", "Docs");
    await studio.open("Archive");
    await studio.open("Old");
    assert.deepEqual((await studio.session("trail")).map((crumb) => crumb.name).slice(1),
      ["Acme", "Docs", "Archive", "Old"]);
    await studio.click("crumb2");
    await studio.untilHere("Archive");
    await studio.click("crumb1");
    await studio.untilHere("Docs");
    await studio.click("crumb0");
    await studio.untilHere("Acme");
    assert.equal(await studio.level(), "spaces");
    await studio.untilShown("crumb1", false);
  });

  scenario("2.4", "the マ mark goes home", BOTH, async ({ studio, core }) => {
    await core.seed(TREE);
    await studio.enter("Acme", "Docs");
    await studio.activate("homeLink");
    await studio.untilLevel("orgs");
    await studio.untilShown("crumb0", false);
    assert.equal(await studio.prop("locationTitle", "text"), "Matome");
  });

  scenario("2.5", "back, forward, and up by button and key", DESKTOP, async ({ studio, core }) => {
    await core.seed(TREE);
    await studio.enter("Acme", "Docs");
    await studio.open("Archive");
    assert.equal(await studio.prop("forwardButton", "usable"), false);

    await studio.click("backButton");
    await studio.untilHere("Docs");
    await studio.click("forwardButton");
    await studio.untilHere("Archive");
    await studio.click("upButton");
    await studio.untilHere("Docs");

    await studio.press("Alt+ArrowLeft");
    await studio.untilHere("Archive");
    await studio.press("Alt+ArrowRight");
    await studio.untilHere("Docs");
    await studio.open("Archive");
    await studio.press("Alt+ArrowUp");
    await studio.untilHere("Docs");
    await studio.open("Archive");
    await studio.press("Backspace");
    await studio.untilHere("Docs");
    await studio.press("Escape");
    await studio.untilHere("Acme");
    await studio.press("Escape");
    await studio.untilLevel("orgs");
    assert.equal(await studio.page.url(), `${studio.stack.webUrl}/`);
  });

  scenario("2.6", "the folder tree expands, collapses, and opens by pointer and arrows", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(TREE);
      await studio.enter("Acme", "Docs");
      const archive = studio.row("Archive", "treeRow");
      await studio.untilProp(archive, "expandable", true);
      const old = studio.row("Old", "treeRow");
      assert.equal(await studio.prop(archive, "expanded"), false);
      await studio.click({ ...archive, child: "disclosure" });
      await studio.untilProp(archive, "expanded", true);
      await studio.untilShown(old);
      await studio.untilIdle();
      await studio.click({ ...archive, child: "disclosure" });
      await studio.untilProp(archive, "expanded", false);
      await studio.untilShown(old, false);
      assert.equal(await studio.here(), "Docs");

      await studio.click(archive);
      await studio.untilHere("Archive");
      await studio.untilIdle();
      await studio.untilProp(archive, "expanded", true);
      await studio.untilShown(old);
      await studio.untilRegion("sidebar");

      await studio.press("Home");
      await studio.press("ArrowDown");
      await studio.untilFocus("treeRow1");
      await studio.press("ArrowLeft");
      await studio.untilProp(archive, "expanded", false);
      await studio.untilShown(old, false);
      await studio.press("ArrowRight");
      await studio.untilProp(archive, "expanded", true);
      await studio.press("ArrowRight");
      await studio.untilFocus("treeRow2");
      await studio.press("Enter");
      await studio.untilHere("Old");
      await studio.press("ArrowLeft");
      await studio.untilFocus("treeRow1");
    });

  scenario("2.7", "the sidebar switches organization and space", DESKTOP, async ({ studio, core }) => {
    await core.seed(TREE);
    await studio.enter("Acme", "Docs");
    await studio.click(studio.row("Media", "spaceRow"));
    await studio.untilHere("Media");
    assert.equal(await studio.prop(studio.row("Media", "treeRow"), "selected"), true);
    await studio.click(studio.row("Beta", "orgRow"));
    await studio.untilHere("Beta");
    await studio.untilNames(["Plans"]);
    await studio.click(studio.row("Plans", "spaceRow"));
    await studio.untilHere("Plans");
    assert.equal(await studio.prop(studio.row("Beta", "orgRow"), "along"), true);
  });

  scenario("2.8", "Ctrl+F filters, says when nothing matches, and Esc clears then leaves", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(TREE);
      await studio.enter("Acme", "Docs");
      await studio.press("Control+f");
      await studio.untilFocus("filterField");
      await studio.type("arch");
      await studio.untilNames(["Archive"]);
      await studio.type("zz");
      await studio.untilNames([]);
      await studio.untilProp("emptyText", "text", "Nothing here matches “archzz”.");
      await studio.press("Escape");
      await studio.untilSession("filter", "");
      await studio.untilNames(["Archive", "Contracts"]);
      assert.equal(await studio.focusName(), "filterField");
      await studio.press("Escape");
      await studio.untilRegion("entryPane");
    });

  // The browser binds F5 and Ctrl+R to reload the page. The studio takes
  // both (it accepts the keys, so Qt cancels the browser's default): they
  // re-read the open level from Core and the page stays loaded, signed in.
  scenario("2.9", "F5, Ctrl+R, and the button refresh the level without reloading the page", DESKTOP,
    async ({ studio, core, page }) => {
      await core.seed({ organizations: [{ name: "Acme", spaces: [{ name: "Docs" }] }] });
      await studio.signIn();
      await page.evaluate(() => { window.stillLoaded = true; });
      await core.seed({ organizations: [{ name: "Guests" }] });
      await studio.press("F5");
      await studio.untilListed("Guests");

      await studio.open("Acme");
      await core.seed({ organizations: [{ name: "Later" }] });
      const before = (await core.state()).hits;
      await studio.press("Control+r");
      await studio.until(async () => (await core.state()).hits > before, "a spaces reload after Ctrl+R");
      await studio.untilIdle();

      await studio.open("Docs");
      const hits = (await core.state()).hits;
      await studio.click("refreshButton");
      await studio.until(async () => (await core.state()).hits > hits, "a files reload after the button");
      await studio.untilIdle();
      assert.equal(await page.evaluate(() => window.stillLoaded), true);
      assert.equal(await studio.session("signedIn"), true);

      await studio.press("Control+f");
      await studio.untilFocus("filterField");
      const typed = (await core.state()).hits;
      await studio.press("F5");
      await studio.until(async () => (await core.state()).hits > typed, "F5 from the filter");
      assert.equal(await studio.focusName(), "filterField");
    });

  scenario("2.10", "the location header names each level", BOTH, async ({ studio, core }) => {
    await core.seed(TREE);
    await studio.signIn();
    const header = async () => [await studio.prop("locationEyebrow", "text"),
      await studio.prop("locationTitle", "text"), await studio.prop("itemCount", "text")];
    await studio.untilEqual(header, ["Organizations", "Matome", "3 items"], "the root header");
    await studio.open("Acme");
    await studio.untilEqual(header, ["Organization", "Acme", "2 items"], "the organization header");
    await studio.open("Docs");
    await studio.untilEqual(header, ["Space · Acme", "Docs", "2 items"], "the space header");
    await studio.open("Archive");
    await studio.untilEqual(header, ["Folder · Docs", "Archive", "1 item"], "the folder header");
    const title = await studio.prop("locationTitle", "font");
    assert.equal(title.family, (await studio.theme(studio.touch ? "heading" : "title")).family);
  });
};
