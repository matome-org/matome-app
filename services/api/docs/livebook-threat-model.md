# Livebook threat model — why it is dev-only

**Wave 0 · #1868 · plan p2-core-backoffice**

## TL;DR

Livebook is used **only** as a standalone dev tool to render the foundations
design-system catalog (`notebooks/foundations_catalog.livemd`) as a visual
drift guard against the Flutter widgetbook. It is **never** a dependency of the
`matome_api` app and is **never** mounted by the Phoenix router or endpoint, so
it **cannot** exist in a `:prod` release.

## The blast radius

Livebook is a notebook environment that **evaluates arbitrary Elixir** in a
running BEAM node with the **full privileges of the OS/service user**. A notebook
cell can:

- read/write any file the process can (secrets, `.env`, keys, the DB);
- open network connections and exfiltrate data;
- connect to / control the app's node (`Node.connect`), call any module —
  including `MatomeApi.Repo`, `MatomeApi.Auth.Guardian`, the storage presigner;
- run shell commands via `System.cmd/os.cmd`.

In short: **a Livebook mount is remote code execution by design.** That is
exactly what makes it excellent for local development and unacceptable anywhere
near production data or credentials.

## How prod exclusion is enforced (defense in depth)

1. **Not a Mix dependency.** Livebook is intentionally absent from
   `services/api/mix.exs`. It therefore cannot be compiled into or started by any
   release, for any `MIX_ENV`. This is the strongest guarantee — there is nothing
   to gate.
   - Verify: `MIX_ENV=prod mix deps | grep -i livebook` → no output.
2. **Not mounted.** No `live_dashboard`/Livebook route or socket exists in
   `lib/matome_api_web/router.ex` or `endpoint.ex`. The only server-rendered
   surface is the empty `/admin` LiveView shell.
   - Verify: `grep -ri livebook lib/` → only comments pointing here.
3. **Run out-of-band, dev only.** The catalog is opened with a **separate**
   `livebook server` process on a developer machine — never wired into the API's
   supervision tree.

## Running the catalog (developers)

```bash
# Install once (dev machine only), then serve:
mix escript.install hex livebook   # or: use the Livebook desktop app
livebook server
# Open services/api/notebooks/foundations_catalog.livemd in the browser.
```

The notebook reads `services/api/assets/css/foundations.css` at runtime and
renders swatches / type scale / spacing / icon inventory. Compare it
side-by-side with the Flutter widgetbook Foundations pages
(`apps/flutter_widgetbook/lib/foundations_stories.dart`) in both Light and Dark
to catch drift.

## If in-app Livebook is ever wanted (it should not be)

Do **not** mount it in `matome_api`. If a hosted notebook is ever genuinely
needed, run Livebook as an isolated, separately-deployed service with its own
auth, on a node with **no** access to prod secrets or the prod database, and
treat access as equivalent to shell access to that node.
