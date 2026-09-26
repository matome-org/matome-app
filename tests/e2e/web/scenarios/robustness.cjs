// 7 Robustness: Core dying and failing, long lists, long names, and the
// shipped binary booting in a browser.
"use strict";

const assert = require("node:assert/strict");
const { Studio } = require("../lib/studio.cjs");
const { BOTH, DESKTOP, EMAIL, INK, MESSAGES, OWN_ORG, argb } = require("../lib/constants.cjs");

const SPACE = {
  organizations: [{ name: "Acme", spaces: [{ name: "Docs", folders: [{ name: "Contracts" }, { name: "Drafts" }] }] }],
};

// Settings the studio saved on an earlier visit, dark and in Japanese with
// Core at `apiBaseUrl` (QSettings on WASM is localStorage under this prefix).
function savedSettings(context, apiBaseUrl) {
  const values = { "theme/mode": "dark", "theme/language": "ja", "session/email": EMAIL,
    "session/apiBaseUrl": apiBaseUrl };
  return context.addInitScript((entries) => {
    for (const [key, value] of Object.entries(entries))
      localStorage.setItem(`qt-v0-matome-matome--studio-${key}`, value);
  }, values);
}

// Whether `inner` lies within `outer` (rectangles from the probe).
function inside(inner, outer) {
  return inner.y >= outer.y - 0.5 && inner.y + inner.h <= outer.y + outer.h + 0.5
    && inner.x >= outer.x - 0.5 && inner.x + inner.w <= outer.x + outer.w + 0.5;
}

async function cursorInSight(studio) {
  const list = await studio.item("entryList", ["currentIndex"]);
  const row = await studio.item(`entryRow${list.props.currentIndex}`);
  return Boolean(row && inside(row, list));
}

module.exports = (scenario) => {
  // The studio talks to Core itself here (CORS), so Core dying is a refused
  // connection, as it is for a deployed page whose Core goes away.
  scenario("7.1", "Core dying mid-use is a message, and the same refresh recovers", DESKTOP,
    async ({ studio, core, stack }) => {
      await core.seed(SPACE);
      await studio.signIn({ server: stack.coreUrl });
      await studio.open("Acme");
      await studio.open("Docs");

      await stack.stopCore();
      await studio.press("F5");
      await studio.untilStatus(MESSAGES.unreachable);
      assert.equal(await studio.session("signedIn"), true);
      assert.deepEqual(await studio.names(), ["Contracts", "Drafts"]);
      await studio.dblclick(studio.row("Contracts"));
      await studio.untilProp("emptyText", "text", MESSAGES.unreachable);

      await stack.startCore(stack.corePort);
      await core.seed(SPACE);
      await studio.press("F5");
      await studio.untilProp("emptyState", "mode", "empty");
      assert.equal(await studio.statusText(), "");
      assert.equal(await studio.here(), "Contracts");
    });

  // Behind the page server the browser still reaches its origin; the proxy
  // answers 502 for the dead Core, which reads as a server failure.
  scenario("7.1", "Core dying behind the page server reads as a server failure", DESKTOP,
    async ({ studio, core, stack }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await stack.stopCore();
      await studio.press("F5");
      await studio.untilStatus(MESSAGES.server);
      assert.equal(await studio.session("signedIn"), true);
      await stack.startCore(stack.corePort);
      await core.seed(SPACE);
      await studio.press("F5");
      await studio.untilStatus("");
      assert.deepEqual(await studio.names(), ["Contracts", "Drafts"]);
    });

  scenario("7.2", "a 500 reads the same at every level: status line over rows, message over none", DESKTOP,
    async ({ studio, core }) => {
      await core.seed({ organizations: [{ name: "Acme" }, { name: "Beta", spaces: [{ name: "Docs",
        folders: [{ name: "Contracts" }] }] }] });
      await studio.signIn();
      await core.fail({ method: "GET", path: "^/api/v1/organizations$", status: 500 });
      await studio.press("F5");
      await studio.untilStatus(MESSAGES.server);
      assert.deepEqual(await studio.names(), ["Acme", "Beta", OWN_ORG]);
      await studio.press("F5");
      await studio.untilStatus("");

      await studio.open("Acme");
      await core.fail({ method: "GET", path: "/spaces$", status: 500 });
      await studio.press("F5");
      await studio.untilProp("emptyText", "text", MESSAGES.server);
      assert.equal(await studio.prop("emptyState", "mode"), "error");
      assert.equal(await studio.shown("itemCount"), false);

      await studio.click(studio.row("Beta", "orgRow"));
      await studio.untilHere("Beta");
      await studio.open("Docs");
      await core.fail({ method: "GET", path: "/folders", status: 500 });
      await studio.press("F5");
      await studio.untilStatus(MESSAGES.server);
      assert.equal(await studio.prop("explorerStatus", "color"), await studio.theme("failed"));
      await studio.open("Contracts");
      await core.fail({ method: "GET", path: "/folders", status: 500 });
      await studio.press("F5");
      await studio.untilProp("emptyState", "mode", "error");
      assert.equal(await studio.prop("emptyText", "text"), MESSAGES.server);
      await studio.press("F5");
      await studio.untilProp("emptyState", "mode", "empty");
    });

  scenario("7.3", "two hundred rows scroll, and every cursor key keeps its row in sight", BOTH,
    async ({ studio, core }) => {
      await core.seed({ organizations: [{ name: "Acme", spaces: [{ name: "Docs",
        documents: [{ title: "Row", repeat: 200 }] }] }] });
      await studio.enter("Acme", "Docs");
      await studio.untilProp("itemCount", "text", "200 items");
      assert.ok(await cursorInSight(studio));
      const top = (await studio.item("entryList", ["contentY"])).props.contentY;

      if (!studio.touch) {
        await studio.click(studio.row("Row 003"));
        await studio.untilProp("entryList", "currentIndex", 2);
        await studio.press("End");
        await studio.untilProp("entryList", "currentIndex", 199);
        await studio.until(() => cursorInSight(studio), "Row 200 in sight");
        await studio.untilFocus("entryRow199");
        await studio.press("PageUp");
        await studio.until(async () => (await studio.prop("entryList", "currentIndex")) < 199, "PageUp");
        await studio.until(() => cursorInSight(studio), "the cursor in sight after PageUp");
        for (let i = 0; i < 5; ++i)
          await studio.press("ArrowUp");
        await studio.until(() => cursorInSight(studio), "the cursor in sight after Up");
        await studio.press("PageDown");
        await studio.until(() => cursorInSight(studio), "the cursor in sight after PageDown");
        await studio.press("Home");
        await studio.untilProp("entryList", "currentIndex", 0);
        await studio.untilEqual(async () => (await studio.item("entryList", ["contentY", "topMargin"])).props,
          { contentY: -4, topMargin: 4 }, "the list at its top");
      }

      // A wheel on desktop, a swipe on the phone.
      const list = await studio.locate("entryList");
      if (studio.touch) {
        const cdp = await studio.page.context().newCDPSession(studio.page);
        await cdp.send("Input.synthesizeScrollGesture", { x: Math.round(list.x + list.w / 2),
          y: Math.round(list.y + list.h * 0.8), yDistance: -300, speed: 800 });
        await cdp.detach();
      } else {
        await studio.page.mouse.move(list.x + list.w / 2, list.y + list.h / 2);
        await studio.page.mouse.wheel(0, 360);
      }
      await studio.until(async () => (await studio.prop("entryList", "contentY")) > top, "the list to scroll");
      await studio.untilProp("entryList", "moving", false);
    });

  scenario("7.4", "long and Japanese names end in an ellipsis inside their row and title", BOTH,
    async ({ studio, core }) => {
      const latin = Array(20).fill("Quarterly report").join(" ");
      const japanese = "とても長い日本語の書類名です".repeat(12);
      const folder = "とても長い日本語のフォルダ名です".repeat(12);
      await core.seed({ organizations: [{ name: "Acme", spaces: [{ name: "Docs", folders: [{ name: folder }],
        documents: [{ title: latin, content: "x" }, { title: japanese, content: "y" }] }] }] });
      await studio.enter("Acme", "Docs");
      await studio.untilNames([folder, latin, japanese]);
      const list = await studio.locate("entryList");
      for (const name of [latin, japanese, folder]) {
        const row = await studio.locate(studio.row(name));
        const title = await studio.item({ ...studio.row(name), child: "rowTitle" }, ["truncated"]);
        const detail = await studio.item({ ...studio.row(name), child: "rowDetail" });
        assert.equal(row.w, list.w);
        assert.equal(title.props.truncated, true, name);
        assert.ok(title.x + title.w <= detail.x + 0.5);
        assert.ok(detail.visible && inside(detail, row));
      }
      if (!studio.touch) {
        const node = await studio.item({ ...studio.row(folder, "treeRow"), child: "rowTitle" }, ["truncated"]);
        assert.equal(node.props.truncated, true);
        assert.ok(inside(await studio.item(studio.row(folder, "treeRow")), await studio.item("sidebar")));
      }

      await studio.open(folder);
      await studio.untilProp("locationTitle", "text", folder);
      const heading = await studio.item("locationTitle", ["truncated"]);
      const header = await studio.item("locationHeader");
      const count = await studio.item("itemCount");
      const { width } = await studio.wiring();
      assert.equal(heading.props.truncated, true);
      assert.ok(count.visible && inside(count, header));
      assert.ok(header.x + header.w <= width);
      const crumbs = await studio.item("breadcrumb");
      assert.ok(crumbs.x + crumbs.w <= width);
    });

  // The page as shipped (mise run wasm): no probe, so it is judged by its
  // DOM and its pixels, placed from the e2e build of the same sources.
  scenario("7.5", "the shipped build boots: title, icon, splash, and a studio painted from saved settings", BOTH,
    async ({ studio, stack, context, product }) => {
      const productUrl = await stack.serve(product);
      await savedSettings(context, productUrl);
      await studio.load();
      const submit = await studio.locate("submitButton");
      const shipped = new Studio(await context.newPage(), stack, studio.profile);
      await shipped.goto(productUrl + "/");
      assert.equal(await shipped.page.title(), "Matome");
      const icon = await shipped.page.locator("link[rel=icon]").getAttribute("href");
      assert.ok(icon.startsWith("data:image/svg+xml"), icon);
      assert.equal(await shipped.page.locator("#qtspinner").isVisible(), true);
      const screen = await shipped.page.locator("#screen").boundingBox();
      assert.ok(screen.width >= 300 && screen.height >= 400, JSON.stringify(screen));
      await shipped.untilBooted(() => shipped.page.evaluate(() => {
        const splash = getComputedStyle(document.querySelector("#qtspinner")).display === "none";
        const host = document.querySelector("#qt-shadow-container");
        const canvas = host && host.shadowRoot.querySelector("canvas");
        return splash && canvas && canvas.getBoundingClientRect().width > 100;
      }), "the shipped studio to paint");
      assert.equal(await shipped.page.evaluate(() => typeof window.matomeE2E), "undefined");
      await shipped.until(async () => (await shipped.pixel(4, screen.height - 4)) === INK,
        "the saved dark background");
      await shipped.until(async () => (await shipped.pixel(submit.x + 12, submit.y + submit.h / 2)) === "#e1b346",
        "the gold サインイン pill where the e2e build puts it");
      await shipped.page.close();
    }, { load: false });

  scenario("7.5", "main wires the saved language's translator, the icon, and settings", DESKTOP,
    async ({ studio, stack, context }) => {
      await savedSettings(context, stack.webUrl);
      await studio.load();
      const wiring = await studio.wiring();
      assert.equal(wiring.icon, true);
      assert.equal(wiring.application, "matome-studio");
      assert.equal(wiring.organization, "matome");
      assert.equal(wiring.windowColor, argb(INK));
      assert.equal(await studio.theme("mode"), "dark");
      assert.equal(await studio.prop("submitButton", "text"), "サインイン");
      assert.equal(await studio.prop("emailField", "text"), EMAIL);
      assert.equal(await studio.prop("apiField", "text"), stack.webUrl);
      await studio.signInAgain();
    }, { load: false });
};
