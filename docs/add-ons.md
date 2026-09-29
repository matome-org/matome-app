# Add-on modules

`AddOnManager` owns the current organization's catalog, installed products,
space selection and installation lifecycle. `OrgBilling` owns commercial
quantities and decorates manager products with subscription purchases; it
does not install or pause products. All installation controls use the manager.

The manager distinguishes unknown availability, effective capability entitlement,
installation status and coverage of a selected space. A failed read never
means that the product is available or that existing document gates can be
removed. Ordinary members cannot read the organization installation index;
their availability remains unknown and Core checks every operation.
Entitlements are read once by the manager and shared with billing. Catalog
presence, capability, active installation and space coverage all participate in
the availability calculation; billing quantities alone do not activate a product.

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

New add-on modules consume the manager and injected backend. They own their
resource workflows and confirmations. Product-specific destructive lifecycle
operations remain explicit; they must not replace generic pause semantics.

Run `mise run test:core` for the controller and mock tests. Run `mise run lint`
for build and QML checks, and `mise run i18n` for translation completeness.
