# Design-System Route Contract

This is the W0 contract for converging app routes, Widgetbook `[Pages]`, and
Widgetbook `[Journeys]` without visual drift. It is documentation-only: no route
migration or new Page widgets are introduced by this file.

## Source Of Truth

`apps/flutter` owns shippable UI. `apps/flutter_widgetbook` only renders app UI
for review, using `package:matome_flutter/...` imports plus private fixtures and
provider overrides. If a Widgetbook story needs a new visual component, screen,
frame, or page, create it in `apps/flutter` first and import it into the catalog.

The production import direction is:

```text
Foundations -> Components/Base -> Components/Composite -> Screens -> Pages -> Router
                                  Frames -----------^           ^
Widgetbook [Pages] and [Journeys] import app Pages; the app never imports Widgetbook.
```

## Layer Contract

| Layer | Owner | Owns | May depend on | Must not depend on |
| --- | --- | --- | --- | --- |
| Foundations | `apps/flutter/lib/core/theme`, `core/layout`, `core/config`, `i18n` | Theme extensions, spacing/radius/type/elevation tokens, breakpoints, feature flags, localization access. | Flutter/Material primitives and package-level utilities. | App screens, routes, Widgetbook, product feature state, or visual one-offs. |
| Components/Base | `apps/flutter/lib/ui` unless private to one feature | Small reusable primitives such as buttons, fields, badges, cards, chips, empty/loading states, and other leaf widgets. | Foundations, Material primitives, localization strings, simple value objects. | Navigation, route params, shell/tab state, feature data loading, Widgetbook. |
| Components/Composite | `apps/flutter/lib/ui` for shared composites; `features/<feature>/widgets` for feature-private composites | Reusable assemblies of base components, domain rows, panels, pickers, and detail bodies. | Foundations, base components, feature models/controllers when feature-scoped. | Route ownership, shell frames, app-level redirects, or catalog-only behavior. |
| Screens | `apps/flutter/lib/features/**` or `apps/flutter/lib/app/screens/**` | A product surface for one user goal, including feature state, empty/error/loading states, and screen-local actions. | Foundations, components, feature providers/controllers, and navigation callbacks passed in from above. | Widgetbook imports, catalog fixtures, shell/tab chrome, or route parsing that belongs in Pages. |
| Frames | `apps/flutter/lib/app/**` or shared frame widgets in `apps/flutter/lib/ui/**` | Viewport/device chrome, shell scaffolds, page transitions, modal/dialog hosts, safe areas, and responsive slots. | Foundations, components, and child widgets supplied by Pages or router wiring. App shell frames may depend on shell metadata. | Feature fetching, domain decisions, catalog-only mocks, or concrete Page definitions unless the frame is the app shell itself. |
| Pages | `apps/flutter` only, colocated with the routed feature unless a shared app page is warranted | Canonical route targets: route params, route-level provider overrides, frame selection, and composition of one Screen/body into the correct Frame. | Foundations, frames, screens, components, feature providers, and typed route inputs. | Widgetbook, catalog fixtures, duplicate visual implementations, or behavior that bypasses the router/auth guard. |
| Journeys | `apps/flutter_widgetbook` as renderer-only scenario glue | Multi-step review scenarios that render real app Pages with private fixtures/provider overrides. | App Pages, app Frames only through those Pages, fixture data, Widgetbook APIs. | Public shippable widget classes, app source imports from Widgetbook, alternate page/screen implementations. |

## Review Rules

| Rule | Required evidence |
| --- | --- |
| New route or changed route target | Update the route inventory below in the same change. |
| New Widgetbook `[Pages]` entry | It imports a Page from `apps/flutter`; it does not define the Page in `apps/flutter_widgetbook`. |
| New Widgetbook `[Journeys]` entry | It composes imported app Pages and private fixtures only. Any missing UI is added app-first. |
| New exemption | It names the route, owner/reviewer, reason, exact trigger for re-review, and why there is no independent visual Page. |
| Naming conflict | Prefer the layer contract over suffix history. A current `*Screen` can be the body of a canonical Page; do not rename only for suffix alignment. |

## New Route Checklist

Every new user-visible route must keep app and catalog coverage in one change.

- Create or reuse an app-owned canonical `*Page` in `apps/flutter/lib`; the Page
  owns route params, route-level provider overrides, and frame/screen
  composition.
- Point `router.dart` at that Page. If the route needs only a transition or
  fullscreen wrapper, keep that wrapper as a Frame concern around the Page.
- Update the route inventory in this document and the route/Page guard evidence
  in `apps/flutter/test/app/route_page_contract_guard_test.dart`.
- Add Widgetbook `[Pages]` coverage typed against the imported app Page and
  regenerate `apps/flutter_widgetbook/lib/widgetbook.directories.g.dart`.
- If the route belongs to a critical user process, update or add a Widgetbook
  `[Journeys]` entry that sequences real Pages with private fixtures only.
- Run `mise run flutter-design-system-check`; it enforces route/Page parity,
  Widgetbook provenance, generated-directory freshness, smoke coverage, and the
  Widgetbook web build.
- If a route cannot have Page coverage yet, document a route-specific Deferred or
  Exempt row with an owner/reviewer, reason, and re-review trigger. Do not add a
  broad path or folder exemption.

## Exemption Criteria

Exemptions are route-specific and reviewable. Broad path or folder exemptions are
not allowed.

| Exemption type | Allowed only when | Required re-review trigger |
| --- | --- | --- |
| Redirect-only legacy route | `router.dart` redirects before the fallback builder should render, and the fallback has no independent product surface. | Redirect is removed, redirect can return null in normal operation, or the fallback becomes user-visible. |
| Flag-compiled or dark route | A const feature flag or shell policy compiles the route out of the active app, or the feature is explicitly dark. | The flag default changes, the route enters primary navigation, or the feature is scheduled for release. |
| Transition/frame-only wrapper | The route wrapper owns animation, dialog bounds, or modal presentation only, while the visual Page is named elsewhere. | The wrapper starts owning content, feature state, or route-specific business logic. |

## Route Inventory

Source: `apps/flutter/lib/app/router.dart` as of 2026-06-29.

Status values:

| Status | Meaning |
| --- | --- |
| Required | Should converge to an app-owned canonical Page and be eligible for Widgetbook `[Pages]`. |
| Deferred | No Page migration until the named flag/feature decision makes the route active again. |
| Exempt | No canonical Page target while the stated exemption remains true. |

| Route | Current router target | Target Page status | Target when migrated | Notes |
| --- | --- | --- | --- | --- |
| `/` | `WelcomePage` | Required | `WelcomePage` | Unauthenticated landing; Widgetbook `[Pages]` covered. |
| `/login` | `LoginPage` | Required | `LoginPage` | Auth form route; Widgetbook `[Pages]` covered. |
| `/signup` | `SignupPage` | Required | `SignupPage` | Auth form route; Widgetbook `[Pages]` covered. |
| `/recording` | `RecordingPage` in a fullscreen `MaterialPage` | Required | `RecordingPage` with capture binding | The fullscreen `MaterialPage` is a Frame concern. |
| `/meeting` | `MeetingRecordingPage` in a fullscreen `MaterialPage` | Required | `MeetingRecordingPage` or `RecordingPage.meeting` | Same screen family as `/recording`, different binding. |
| `/matome/:id` | `MatomeDetailPage(id)` | Required | `MatomeDetailPage` | Primary Matome hub. |
| `/files` | `FilesPage`; root route when `!FeatureFlags.newNavShell`, shell branch when `FeatureFlags.newNavShell` | Required | `FilesPage` | One canonical Page serves both router placements. |
| `/recording/detail/:id` | `fileDetailPage(context, FileDetailPage.audio(id))` | Required | `FileDetailPage.audio` | `fileDetailPage` is a Frame/transition wrapper. |
| `/recording/image/:id` | `fileDetailPage(context, FileDetailPage.image(id))` | Required | `FileDetailPage.image` | Image item detail variant. |
| `/recording/document/:id` | `fileDetailPage(context, FileDetailPage.document(id))` | Required | `FileDetailPage.document` | Document item detail variant. |
| `/inbox` | `InboxPage` inside the shell | Required | `InboxPage` | Fixed home tab. |
| `/inbox/settings` | `SettingsPage` | Required | `SettingsPage` | Nested under the inbox branch today. |
| `/inbox/:id` | Legacy redirect to `/matome/:matomeId` with `RecordingDetailScreen` fallback | Exempt | None while redirect-only | Re-review if legacy recording deep links stop redirecting. |
| `/calendar` | `CalendarPage` shell branch | Required | `CalendarPage` | Feature-flagged by `FeatureFlags.calendar`. |
| `/calendar/:id` | Legacy redirect to `/matome/:matomeId` with `RecordingDetailScreen` fallback | Exempt | None while redirect-only | Re-review if calendar recording deep links stop redirecting. |
| `/spaces` | `SpacesPage` shell branch wrapper | Required | `SpacesPage` | Feature-flagged by `FeatureFlags.spaces`. |
| `/spaces/recording/:id` | Legacy redirect to `/matome/:matomeId` with `SpaceRecordingScreen` fallback | Exempt | None while redirect-only | Re-review if space recording deep links stop redirecting. |
| `/spaces/:spaceId` | `SpaceDetailPage(spaceId)` | Required | `SpaceDetailPage` | Space detail route. |
| `/satori` | `SatoriScreen` shell branch when present | Deferred | `SatoriPage` if route is restored | Under `FeatureFlags.newNavShell` the Satori branch is compiled out and `/satori` safety-redirects home. |
| `/contacts` | `ContactsPage` shell branch | Required | `ContactsPage` | Feature-flagged by `FeatureFlags.contacts`. |
| `/contacts/:id` | `ContactDetailPage(id)` | Required | `ContactDetailPage` | Contact detail route. |

## Journey Coverage

Widgetbook `[Journeys]` are review/documentation surfaces only. They sequence the
same canonical Pages listed above with explicit catalog-local fixtures; they do
not define shippable UI and they do not replace route tests.

- `[Journeys]/Auth` covers `/`, `/login`, and `/signup` with `WelcomePage`,
  `LoginPage`, and `SignupPage`.
- `[Journeys]/Capture` covers `/recording`, `/inbox`, and `/matome/:id` with
  `RecordingPage`, `InboxPage`, and `MatomeDetailPage`.
- `[Journeys]/Organize` covers `/inbox`, `/matome/:id`, and `/spaces/:spaceId`
  with `InboxPage`, `MatomeDetailPage`, and `SpaceDetailPage`.
- `[Journeys]/Review` covers `/files` and `/recording/detail/:id` with
  `FilesPage` and `FileDetailPage.audio`.
- `[Journeys]/Recovery` covers `/inbox/settings`, `/inbox`, and `/files` with
  `SettingsPage`, `InboxPage`, and `FilesPage`.

## Visual Verification Matrix

The first Page/Journey visual signal is intentionally small and stable. The
design-system gate runs `apps/flutter_widgetbook/test/widgetbook_smoke_test.dart`
on Chrome, which renders a bounded matrix rather than capturing a screenshot for
every route.

- Component-level pixel baselines stay in
  `apps/flutter/test/goldens/shared_widgets_golden_test.dart`, already covering
  light/dark themes and English/Japanese locales.
- Page/Journey smoke covers representative route surfaces: Auth mobile,
  Auth desktop locale stress, Files desktop, Settings locale stress, Capture
  journey, and Recovery journey.
- Theme/locale coverage is bounded to light English and dark Japanese for the
  Page/Journey smoke; add another variant only when a routed surface has known
  theme or text-layout risk.
- The Widgetbook smoke is a runtime visual signal: it catches missing providers,
  broken generated directories, layout assertions, and locale/theme crashes. It
  is not a pixel-perfect replacement for the shared widget goldens.
- Flake policy: if this smoke flakes, first remove timing, animation, backend,
  device, or platform-channel dependency from the fixture. Do not widen pump
  delays or skip cases without documenting the route, trigger, owner, and re-add
  condition here.
- Update workflow: when adding or changing a canonical Page/Journey, update the
  relevant Widgetbook use case, regenerate `widgetbook.directories.g.dart`, add
  the smallest representative smoke case if the surface introduces new layout
  risk, then run `mise run flutter-design-system-check`.

## Remaining Deferred And Exempt Routes

No Required route has pending Page/Journey migration debt. The remaining
non-Required rows are acceptable because they are either redirect-only legacy
entry points or a deferred feature route with an explicit re-review trigger.

- `/inbox/:id` is Exempt while legacy recording deep links redirect to the parent
  Matome before the fallback `RecordingDetailScreen` should render. Re-review if
  that redirect is removed, can normally return null, or the fallback becomes a
  user-visible product surface.
- `/calendar/:id` is Exempt for the same redirect-only legacy recording-link
  reason. Re-review if the redirect contract changes.
- `/spaces/recording/:id` is Exempt for the same redirect-only legacy
  recording-in-space reason. Re-review if the fallback `SpaceRecordingScreen`
  becomes visible in normal app flow.
- `/satori` is Deferred because `FeatureFlags.newNavShell` compiles the Satori
  branch out of the active app and safety-redirects `/satori` home. Re-review if
  the Satori route is restored, enters primary navigation, or the feature is
  scheduled for release.

## Sustainment Boundary

Do not rename existing `*Screen` classes only to satisfy naming preference. A
current `*Screen` can remain the body of a canonical Page. Future migrations must
preserve the source-of-truth rule above: app Pages own shipped UI; Widgetbook
renders those Pages and never reimplements them.
