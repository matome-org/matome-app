// Admin back-office LiveView bootstrap (W0 #1868).
// esbuild bundles this into priv/static/assets/app.js. NODE_PATH points at
// deps/, so these bare imports resolve to the Phoenix packages' JS.
import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
});

liveSocket.connect();

// Expose for debugging in the browser console (dev convenience).
window.liveSocket = liveSocket;
