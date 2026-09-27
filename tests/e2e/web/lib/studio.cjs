// One studio tab and every way a test touches it. Eyes: the e2e build's
// window.matomeE2E probe (items by objectName, focus, singletons, models).
// Hands: Playwright's real mouse, keyboard, and touch on the page, aimed at
// the probe's rectangles. Waits are conditions polled until they hold.
"use strict";

const zlib = require("node:zlib");
const { EMAIL, PASSWORD, REGIONS } = require("./constants.cjs");

const POLL_MS = 25;
const TIMEOUT_MS = 10000;
// Loading the page and booting its WASM share one budget: a cold,
// instrumented build on a busy machine takes tens of seconds.
const LOAD_MS = 60000;

// "name", or {name | prefix, title?, child?}.
function selector(sel) {
  return typeof sel === "string" ? { name: sel } : sel;
}

function describe(sel) {
  return JSON.stringify(selector(sel));
}

class Studio {
  constructor(page, stack, profile) {
    this.page = page;
    this.stack = stack;
    this.profile = profile;
    this.touch = Boolean(profile.hasTouch);
    this.errors = [];
    page.on("pageerror", (err) => this.errors.push(err.message));
  }

  // Navigates to `url` (this run's studio by default) within the load budget.
  goto(url = this.stack.webUrl + "/") {
    return this.page.goto(url, { timeout: LOAD_MS });
  }

  // Polls `check` within the load budget: for what waits on the WASM boot.
  untilBooted(check, what) {
    return this.until(check, what, LOAD_MS);
  }

  // Loads the page (at `url` when given, as goto() does) and waits for the
  // studio to paint its first screen with the splash gone.
  async load(url) {
    await this.goto(url);
    await this.untilPainted();
  }

  // Reloads the page and waits as load() does.
  async reload() {
    await this.page.reload({ timeout: LOAD_MS });
    await this.untilPainted();
  }

  untilPainted() {
    return this.untilBooted(async () => {
      const ready = await this.page.evaluate(() => typeof window.matomeE2E === "function"
        && getComputedStyle(document.querySelector("#qtspinner")).display === "none");
      return ready && ((await this.shown("authScreen")) || (await this.shown("explorer")));
    }, "the studio to paint");
  }

  // ---- eyes ---------------------------------------------------------------

  probe(request) {
    return this.page.evaluate((r) => window.matomeE2E(r), request);
  }

  async items(sel, props = []) {
    return (await this.probe({ op: "items", props, ...selector(sel) })) || [];
  }

  // The first visible match, else the first hidden one, else null.
  async item(sel, props = []) {
    return (await this.items(sel, props))[0] || null;
  }

  async shown(sel) {
    const found = await this.item(sel);
    return Boolean(found && found.visible);
  }

  async prop(sel, name) {
    const found = await this.item(sel, [name]);
    return found ? found.props[name] : undefined;
  }

  async object(name, ...props) {
    return this.probe({ op: "object", name, props });
  }

  async session(prop) {
    return (await this.object("Session", prop))[prop];
  }

  async theme(prop) {
    return (await this.object("Theme", prop))[prop];
  }

  // The names of the rows the explorer lists, in order.
  async names() {
    const rows = await this.probe({ op: "rows", object: "Session", model: "entries", roles: ["name"] });
    return rows.map((row) => row.name);
  }

  focus() {
    return this.probe({ op: "focus" });
  }

  async focusName() {
    return (await this.focus()).name;
  }

  async region() {
    const { chain } = await this.focus();
    return chain.find((name) => REGIONS.includes(name)) || "";
  }

  wiring() {
    return this.probe({ op: "wiring" });
  }

  // The level the explorer stands at, named as the desktop suite does.
  async level() {
    const kind = await this.session("childKind");
    return { org: "orgs", space: "spaces", folder: "files" }[kind];
  }

  // Polls `check` until it returns something truthy and hands that back.
  async until(check, what, timeout = TIMEOUT_MS) {
    const deadline = Date.now() + timeout;
    let last;
    for (;;) {
      try {
        last = await check();
        if (last)
          return last;
      } catch (err) {
        last = err.message;
      }
      if (Date.now() > deadline)
        throw new Error(`timed out waiting for ${what} (last: ${JSON.stringify(last)})`);
      await new Promise((resolve) => setTimeout(resolve, POLL_MS));
    }
  }

  async untilEqual(read, wanted, what) {
    let seen;
    try {
      await this.until(async () => {
        seen = await read();
        return JSON.stringify(seen) === JSON.stringify(wanted);
      }, what);
    } catch (err) {
      throw new Error(`timed out waiting for ${what} to be ${JSON.stringify(wanted)}; it is ${JSON.stringify(seen)}`);
    }
  }

  untilProp(sel, name, wanted) {
    return this.untilEqual(() => this.prop(sel, name), wanted, `${describe(sel)}.${name}`);
  }

  untilSession(prop, wanted) {
    return this.untilEqual(() => this.session(prop), wanted, `Session.${prop}`);
  }

  untilShown(sel, wanted = true) {
    return this.untilEqual(() => this.shown(sel), wanted, `${describe(sel)} shown`);
  }

  untilFocus(name) {
    return this.untilEqual(() => this.focusName(), name, "the focused item");
  }

  untilRegion(region) {
    return this.untilEqual(() => this.region(), region, "the focused region");
  }

  untilLevel(level) {
    return this.untilEqual(() => this.level(), level, "the level");
  }

  // The rows list exactly `names`, in order.
  untilNames(names) {
    return this.untilEqual(() => this.names(), names, "the rows");
  }

  // The rows list `name` (or, `present` false, no longer do).
  untilListed(name, present = true) {
    return this.until(async () => (await this.names()).includes(name) === present,
      `${name} ${present ? "listed" : "gone"}`);
  }

  // Waits until `core` holds an answer back (a "hold" fault): the studio
  // stays in the state that answer would end until core.release().
  untilHeld(core) {
    return this.until(async () => (await core.state()).held === 1, "Core to hold an answer");
  }

  untilTheme(mode) {
    return this.untilEqual(() => this.theme("mode"), mode, "Theme.mode");
  }

  // A visible item whose rectangle held still for two polls: laid out and
  // done moving, so a pointer aimed at it lands on it.
  async locate(sel) {
    let previous = null;
    return this.until(async () => {
      const found = await this.item(sel);
      if (!found || !found.visible || found.w <= 0 || found.h <= 0) {
        previous = null;
        return null;
      }
      const still = previous && ["x", "y", "w", "h"].every((key) => previous[key] === found[key]);
      previous = found;
      return still ? found : null;
    }, `${describe(sel)} to show and hold still`);
  }

  row(title, prefix = "entryRow") {
    return { prefix, title };
  }

  // ---- hands --------------------------------------------------------------

  async point(sel, dx = 0.5, dy = 0.5) {
    const box = await this.locate(sel);
    return { x: box.x + box.w * dx, y: box.y + box.h * dy };
  }

  // Two clicks on one spot within Qt's double-click interval are a double
  // click; a second single click there waits the interval out. This is the
  // one timed wait: the gesture is defined by time.
  async click(sel, { button = "left" } = {}) {
    const at = await this.point(sel);
    const last = this.lastClick;
    if (last && Math.hypot(last.x - at.x, last.y - at.y) < 5) {
      const { doubleClickMs } = await this.wiring();
      const wait = last.time + doubleClickMs + 50 - Date.now();
      if (wait > 0)
        await new Promise((resolve) => setTimeout(resolve, wait));
    }
    await this.page.mouse.move(at.x, at.y);
    await this.page.mouse.click(at.x, at.y, { button });
    this.lastClick = { ...at, time: Date.now() };
  }

  async dblclick(sel) {
    const at = await this.point(sel);
    await this.page.mouse.move(at.x, at.y);
    await this.page.mouse.dblclick(at.x, at.y);
  }

  async hover(sel) {
    const at = await this.point(sel);
    await this.page.mouse.move(at.x, at.y);
  }

  async tap(sel, dx, dy) {
    const at = await this.point(sel, dx, dy);
    await this.page.touchscreen.tap(at.x, at.y);
  }

  // A finger held on `sel` until `done` holds (the gesture's own outcome,
  // such as the context menu opening), then lifted.
  async longPress(sel, done, what) {
    const at = await this.point(sel);
    const cdp = await this.page.context().newCDPSession(this.page);
    const touch = (type, points) => cdp.send("Input.dispatchTouchEvent", { type, touchPoints: points });
    await touch("touchStart", [{ x: at.x, y: at.y }]);
    try {
      await this.until(done, what);
    } finally {
      await touch("touchEnd", []);
      await cdp.detach();
    }
  }

  // A mouse drag from one item onto another, in steps a drag handler sees.
  async drag(from, onto) {
    const start = await this.point(from);
    const end = await this.point(onto);
    await this.page.mouse.move(start.x, start.y);
    await this.page.mouse.down();
    await this.page.mouse.move(start.x + 20, start.y + 20, { steps: 5 });
    await this.page.mouse.move(end.x, end.y, { steps: 10 });
    await this.page.mouse.up();
  }

  // Keys reach Qt only while the page's focus is inside its window (its
  // focus helper or text input). After a click Qt re-focuses that element a
  // task later; keys sent in between would land on <body>.
  untilKeyboard() {
    return this.until(() => this.page.evaluate(() => {
      const host = document.querySelector("#qt-shadow-container");
      const inner = host && host.shadowRoot.activeElement;
      return document.activeElement === host && inner !== null && inner.closest(".qt-window") !== null;
    }), "the page's keyboard focus inside the studio");
  }

  async press(keys) {
    await this.untilKeyboard();
    await this.page.keyboard.press(keys);
  }

  async type(text) {
    await this.untilKeyboard();
    await this.page.keyboard.type(text);
  }

  // Focuses a field by pointer (tap on touch), replaces its text by
  // keyboard, and leaves focus in it.
  async fill(sel, text) {
    if (this.touch)
      await this.tap(sel);
    else
      await this.click(sel);
    await this.untilEqual(async () => (await this.item(sel)).focus, true, `${describe(sel)} focused`);
    await this.press("Control+A");
    await this.press("Backspace");
    await this.untilProp(sel, "text", "");
    if (text !== "")
      await this.type(text);
    await this.untilProp(sel, "text", text);
  }

  // Clicks, or taps on a touch profile.
  activate(sel) {
    return this.touch ? this.tap(sel) : this.click(sel);
  }

  // ---- flows --------------------------------------------------------------

  // Chromium offers window.showOpenFilePicker, a native dialog Playwright
  // cannot fill; Qt then uses it. Without it (Firefox, Safari) Qt opens an
  // <input type=file>, which is the picker Playwright drives.
  async loadWithInputPicker() {
    await this.page.addInitScript(() => { delete window.showOpenFilePicker; });
    await this.load();
  }

  // Points the studio at this run's page server (it proxies FakeCore), or at
  // `url`, through the Server disclosure.
  async useServer(url = this.stack.webUrl) {
    if (!(await this.shown("apiField")))
      await this.activate("serverToggle");
    await this.fill("apiField", url);
  }

  // Types the account into the sign-in pane and presses Enter.
  async submit({ email = EMAIL, password = PASSWORD } = {}) {
    await this.fill("emailField", email);
    await this.fill("passwordField", password);
    await this.press("Enter");
  }

  // Signs in through `server` (this run's page server unless given).
  async signIn({ server, email, password } = {}) {
    await this.useServer(server);
    await this.submit({ email, password });
    await this.untilSignedIn();
  }

  // Signs in from a sign-in screen that kept the email and server.
  async signInAgain(password = PASSWORD) {
    await this.fill("passwordField", password);
    await this.press("Enter");
    await this.untilSignedIn();
  }

  async signOut() {
    await this.runFromSheet("sign out");
    await this.untilShown("authScreen");
  }

  async untilSignedIn() {
    await this.until(async () => {
      const { signedIn, busy, loading } = await this.object("Session", "signedIn", "busy", "loading");
      return signedIn && !busy && !loading && (await this.shown("explorer"));
    }, "the explorer after sign-in");
  }

  // Waits until nothing is on the wire for the open level.
  untilIdle() {
    return this.until(async () => {
      const { busy, loading } = await this.object("Session", "busy", "loading");
      return !busy && !loading;
    }, "the session to settle");
  }

  // Opens the row titled `title` by double click (tap on touch) and waits
  // for the location to change and load.
  async open(title) {
    const before = await this.session("trail");
    if (this.touch)
      await this.tap(this.row(title));
    else
      await this.dblclick(this.row(title));
    await this.until(async () => JSON.stringify(await this.session("trail")) !== JSON.stringify(before),
      `opening ${title}`);
    await this.untilIdle();
  }

  // The name of the place the explorer shows.
  async here() {
    const trail = await this.session("trail");
    return trail[trail.length - 1].name;
  }

  untilHere(name) {
    return this.untilEqual(() => this.here(), name, "the open location");
  }

  // Clicks the row titled `title` and waits until it holds the cursor and
  // focus; a document also becomes the open one, which re-reads the rows, so
  // keys pressed next reach the row that is there to stay.
  async select(title) {
    const row = this.row(title);
    await this.click(row);
    await this.until(async () => {
      const found = await this.item(row, ["selected", "kind", "here"]);
      const { selected, kind, here } = found.props;
      return found.focus && selected && (kind !== "document" || here) && !(await this.session("loading"));
    }, `${title} selected`);
  }

  // Signs in and opens `org`, then `space` when given.
  async enter(org, space) {
    await this.signIn();
    await this.open(org);
    if (space)
      await this.open(space);
  }

  // Runs a command from the sheet by typing its title.
  async runFromSheet(query) {
    await this.press(":");
    await this.untilFocus("sheetQuery");
    await this.type(query);
    await this.press("Enter");
    await this.untilShown("commandSheet", false);
  }

  // Every text shown at or under `sel`.
  async texts(sel) {
    return this.prop(sel, "$texts");
  }

  // The context menu's visible commands, top to bottom.
  async menuIds() {
    const rows = (await this.items({ prefix: "menu_" })).filter((row) => row.visible);
    return rows.sort((a, b) => a.y - b.y).map((row) => row.name.slice("menu_".length));
  }

  // Runs `id` from the open context menu by click, or tap on touch.
  async pick(id) {
    await this.untilShown("contextMenuList");
    await this.activate(`menu_${id}`);
    await this.untilShown("contextMenuList", false);
  }

  // Opens the menu of the row titled `title`: a right click, or a long
  // press on touch.
  async openMenu(title) {
    if (this.touch) {
      await this.longPress(this.row(title), () => this.shown("contextMenuList"), "the row menu");
    } else {
      await this.click(this.row(title), { button: "right" });
      await this.untilShown("contextMenuList");
    }
  }

  // Runs `id` from the phone's floating button.
  async fab(id) {
    await this.tap("fabButton");
    await this.pick(id);
  }

  // Hands `files` ({name, buffer}) to the browser's file picker that
  // `trigger` opens (a key, a click); the studio reads them from there.
  async pickFiles(trigger, files) {
    const [chooser] = await Promise.all([this.page.waitForEvent("filechooser"), trigger()]);
    if (!chooser.isMultiple())
      throw new Error("the picker takes one file only");
    await chooser.setFiles(files.map((file) => ({ mimeType: "application/octet-stream", ...file })));
  }

  // What dragging `files` from the desktop onto `sel` sends the page: a
  // DataTransfer of File objects through dragenter, dragover, and drop on
  // the element Qt listens on. `hover`, when given, checks the mid-drag
  // state before the drop.
  async dropFiles(sel, files, hover) {
    const at = await this.point(sel);
    const payload = files.map((file) => ({ name: file.name, bytes: [...file.buffer] }));
    const handle = await this.page.evaluateHandle(({ x, y, payload }) => {
      const target = document.querySelector("#qt-shadow-container").shadowRoot.elementFromPoint(x, y);
      const data = new DataTransfer();
      for (const file of payload)
        data.items.add(new File([new Uint8Array(file.bytes)], file.name));
      const send = (type) => target.dispatchEvent(new DragEvent(type, {
        bubbles: true, cancelable: true, composed: true, clientX: x, clientY: y, dataTransfer: data,
      }));
      send("dragenter");
      send("dragover");
      return { send };
    }, { ...at, payload });
    if (hover)
      await hover();
    await handle.evaluate((drag) => drag.send("drop"));
    await handle.dispose();
  }

  async statusText() {
    return this.prop("explorerStatus", "text");
  }

  untilStatus(text) {
    return this.untilProp("explorerStatus", "text", text);
  }

  // The canvas pixel at a page point, as #rrggbb.
  async pixel(x, y) {
    const png = await this.page.screenshot({ clip: { x, y, width: 1, height: 1 }, scale: "css" });
    return decodePixel(png);
  }
}

// The one RGB pixel of a 1×1 PNG screenshot.
function decodePixel(png) {
  let offset = 8;
  const idat = [];
  let colorType = 6;
  while (offset < png.length) {
    const length = png.readUInt32BE(offset);
    const type = png.toString("ascii", offset + 4, offset + 8);
    const data = png.subarray(offset + 8, offset + 8 + length);
    if (type === "IHDR")
      colorType = data[9];
    else if (type === "IDAT")
      idat.push(data);
    offset += 12 + length;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const hex = (v) => v.toString(16).padStart(2, "0");
  // Byte 0 is the scanline filter; a single pixel has no neighbour to use.
  const [r, g, b] = colorType === 2 || colorType === 6 ? raw.subarray(1, 4) : [raw[1], raw[1], raw[1]];
  return `#${hex(r)}${hex(g)}${hex(b)}`;
}

module.exports = { Studio };
