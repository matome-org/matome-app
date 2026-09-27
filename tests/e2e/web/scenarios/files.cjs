// 3 Files: uploads through the browser, downloads, and every edit of a
// space's folders and documents, checked in the UI and in Core's state.
"use strict";

const assert = require("node:assert/strict");
const { sha256 } = require("../lib/core.cjs");
const { BOTH, DESKTOP, MESSAGES } = require("../lib/constants.cjs");

const SPACE = {
  organizations: [{
    name: "Acme",
    spaces: [{
      name: "Docs",
      folders: [{ name: "Archive" }, { name: "Contracts" }],
      documents: [{ title: "Notes", content: "notes body" }, { title: "Budget", content: "budget body" }],
    }],
  }],
};

const BINARY = Buffer.from([0x00, 0x01, 0x62, 0x69, 0x6e, 0xff, 0xfe, 0x00, 0x7f]);
const CYCLE = "A folder cannot move into itself.";
const TWO_FILES = [{ name: "a.txt", buffer: Buffer.from("aaaa") }, { name: "b.txt", buffer: Buffer.from("bbbb") }];

// Selects `title`, trashes it with Del, and waits until Core holds it in
// the trash and the list no longer shows it.
async function trash(studio, core, title) {
  await studio.select(title);
  const before = (await core.state()).trash.length;
  await studio.press("Delete");
  await studio.untilListed(title, false);
  await studio.until(async () => (await core.state()).trash.length === before + 1, `${title} in the trash`);
  await studio.untilIdle();
}

async function landed(core, title) {
  return (await core.document(title) || {}).content_sha256;
}

module.exports = (scenario) => {
  scenario("3.1", "U opens the browser picker and uploads the file's exact bytes", BOTH,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.loadWithInputPicker();
      await studio.enter("Acme", "Docs");
      const trigger = studio.touch
        ? () => studio.fab("upload")
        : () => studio.press("u");
      await studio.pickFiles(trigger, [{ name: "scan.bin", buffer: BINARY }]);
      await studio.untilListed("scan.bin");
      await studio.untilSession("uploadBusy", false);
      const doc = await core.document("scan.bin");
      assert.equal(doc.content_sha256, sha256(BINARY));
      assert.equal(doc.content_size, BINARY.length);
      assert.equal(await studio.statusText(), "");
    }, { load: false });

  scenario("3.1", "in Chromium U asks the native picker for many files under the key's activation", DESKTOP,
    async ({ studio, core, page }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await page.evaluate(() => {
        window.picks = [];
        const native = window.showOpenFilePicker;
        window.showOpenFilePicker = function (options) {
          window.picks.push({ options, activation: navigator.userActivation.isActive });
          return native.call(this, options);
        };
      });
      await studio.press("u");
      const [pick] = await studio.until(() => page.evaluate(() => window.picks.length && window.picks),
        "the native picker");
      assert.deepEqual(pick, { options: { multiple: true }, activation: true });
      // Headless Chromium answers the picker as a cancel: nothing uploads, nothing fails.
      await studio.untilIdle();
      assert.equal(await studio.statusText(), "");
      assert.equal((await core.state()).documents.length, 2);
    });

  scenario("3.2", "the upload button takes several files at once, into the open folder", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.loadWithInputPicker();
      await studio.enter("Acme", "Docs");
      await studio.open("Contracts");
      const files = [
        { name: "q1.txt", buffer: Buffer.from("first quarter") },
        { name: "q2.txt", buffer: Buffer.from("second quarter") },
        { name: "日本語.txt", buffer: Buffer.from("三番目") },
      ];
      await studio.pickFiles(() => studio.click("uploadButton"), files);
      await studio.untilNames(files.map((file) => file.name));
      await studio.untilSession("uploadBusy", false);
      const contracts = (await core.folder("Contracts")).id;
      for (const file of files) {
        const doc = await core.document(file.name);
        assert.equal(doc.content_sha256, sha256(file.buffer), file.name);
        assert.equal(doc.folder_id, contracts, file.name);
      }
    }, { load: false });

  scenario("3.3", "files dragged from the desktop onto the list upload there", BOTH, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.open("Archive");
    const files = [{ name: "drop.bin", buffer: BINARY }, { name: "メモ.txt", buffer: Buffer.from("落とした") }];
    await studio.dropFiles("entryList", files, () => studio.untilShown("dropOverlay"));
    await studio.untilShown("dropOverlay", false);
    await studio.untilNames(["drop.bin", "メモ.txt"]);
    await studio.untilSession("uploadBusy", false);
    for (const file of files)
      assert.equal(await landed(core, file.name), sha256(file.buffer), file.name);
    const archive = (await core.folder("Archive")).id;
    assert.equal((await core.document("drop.bin")).folder_id, archive);
  });

  scenario("3.4", "the status line counts the files on the wire", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    assert.equal(await studio.shown("uploadProgress"), false);
    await core.fail({ method: "POST", path: "/uploads$", mode: "hold", count: 2 });
    await studio.dropFiles("entryList", TWO_FILES);
    await studio.untilHeld(core);
    assert.equal(await studio.prop("uploadText", "text"), "Uploading 1 of 2 · 0%");
    const progress = await studio.item("uploadProgress");
    assert.equal(progress.visible, true);
    assert.deepEqual(progress.a11y, { name: "Uploading 1 of 2 · 0%", role: "ProgressBar",
      checkable: false, checked: false });
    await core.release();
    await studio.untilHeld(core);
    assert.equal(await studio.prop("uploadText", "text"), "Uploading 2 of 2 · 0%");
    await core.release();
    await studio.untilShown("uploadProgress", false);
    await studio.untilIdle();
    assert.deepEqual((await studio.names()).slice(-2), ["a.txt", "b.txt"]);
  });

  scenario("3.4", "each file's bar fills to 100% before the next", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await core.fail({ method: "POST", path: "/complete$", mode: "hold" });
    await studio.dropFiles("entryList", TWO_FILES);
    await studio.untilHeld(core);
    assert.equal(await studio.prop("uploadText", "text"), "Uploading 1 of 2 · 100%");
    assert.equal((await studio.item("uploadBar")).w, 80);
    await core.release();
    await studio.untilShown("uploadProgress", false);
  });

  scenario("3.5", "a file Core refuses is named in the status line; the rest still land", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      // Each file has its own name: a failed upload leaves its document, which holds it.
      const faults = [
        ["server.txt", { method: "POST", path: "/uploads$", status: 500 },
          `Could not upload “server.txt”: ${MESSAGES.server}`],
        // The browser's fetch never retries a dropped PUT (Qt's native
        // network stack retries once), so one drop fails the file.
        ["dropped.txt", { method: "PUT", path: "^/files/", mode: "drop" },
          "Could not upload “dropped.txt”: Core or storage could not be reached."],
        ["refused.txt", { method: "POST", path: "/complete$", status: 422, error: "verification_failed" },
          "Could not upload “refused.txt”: Core refused it."],
      ];
      for (const [name, rule, words] of faults) {
        await core.fail(rule);
        await studio.dropFiles("entryList", [{ name, buffer: Buffer.from("bad") }]);
        await studio.untilStatus(words);
        await studio.untilSession("uploadBusy", false);
        assert.equal(await studio.prop("explorerStatus", "color"), await studio.theme("failed"));
        assert.deepEqual((await core.state()).faults, []);
        assert.equal(await landed(core, name), null);
      }

      await core.fail({ method: "POST", path: "/uploads$", status: 500 });
      await studio.dropFiles("entryList", [
        { name: "bad.txt", buffer: Buffer.from("bad") }, { name: "kept.txt", buffer: Buffer.from("kept") },
      ]);
      await studio.untilListed("kept.txt");
      await studio.untilSession("uploadBusy", false);
      assert.equal(await landed(core, "kept.txt"), sha256(Buffer.from("kept")));
      assert.equal(await studio.statusText(), `Could not upload “bad.txt”: ${MESSAGES.server}`);
      await studio.press("Backspace");
      await studio.untilLevel("spaces");
      assert.equal(await studio.statusText(), "");
    });

  scenario("3.6", "D downloads the document through the browser", DESKTOP, async ({ studio, core, page }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.select("Notes");
    const [download] = await Promise.all([page.waitForEvent("download"), studio.press("d")]);
    assert.equal(download.suggestedFilename(), "Notes");
    const chunks = [];
    for await (const chunk of await download.createReadStream())
      chunks.push(chunk);
    assert.equal(Buffer.concat(chunks).toString(), "notes body");
    await studio.untilIdle();
    assert.equal(await studio.statusText(), "");
  });

  scenario("3.7", "rename in place by F2 and the menu; Esc cancels", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.select("Notes");
    await studio.press("F2");
    await studio.untilFocus("rowEditor");
    assert.equal((await studio.focus()).text, "Notes");
    await studio.press("Control+a");
    await studio.type("Minutes");
    await studio.press("Enter");
    await studio.untilListed("Minutes");
    assert.ok(await core.document("Minutes"));

    await studio.select("Minutes");
    await studio.press("F2");
    await studio.untilFocus("rowEditor");
    await studio.type("Nope");
    await studio.press("Escape");
    await studio.untilRegion("entryPane");
    assert.ok((await studio.names()).includes("Minutes"));

    await studio.openMenu("Archive");
    await studio.pick("rename");
    await studio.untilFocus("rowEditor");
    await studio.press("Control+a");
    await studio.type("Attic");
    await studio.press("Enter");
    await studio.untilListed("Attic");
    assert.ok(await core.folder("Attic"));
  });

  // The menu opens over Contracts; the click on its Rename row must rename
  // Archive, the row the menu is for.
  scenario("3.7", "a mouse click on the menu's Rename renames the row the menu is for", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await studio.select("Notes");
      await studio.openMenu("Archive");
      await studio.click("menu_rename");
      await studio.untilFocus("rowEditor");
      assert.equal((await studio.focus()).text, "Archive");
    });

  // A folder has no trash: the toolbar deletes it for good once confirmed.
  scenario("3.8", "trash by Del, the menu, and the toolbar", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.select("Notes");
    await studio.press("Delete");
    await studio.untilListed("Notes", false);
    await studio.untilStatus("Moved to trash. Restore brings it back.");
    assert.equal((await core.state()).trash.length, 1);

    await studio.openMenu("Budget");
    await studio.pick("trash");
    await studio.untilListed("Budget", false);

    await studio.select("Contracts");
    await studio.click("trashButton");
    await studio.untilFocus("confirmCancel");
    await studio.click("confirmAccept");
    await studio.untilNames(["Archive"]);
    const { folders, trash: trashed } = await core.state();
    assert.deepEqual(folders.map((folder) => folder.name), ["Archive"]);
    assert.equal(trashed.length, 2);
  });

  // Ctrl+Z is the browser's undo only inside editable DOM; the canvas's
  // hidden input hands it to Qt, which restores the last trash.
  scenario("3.9", "Ctrl+Z and the restore button bring the last trash back", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await trash(studio, core, "Notes");
    await studio.press("Control+z");
    await studio.untilListed("Notes");
    assert.equal((await core.state()).trash.length, 0);

    await trash(studio, core, "Budget");
    await studio.click("restoreButton");
    await studio.untilListed("Budget");
    await studio.untilShown("restoreButton", false);
  });

  scenario("3.10", "purge empties Core's trash; a refused purge keeps it restorable", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await trash(studio, core, "Notes");
      await studio.runFromSheet("purge");
      await studio.until(async () => (await core.state()).trash.length === 0, "the trash purged");
      await studio.untilShown("restoreButton", false);
      assert.ok(!(await core.document("Notes")));

      await trash(studio, core, "Budget");
      await core.fail({ method: "POST", path: "/purge$", status: 500 });
      await studio.runFromSheet("purge");
      await studio.untilStatus(MESSAGES.server);
      assert.equal((await core.state()).trash.length, 1);
      await studio.click("restoreButton");
      await studio.untilListed("Budget");
    });

  // Ctrl+V reaches Qt as the browser's paste event. Here the page's
  // clipboard holds text, as after any copy; the next scenario empties it.
  scenario("3.11", "cut and paste move documents into a folder", BOTH, async ({ studio, core, page }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    if (studio.touch) {
      await studio.openMenu("Notes");
      await studio.pick("cut");
    } else {
      await studio.select("Notes");
      await studio.press("Control+x");
    }
    await studio.untilStatus("Cut. Paste moves it into the open folder.");
    await studio.open("Contracts");
    if (studio.touch) {
      await studio.fab("paste");
    } else {
      await studio.click("pasteButton");
    }
    await studio.untilNames(["Notes"]);
    await studio.untilSession("hasClipboard", false);
    const contracts = (await core.folder("Contracts")).id;
    assert.equal((await core.document("Notes")).folder_id, contracts);
    if (studio.touch)
      return;

    await studio.press("Backspace");
    await studio.untilHere("Docs");
    await studio.select("Budget");
    await studio.press("Control+x");
    await studio.untilSession("hasClipboard", true);
    await studio.open("Contracts");
    await page.evaluate(() => navigator.clipboard.writeText("copied earlier"));
    await studio.press("Control+v");
    await studio.untilNames(["Notes", "Budget"]);
    assert.equal((await core.document("Budget")).folder_id, contracts);
  }, { context: { permissions: ["clipboard-read", "clipboard-write"] } });

  scenario("3.11", "Ctrl+V pastes the cut row when the browser clipboard is empty", DESKTOP,
    async ({ studio, core, page }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      // The browser's clipboard outlives a context; empty it first.
      await page.evaluate(() => navigator.clipboard.writeText(""));
      await studio.select("Notes");
      await studio.press("Control+x");
      await studio.untilSession("hasClipboard", true);
      await studio.open("Contracts");
      await studio.press("Control+v");
      await studio.untilNames(["Notes"]);
    }, { context: { permissions: ["clipboard-read", "clipboard-write"] } });

  scenario("3.12", "a row dragged onto a folder row moves there", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.drag(studio.row("Notes"), studio.row("Contracts"));
    await studio.untilListed("Notes", false);
    assert.equal((await core.document("Notes")).folder_id, (await core.folder("Contracts")).id);
  });

  scenario("3.12", "a row dragged onto a tree node or a crumb moves there", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    await studio.drag(studio.row("Budget"), studio.row("Archive", "treeRow"));
    await studio.untilListed("Budget", false);
    await studio.open("Archive");
    await studio.drag(studio.row("Budget"), "crumb1");
    await studio.untilNames([]);
  });

  scenario("3.13", "the list refuses desktop files outside a space", DESKTOP, async ({ studio, core }) => {
    await core.seed(SPACE);
    await studio.signIn();
    await studio.dropFiles("entryList", [{ name: "early.txt", buffer: Buffer.from("early") }],
      async () => assert.equal(await studio.shown("dropOverlay"), false));
    await studio.open("Acme");
    await studio.dropFiles("entryList", [{ name: "early.txt", buffer: Buffer.from("early") }],
      async () => assert.equal(await studio.shown("dropOverlay"), false));
    await studio.untilIdle();
    assert.equal(await studio.session("uploadBusy"), false);
    assert.equal(await core.document("early.txt"), undefined);
  });

  scenario("3.14", "a folder pasted into itself or below is refused and stays put", DESKTOP,
    async ({ studio, core }) => {
      await core.seed({ organizations: [{ name: "Acme", spaces: [{ name: "Docs",
        folders: [{ name: "Outer", folders: [{ name: "Inner" }] }] }] }] });
      await studio.enter("Acme", "Docs");
      await studio.select("Outer");
      await studio.press("Control+x");
      await studio.untilSession("hasClipboard", true);
      await studio.press("Enter");
      await studio.untilHere("Outer");
      await studio.click("pasteButton");
      await studio.untilStatus(CYCLE);
      assert.equal(await studio.prop("explorerStatus", "color"), await studio.theme("failed"));

      await studio.press("Backspace");
      await studio.untilHere("Docs");
      await studio.select("Outer");
      await studio.press("Control+x");
      await studio.open("Outer");
      await studio.open("Inner");
      await studio.click("pasteButton");
      await studio.untilProp("emptyText", "text", CYCLE);
      assert.equal((await core.folder("Outer")).parent_id, null);
    });
};
