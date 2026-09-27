// 5 Responsive: the phone profile. The sidebar is a drawer, the toolbar a
// floating button, rows are touch height, and a long press is a right click.
"use strict";

const assert = require("node:assert/strict");
const { sha256 } = require("../lib/core.cjs");

const MOBILE = ["mobile"];

const SPACE = {
  organizations: [{
    name: "Acme",
    spaces: [{ name: "Docs", folders: [{ name: "Contracts" }], documents: [{ title: "Notes", content: "notes" }] }],
  }],
};

async function drawerOpen(studio) {
  await studio.tap("drawerButton");
  await studio.untilProp("sidebar", "x", 0);
  await studio.untilRegion("sidebar");
}

module.exports = (scenario) => {
  scenario("5.1", "the drawer opens by its button and closes by scrim, Esc, and navigating", MOBILE,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      assert.equal(await studio.shown("sidebar"), false);
      assert.equal(await studio.shown("toolbar"), false);
      assert.equal(await studio.shown("fabButton"), true);

      await drawerOpen(studio);
      assert.equal(await studio.shown("drawerScrim"), true);
      await studio.press("Escape");
      await studio.untilShown("sidebar", false);
      await studio.untilRegion("entryPane");
      assert.equal(await studio.level(), "files");

      await drawerOpen(studio);
      await studio.tap("drawerScrim", 0.95, 0.5);
      await studio.untilShown("sidebar", false);

      await drawerOpen(studio);
      await studio.tap(studio.row("Contracts", "treeRow"));
      await studio.untilHere("Contracts");
      await studio.untilShown("sidebar", false);
    });

  scenario("5.2", "the floating button offers New, Upload, and Paste", MOBILE, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.loadWithInputPicker();
    await studio.enter("Acme", "Docs");
    await studio.tap("fabButton");
    await studio.untilShown("contextMenuList");
    assert.deepEqual(await studio.menuIds(), ["new", "upload"]);
    await studio.pick("new");
    await studio.untilFocus("rowEditor");
    await studio.type("Drafts");
    await studio.press("Enter");
    await studio.untilNames(["Contracts", "Drafts", "Notes"]);
    await studio.untilProp(studio.row("Drafts"), "height", 48);

    const photo = Buffer.from("not really a jpeg");
    await studio.pickFiles(() => studio.fab("upload"), [{ name: "photo.jpg", buffer: photo }]);
    await studio.untilListed("photo.jpg");
    await studio.untilSession("uploadBusy", false);
    assert.equal((await core.document("photo.jpg")).content_sha256, sha256(photo));

    await studio.openMenu("Notes");
    await studio.pick("cut");
    await studio.open("Drafts");
    await studio.tap("fabButton");
    await studio.untilShown("contextMenuList");
    assert.deepEqual(await studio.menuIds(), ["new", "upload", "paste"]);
    await studio.pick("paste");
    await studio.untilNames(["Notes"]);
  }, { load: false });

  scenario("5.3", "a tap opens, a long press asks for the menu without opening", MOBILE, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    assert.equal((await studio.prop("locationTitle", "font")).pixelSize,
      (await studio.theme("heading")).pixelSize);
    await studio.openMenu("Contracts");
    assert.equal(await studio.here(), "Docs");
    assert.ok((await studio.menuIds()).includes("rename"));
    await studio.press("Escape");
    await studio.untilShown("contextMenuList", false);
    await studio.tap(studio.row("Contracts"));
    await studio.untilHere("Contracts");

    await studio.tap("filterButton");
    await studio.untilFocus("filterField");
    assert.equal(await studio.shown("breadcrumb"), false);
    await studio.press("Escape");
    await studio.untilShown("breadcrumb");
    assert.equal(await studio.here(), "Contracts");
  });
};
