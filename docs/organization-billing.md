# Organization billing and add-ons

Open the account menu, choose Settings, and expand an organization in the
sidebar. Plan and billing, Add-ons, and Usage are available to owners,
admins, and billing members. Owners and billing members can change
billing; owners and admins can configure installations. Core authorizes
every request. Custom role grants are not yet reflected in the client
navigation, which follows the organization's built-in membership role.

Plan and billing shows the effective plan and the subscription status,
period end, scheduled cancellation, and pending payment. Manage billing
creates a Stripe portal session. Open Stripe portal then opens the returned
HTTPS link in the browser. The explicit second action also permits browser
popup protection to recognize the user's click. Payment methods, invoices,
billing details, and cancellation are handled by Stripe.

The browser's origin is the return destination on web. Desktop uses
`https://app.matome.io/`. Core must allow the destination through
`CORS_ORIGINS`. With `STRIPE_ENABLED=false`, billing reads remain available
and commercial mutations report that billing is disabled.

The organization-scoped `billing/packages` endpoint supplies purchasable
packages with a name and exact plan/SKU versions and quantities. The app
shows these offers without prices. Subscribe creates a checkout session;
Switch package submits the selected key and version to the subscription
update endpoint. A package replaces the plan and all purchased items with
its exact composition. Independent grants are preserved. Both actions
require confirmation and an idempotency key. Returning from checkout does
not grant entitlements; refresh after the verified payment notification.
The shipped Core catalog has no paid packages. The UI shows an empty
catalog message until offers are published on the server.
Package cards and confirmations show the package version and its exact
component versions. Checkout links are cleared when the server-provided
`expires_at` deadline passes. Select the package again to request a new
session. Portal links do not use a checkout deadline.

Add-ons lists catalog products, SKU allowances, purchased quantities, total
assigned quantities, usage, reservations, and installation state. Catalog
products with multiple active SKU versions offer the latest version of each
key. Organization installations remain visible even when a product leaves
the catalog. Billing quantities change only subscription items; independent
grants are preserved. Changes keep every other subscription item in the
desired snapshot submitted with an idempotency key. Core resolves the plan
and SKU keys to their latest active versions when applying a purchase.

Subscription changes require confirmation. Core's response does not apply
new allowances optimistically. Refresh after Stripe confirms payment to
read the effective subscription and entitlements. Pending payment blocks
further quantity edits. Stripe owns amounts, currencies, proration and tax;
the client does not calculate or display a fabricated price.

Install or resume selects the spaces where an entitled product runs. An
empty selection applies to all spaces. Saving preserves the installation's
existing settings, because the catalog does not expose its settings schema.
Pause installation stops processing without canceling a purchased SKU.
It uses Core's pause endpoint rather than destructive uninstall, which can
require additional product-specific lifecycle decisions.

Installation state and operations live in the shared [add-on module](add-ons.md).
Controlled documents also supports explicit destructive uninstall; see the
[configuration and review workflow](controlled-documents.md).

Billing controllers discard replies after switching organizations, signing
out, closing Settings, or losing the applicable membership role. The shared
add-on manager retains state while the organization context remains valid.
Loading errors are shown per section and prevent mutations that depend on
missing data.

Run `mise run lint`, `mise run i18n`, and `mise run test:core` for the
development checks. Run the full `mise run verify` and platform e2e tasks
after the UI has been validated.
