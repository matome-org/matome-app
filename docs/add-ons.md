# Add-on modules

`AddOnManager` owns the current organization's catalog, installed products
and installation lifecycle. `OrgBilling` owns commercial
quantities and decorates manager products with subscription purchases; it
does not install or pause products. All installation controls use the manager.

The manager distinguishes unknown availability, effective capability
entitlement and installation status. An installed add-on is available in
every space and active in none until a space turns it on
(`PUT spaces/:space_id/add-ons/:product`, off with `DELETE`, listed by
`GET spaces/:space_id/add-ons`, all needing `add_on.space_activate`
there); `AddOnActivations` reads every space's add-ons and turns one on or
off there, controlled documents included. A failed read never
means that the product is available or that existing document gates can be
removed. Ordinary members cannot read the organization installation index;
their availability remains unknown and Core checks every operation.
Entitlements are read once by the manager and shared with billing. Catalog
presence, capability and active installation participate in the
availability calculation; billing quantities alone do not activate a
product. Whether it is active in a space is Core's: an add-on action needs
the add-on active there and the action granted, so the space's action
catalog (`GET action-catalog?space_id=`) grants an add-on action only where
both hold.

`AddOnBackend` is the injectable asynchronous boundary. `CoreAddOnBackend`
uses Session's authenticated requests and Client's signed storage transfers.
The shared backend implementation handles pagination, checksums and the
upload creation, transfer and completion sequence. Failed transfers or
completions request an upload abort before reporting the original failure.
Ordinary uploads use this same implementation through the Core backend.

Construct `Session(nullptr, &backend)` to inject a backend for add-on modules.
The supplied backend must outlive the session. Authentication and ordinary
explorer reads still use Session's Core connection. `AddOnManager` can also be
constructed directly with a backend and an explicit organization context,
without a session or any HTTP server.

`tests/MockAddOnBackend.h` provides configurable responses, queued failures,
delayed replies, file bytes and captured requests. Tests exercise installation
and review APIs without a Core service. Controller tests use FakeCore only
for identity and explorer setup; add-on operations use the injected mock.
Replies after context changes or controller destruction are discarded.

`AddOnManager::install` sends one installation request with the settings
alone; Core makes the installer the responsible member, which `assign`
changes. `uninstall` sends the installation `DELETE`; only controlled
documents needs a reason. Core keeps an uninstalled installation with
status `uninstalled`
and reactivates it on `PUT`; the manager reads it as no installation, so
every consumer shows the product as not installed, and installing it again
is a first installation. `resume` sends the saved settings back unchanged,
because Core resumes on `PUT`, which replaces them.

`AddOnAccess` counts who holds the roles an add-on brings: `measure`
counts, from the grants on every space of the organization, the people and
groups holding a role of the add-on (`role_key` under `addon.<product>.`)
and how many hold each of those roles; the pause and uninstall panels
state that count, with the spaces where it is active, before confirming.
Access to an add-on's roles is given like any other, on a space's access.

`AddOnActivations` lists, for every space of the organization, the
installed add-ons that work per space with their state there, from
`GET spaces/:id/add-ons`. `activate` sends `PUT spaces/:id/add-ons/:product`
with the space's settings overrides, `deactivate` sends `DELETE` on the same
path; both carry the activation's revision once it has one, and Core's
answer replaces the space's row. It reads every space again when the
organization's spaces or installation states change. The space's page and
the add-on's page open the same activation panel on it, so every add-on,
the classifier included, turns on per space the same way.

Settings › Add-ons is a table of the add-ons with their status and the
number of spaces where each is active; **Open** opens the one selected. Its
page's tabs are **Details** (the status and the organization settings read
only), **Spaces** (a table of the spaces where it works, active or not),
and **Roles** (a table of the roles it adds); its own commands open a side
panel for **Install** (the settings,
then **Install**), **Pause** and **Uninstall** (what each stops, then the
step; uninstalling document control asks a reason), **Settings**, and
**Plan and usage** (allowance, packages, and the purchased quantity), while
**Resume** acts at once. **Responsible member** is an advanced panel shown
only for an add-on that calls Core itself: Core does not say which those
are, so the app treats an add-on that works per space and declares no
action of its own in the action catalog as one. Management stays in
Settings: an add-on only extends the document view, and the app's default
flow does not depend on any add-on.

New add-on modules consume the manager and injected backend. They own their
resource workflows and confirmations. Product-specific destructive lifecycle
operations remain explicit; they must not replace generic pause semantics.

Run `mise run test:core` for the controller and mock tests. Run `mise run lint`
for build and QML checks, and `mise run i18n` for translation completeness.
