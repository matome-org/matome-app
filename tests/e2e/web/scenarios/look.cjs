// 6 Look & language: theme modes and their crossfade, shape, reduced
// motion, the self-writing mark, the three languages, fonts, and the empty,
// loading, and error states.
"use strict";

const assert = require("node:assert/strict");
const { BOTH, DESKTOP, INK, MESSAGES, argb } = require("../lib/constants.cjs");

// The light background, as a pixel reads it.
const PAPER = "#f6f4ef";
const FONTS = ["Inter", "Newsreader", "Cormorant Garamond", "Noto Sans JP", "Noto Serif JP"];

const SPACE = {
  organizations: [{ name: "Acme", spaces: [{ name: "Docs", folders: [{ name: "Contracts" }] }] }],
};

// Reads Theme.background as fast as the page answers until it is `target`;
// every value seen on the way.
async function backgroundsUntil(studio, target) {
  const seen = [];
  await studio.until(async () => {
    const now = await studio.theme("background");
    if (seen[seen.length - 1] !== now)
      seen.push(now);
    return now === target;
  }, `the background to reach ${target}`);
  return seen;
}

// From light, a click on the sign-in toggle turns the studio dark; every
// background seen on the way.
async function fadeToDark(studio) {
  await studio.click("themeToggle");
  await studio.untilEqual(() => studio.theme("background"), argb(PAPER), "the light background");
  await studio.click("themeToggle");
  return backgroundsUntil(studio, argb(INK));
}

module.exports = (scenario) => {
  scenario("6.1", "the sign-in toggle cycles light, dark, system; the account menu picks one", BOTH,
    async ({ studio, page }) => {
      assert.equal(await studio.theme("mode"), "system");
      assert.equal(await studio.prop("themeToggle", "text"), "System");
      await studio.activate("themeToggle");
      await studio.untilTheme("light");
      assert.equal(await studio.prop("themeToggle", "text"), "Light");
      await studio.press("Enter");
      await studio.untilTheme("dark");
      assert.equal(await studio.theme("dark"), true);
      await studio.press("Space");
      await studio.untilTheme("system");
      assert.equal((await studio.item("themeToggle")).a11y.name, "Theme: System. Switch theme");

      // System follows the browser's colour scheme, live.
      assert.equal(await studio.theme("dark"), false);
      await page.emulateMedia({ colorScheme: "dark" });
      await studio.untilEqual(() => studio.theme("dark"), true, "Theme.dark under a dark browser");
      await page.emulateMedia({ colorScheme: "light" });
      await studio.untilEqual(() => studio.theme("dark"), false, "Theme.dark under a light browser");

      await studio.signIn();
      await studio.activate("accountButton");
      assert.equal(await studio.prop({ name: "menu_theme-system", child: "checkMark" }, "visible"), true);
      await studio.pick("theme-dark");
      await studio.untilTheme("dark");
      await studio.activate("accountButton");
      assert.equal(await studio.prop({ name: "menu_theme-dark", child: "checkMark" }, "visible"), true);
      assert.equal(await studio.prop({ name: "menu_theme-light", child: "checkMark" }, "visible"), false);
      await studio.pick("theme-light");
      await studio.untilTheme("light");
    });

  scenario("6.2", "a mode switch crossfades every colour to the new table", DESKTOP, async ({ studio }) => {
    const seen = await fadeToDark(studio);
    assert.ok(seen.length >= 3, `a fade has steps between paper and ink: ${seen}`);
    assert.equal((await studio.wiring()).windowColor, argb(INK));
    assert.equal(await studio.theme("accentLine"), await studio.theme("accent"));
    assert.equal(await studio.pixel(20, 780), INK);
    await studio.click("themeToggle");
    await studio.click("themeToggle");
    await backgroundsUntil(studio, argb(PAPER));
    assert.equal(await studio.theme("accentLine"), await studio.theme("accentDark"));
    assert.equal(await studio.pixel(20, 780), PAPER);
  });

  scenario("6.4", "off Omarchy, buttons are pills and surfaces have soft corners", DESKTOP,
    async ({ studio, core }) => {
      assert.equal(await studio.theme("pill"), true);
      assert.equal(await studio.theme("rounding"), 8);
      const submit = await studio.item("submitButton", ["radius"]);
      assert.equal(submit.props.radius, submit.h / 2);

      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      const row = await studio.item(studio.row("Contracts"));
      const fill = await studio.item({ ...studio.row("Contracts"), child: "fill" }, ["radius"]);
      assert.equal(fill.x - row.x, 8);
      assert.equal(fill.w, row.w - 16);
      assert.equal(fill.props.radius, 8);
      const add = await studio.item("newButton", ["radius", "primary"]);
      assert.equal(add.props.primary, true);
      assert.equal(add.props.radius, add.h / 2);
    });

  scenario("6.5", "prefers-reduced-motion stops every animation", DESKTOP, async ({ studio, core }) => {
    const motion = await studio.object("Theme", "reduceMotion", "fast", "base", "slow");
    assert.deepEqual(motion, { reduceMotion: true, fast: 0, base: 0, slow: 0 });
    const logo = await studio.item("authLogo", ["writing", "frame", "fold"]);
    assert.deepEqual(logo.props, { writing: false, frame: 1, fold: 1 });

    const seen = await fadeToDark(studio);
    assert.deepEqual(seen.filter((colour) => colour !== argb(PAPER)), [argb(INK)]);

    await core.seed(SPACE);
    await studio.enter("Acme", "Docs");
    const lit = new Set();
    await studio.hover(studio.row("Contracts"));
    await studio.until(async () => {
      const now = await studio.prop(studio.row("Contracts"), "lit");
      lit.add(now);
      return now === 1;
    }, "the hover wash");
    assert.deepEqual([...lit].filter((value) => value !== 0 && value !== 1), []);
  }, { context: { reducedMotion: "reduce" } });

  scenario("6.6", "the mark writes itself stroke by stroke, once", DESKTOP, async ({ studio, page }) => {
    await studio.goto();
    await studio.untilBooted(() => page.evaluate(() => typeof window.matomeE2E === "function"), "the probe");
    const strokes = [];
    await studio.until(async () => {
      const logo = await studio.item("authLogo", ["writing", "frame", "hook", "tick", "fold", "written"]);
      if (!logo)
        return false;
      strokes.push(logo.props);
      return logo.props.written && !logo.props.writing && logo.props.fold === 1;
    }, "the mark to finish writing");
    assert.ok(strokes.some((s) => s.writing && s.frame < 1), "the frame was seen mid-stroke");
    assert.ok(strokes.some((s) => s.writing && s.frame === 1 && s.fold < 1), "the fold came last");
    await studio.until(() => page.evaluate(() =>
      getComputedStyle(document.querySelector("#qtspinner")).display === "none"), "the splash to clear");

    await studio.signIn();
    await studio.signOut();
    const again = await studio.item("authLogo", ["writing", "frame", "fold"]);
    assert.deepEqual(again.props, { writing: false, frame: 1, fold: 1 });
  }, { load: false });

  scenario("6.7", "PT, EN, and 日本語 switch live and persist", BOTH, async ({ studio }) => {
    await studio.activate("language_pt-BR");
    await studio.untilProp("submitButton", "text", "Entrar");
    assert.equal(await studio.prop("paneTitle", "text"), "Entrar");
    const title = async (id) => (await studio.session("commandList")).find((row) => row.id === id).title;
    assert.equal(await title("keymap"), "Mapa do teclado");
    assert.equal(await studio.prop("language_pt-BR", "checked"), true);

    await studio.useServer();
    await studio.submit({ password: "wrong" });
    await studio.untilProp("statusMessage", "text", "E-mail ou senha incorretos.");
    await studio.activate("language_en");
    await studio.untilProp("statusMessage", "text", MESSAGES.wrongPassword);

    await studio.activate("language_ja");
    await studio.untilProp("submitButton", "text", "サインイン");
    if (!studio.touch) {
      await studio.press("ArrowLeft");
      await studio.untilFocus("language_en");
      await studio.press("ArrowLeft");
      await studio.untilFocus("language_pt-BR");
      await studio.press("ArrowLeft");
      await studio.untilFocus("language_pt-BR");
      await studio.press("ArrowRight");
      await studio.press("ArrowRight");
      await studio.untilFocus("language_ja");
      const choice = await studio.item("language_ja");
      assert.deepEqual([choice.a11y.name, choice.a11y.checkable, choice.a11y.checked], ["日本語", true, true]);
    }

    await studio.reload();
    assert.equal(await studio.theme("language"), "ja");
    assert.equal(await studio.prop("submitButton", "text"), "サインイン");
  });

  for (const [locale, language, submit] of [["ja-JP", "ja", "サインイン"], ["pt-BR", "pt-BR", "Entrar"],
    ["fr-FR", "en", "Sign in"]]) {
    scenario("6.8", `a first visit in ${locale} starts in ${language}`, DESKTOP, async ({ studio }) => {
      assert.equal(await studio.theme("language"), language);
      assert.equal(await studio.prop("submitButton", "text"), submit);
    }, { context: { locale } });
  }

  scenario("6.9", "the bundled fonts, Japanese included, are the ones in use", DESKTOP, async ({ studio }) => {
    const { fonts } = await studio.wiring();
    for (const family of FONTS)
      assert.ok(fonts.includes(family), `${family} in ${fonts}`);
    const latin = await studio.object("Theme", "display", "body", "title", "slogan");
    assert.equal(latin.display.resolved, "Cormorant Garamond");
    assert.equal(latin.body.resolved, "Inter");
    assert.equal(latin.title.resolved, "Newsreader");
    assert.equal(latin.slogan.italic, true);

    await studio.click("language_ja");
    await studio.untilProp("submitButton", "text", "サインイン");
    const japanese = await studio.object("Theme", "body", "title");
    assert.equal(japanese.body.resolved, "Noto Sans JP");
    assert.equal(japanese.title.resolved, "Noto Serif JP");
    assert.equal((await studio.prop("submitButton", "labelFont")).resolved, "Noto Sans JP");
  });

  scenario("6.10", "an empty place, a loading one, and a failing one each say so", DESKTOP,
    async ({ studio, core }) => {
      await core.seed(SPACE);
      await studio.enter("Acme", "Docs");
      await studio.open("Contracts");
      await studio.untilProp("emptyState", "mode", "empty");
      assert.equal(await studio.prop("emptyText", "text"), "This folder is empty.\nCreate a folder or drop files here.");
      assert.equal(await studio.prop("emptyText", "color"), await studio.theme("accentText"));
      assert.equal((await studio.prop("emptyText", "font")).italic, true);

      await core.fail({ method: "GET", path: "/documents$", mode: "hold" });
      await studio.press("F5");
      await studio.untilHeld(core);
      assert.equal(await studio.prop("emptyState", "mode"), "loading");
      assert.equal(await studio.prop("emptyText", "text"), "Loading…");
      assert.equal(await studio.shown("itemCount"), false);
      await studio.until(async () => (await studio.prop("emptyState", "first")) < 1, "the lines writing");
      await core.release();
      await studio.untilProp("emptyState", "mode", "empty");
      assert.equal(await studio.prop("emptyState", "first"), 1);
      assert.equal(await studio.shown("itemCount"), true);

      await core.fail({ method: "GET", path: "/folders", status: 500 });
      await studio.press("F5");
      await studio.untilProp("emptyState", "mode", "error");
      assert.equal(await studio.prop("emptyText", "text"), MESSAGES.server);
      assert.equal(await studio.prop("emptyText", "color"), await studio.theme("failed"));
      assert.equal(await studio.shown("itemCount"), false);
      await studio.press("F5");
      await studio.untilProp("emptyState", "mode", "empty");
    });
};
