// What more than one part of the web suite names: the profiles a scenario
// runs in, FakeCore's default account, and what the studio shows.
"use strict";

const BOTH = ["desktop", "mobile"];
const DESKTOP = ["desktop"];

// FakeCore's account after every reset, and the organization it owns.
const EMAIL = "ok@localhost";
const PASSWORD = "secret12";
const OWN_ORG = "ok organization";

// The explorer's focus regions, in F6 order from the top bar.
const REGIONS = ["topBar", "sidebar", "toolbar", "entryPane", "statusBar"];

// The dark background as a pixel reads it (#rrggbb); the probe answers
// colours with their alpha (argb()).
const INK = "#1a1714";

const MESSAGES = {
  unreachable: "Could not reach Core at that URL.",
  server: "Core could not complete that request.",
  wrongPassword: "That email or password is wrong.",
};

function argb(rgb) {
  return `#ff${rgb.slice(1)}`;
}

module.exports = { BOTH, DESKTOP, EMAIL, PASSWORD, OWN_ORG, REGIONS, INK, MESSAGES, argb };
