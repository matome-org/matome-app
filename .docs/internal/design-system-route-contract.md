# Design-System Route Contract

This is the W0 contract for converging app routes, Widgetbook `[Pages]`, and
Widgetbook `Journeys/Mobile` + `Journeys/Desktop` without visual drift. It is documentation-only: no route
migration or new Page widgets are introduced by this file.

## Source Of Truth

`apps/flutter` owns shippable UI. `apps/flutter_widgetbook` only renders app UI
for review, using `package:matome_flutter/...` imports plus private fixtures and
provider overrides. If a Widgetbook story needs a new visual component, screen,
frame, or page, create it in `apps/flutter` first and import it into the catalog.

The dependency lattice — a layer may depend only on the layers below it, never
upward and never skipping past its allowed set:

```text
Foundations
Components/Atoms       -> Foundations
Components/Composite   -> Components/Atoms, Foundations
Screens                -> Components/Atoms, Components/Composite, Foundations
Frames                 -> Components/Atoms, Components/Composite, Foundations
Pages                  -> Frames, Screens            (NOT atoms/composite/foundations directly)
Journeys               -> Pages                      (NOT screens/frames directly)
```

Bases and composites derive from foundations; screens and frames derive from
bases and composites; pages compose screens inside frames and reach no lower;
journeys are only an ordered reference over pages. Widgetbook `[Pages]` and
`Journeys` entries import app Pages; the app never imports Widgetbook.

This lattice is enforced, not just documented:

- The Widgetbook taxonomy guard (`apps/flutter_widgetbook/tool/catalog_provenance.dart`)
  requires `Components/Atoms|Composite`, `Frames`, and `Journeys/Mobile|Desktop`,
  and forces `Pages`/`Screens`/`Frames` to use exactly one device group with no
  intermediate feature folder.
- The route/Page guard (`apps/flutter/test/app/route_page_contract_guard_test.dart`)
  fails if any `apps/flutter/lib/app/pages/**` module imports a Components layer
  (`matome_flutter/ui/...`) or Foundations (`matome_flutter/core/theme/...`)
  directly, so Pages can only reach down through Screens and Frames.

## Layer Contract

| Layer | Owner | Owns | May depend on | Must not depend on |
| --- | --- | --- | --- | --- |
| Foundations | `apps/flutter/lib/core/theme`, `core/layout`, `core/config`, `i18n` | Theme extensions, spacing/radius/type/elevation tokens, breakpoints, feature flags, localization access. | Flutter/Material primitives and package-level utilities. | App screens, routes, Widgetbook, product feature state, or visual one-offs. |
| Components/Atoms | `apps/flutter/lib/ui` unless private to one feature | Small reusable primitives such as buttons, fields, badges, cards, chips, empty/loading states, and other leaf widgets. | Foundations, Material primitives, localization strings, simple value objects. | Navigation, route params, shell/tab state, feature data loading, Widgetbook. |
| Components/Composite | `apps/flutter/lib/ui` for shared composites; `features/<feature>/widgets` for feature-private composites | Reusable assemblies of base components, domain rows, panels, pickers, and detail bodies. | Foundations, base components, feature models/controllers when feature-scoped. | Route ownership, shell frames, app-level redirects, or catalog-only behavior. |
| Screens | `apps/flutter/lib/features/**` or `apps/flutter/lib/app/screens/**` | A product surface for one user goal, including feature state, empty/error/loading states, and screen-local actions. | Foundations, components, feature providers/controllers, and navigation callbacks passed in from above. | Widgetbook imports, catalog fixtures, shell/tab chrome, or route parsing that belongs in Pages. |
| Frames | `apps/flutter/lib/app/**` or shared frame widgets in `apps/flutter/lib/ui/**` | Viewport/device chrome, shell scaffolds, page transitions, modal/dialog hosts, safe areas, and responsive slots. | Foundations, components, and child widgets supplied by Pages or router wiring. App shell frames may depend on shell metadata. | Feature fetching, domain decisions, catalog-only mocks, or concrete Page definitions unless the frame is the app shell itself. |
| Pages | `apps/flutter` only, colocated with the routed feature unless a shared app page is warranted | Canonical route targets: route params, route-level provider overrides, frame selection, and composition of one Screen/body into the correct Frame. | Frames and Screens only, plus typed route inputs and route-level provider overrides. | Components (atoms/composite) or Foundations directly — reach them only through Screens/Frames. Also Widgetbook, catalog fixtures, duplicate visual implementations, or behavior that bypasses the router/auth guard. |
| Journeys | `apps/flutter_widgetbook` as renderer-only scenario glue | Multi-step review scenarios, split by mobile and desktop viewport, that render real app Pages with private fixtures/provider overrides — an ordered reference over Pages. | App Pages and fixture data only, plus Widgetbook APIs. | Screens or Frames directly, public shippable widget classes, app source imports from Widgetbook, alternate page/screen implementations. |

## Review Rules

| Rule | Required evidence |
| --- | --- |
| New route or changed route target | Update the route inventory below in the same change. |
| New Widgetbook `[Pages]` entry | It imports a Page from `apps/flutter`; it does not define the Page in `apps/flutter_widgetbook`. |
| New Widgetbook `Journeys/Mobile` or `Journeys/Desktop` entry | It composes imported app Pages and private fixtures only. Any missing UI is added app-first. |
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
  add it to the Widgetbook 4 component registry with native docs.
- If the route belongs to a critical user process, update or add Widgetbook
  `Journeys/Mobile` and `Journeys/Desktop` entries that sequence real Pages with
  private fixtures only. Each journey flow is one component per viewport with
  ordered screen stories; do not add one aggregate journey story.
- Run `mise run flutter-design-system-check`; it enforces route/Page parity,
  Widgetbook provenance and taxonomy, smoke coverage, and the Widgetbook web
  build.
- If a route cannot have Page coverage yet, document a route-specific Deferred or
  Exempt row with an owner/reviewer, reason, and re-review trigger. Do not add a
  broad path or folder exemption.

## Exemption Criteria

Exemptions are route-specific and reviewable. Broad path or folder exemptions are
not allowed.

| Exemption type | Allowed only when | Required re-review trigger |
| --- | --- | --- |
| Legacy compatibility route | `router.dart` first attempts a canonical redirect but retains a documented fallback for unresolved old links. The fallback behavior belongs to a named UC and has route characterization coverage. | The fallback enters primary navigation, gains new behavior, or the compatibility route can be removed. |
| Flag-compiled or dark route | A const feature flag or shell policy compiles the route out of the active app, or the feature is explicitly dark. | The flag default changes, the route enters primary navigation, or the feature is scheduled for release. |
| Transition/frame-only wrapper | The route wrapper owns animation, dialog bounds, or modal presentation only, while the visual Page is named elsewhere. | The wrapper starts owning content, feature state, or route-specific business logic. |

## Route Inventory

Source: `apps/flutter/lib/app/router.dart` as of 2026-07-20.

Status values:

| Status | Meaning |
| --- | --- |
| Required | Should converge to an app-owned canonical Page and be eligible for Widgetbook `[Pages]`. |
| Deferred | No Page migration until the named flag/feature decision makes the route active again. |
| Exempt | No canonical Page target while the stated exemption remains true. |
| Compatibility | Redirect-first legacy entry point with an explicitly documented fallback; not a primary Page surface. |

| Route | Current router target | Target Page status | Target when migrated | Notes |
| --- | --- | --- | --- | --- |
| `/` | `WelcomePage` | Required | `WelcomePage` | Unauthenticated landing; Widgetbook `[Pages]` covered. |
| `/login` | `LoginPage` | Required | `LoginPage` | Auth form route; Widgetbook `[Pages]` covered. |
| `/unlock` | `UnlockPage` | Required | `UnlockPage` | Authenticated Vault gate; Widgetbook `[Pages]` covered. |
| `/signup` | `SignupPage` | Required | `SignupPage` | Auth form route; Widgetbook `[Pages]` covered. |
| `/forgot-password` | `ForgotPasswordPage` | Required | `ForgotPasswordPage` | Password-reset request; Widgetbook `[Pages]` covered. |
| `/reset-password` | `ResetPasswordPage(token)` | Required | `ResetPasswordPage` | Reset code + new password; Widgetbook `[Pages]` covered. |
| `/recording` | `RecordingPage` in a fullscreen `MaterialPage` | Required | `RecordingPage` with capture binding | The fullscreen `MaterialPage` is a Frame concern. |
| `/meeting` | `MeetingRecordingPage` in a fullscreen `MaterialPage` | Required | `MeetingRecordingPage` or `RecordingPage.meeting` | Same screen family as `/recording`, different binding. |
| `/matome/:id` | `MatomeDetailPage(id)` | Required | `MatomeDetailPage` | Primary Matome hub. |
| `/files` | `FilesPage`; root route when `!FeatureFlags.newNavShell`, shell branch when `FeatureFlags.newNavShell` | Required | `FilesPage` | One canonical Page serves both router placements. |
| `/items/audio/:id` | `fileDetailPage(context, FileDetailPage.audio(id))` | Required | `FileDetailPage.audio` | Audio file item detail variant; `fileDetailPage` is a Frame/transition wrapper. |
| `/items/image/:id` | `fileDetailPage(context, FileDetailPage.image(id))` | Required | `FileDetailPage.image` | Image file item detail variant. |
| `/items/document/:id` | `fileDetailPage(context, FileDetailPage.document(id))` | Required | `FileDetailPage.document` | Document file item detail variant. |
| `/items/video/:id` | `fileDetailPage(context, FileDetailPage.video(id))` | Required | `FileDetailPage.video` | Video file item detail variant. Video remains `item_type=file` with `media_type=video`; no separate payload table or AI DispatchJob leg. |
| `/items/text/:id` | `TextItemPage(id)` | Required | `TextItemPage` | Plain-text item detail/edit host. File-less means no file copy, hashing, presign, or byte upload; text can still request AI processing and receive a DispatchJob with body-only input. User-authored body, machine summary, AI status, and durable sync status are separate. Create/edit/delete persist through restart-safe queue states (`local_saved`, `pending_sync`/`pending_delete`, `synced`, `failed`, `conflict`) and reconcile through `POST /api/items/text` plus revision-guarded `PATCH`/`DELETE /api/items/:id/text`. |
| `/inbox` | `InboxPage` inside the shell | Required | `InboxPage` | Fixed home tab. |
| `/inbox/settings` | `SettingsPage` | Required | `SettingsPage` | Nested under the inbox branch today. |
| `/inbox/:id` | Parent-Matome redirect with `RecordingDetailScreen` fallback when local resolution returns null | Compatibility | None while legacy-only | Covered by UC-04/UC-10; fallback performs no Core relationship lookup. |
| `/calendar` | `CalendarPage` shell branch | Required | `CalendarPage` | Feature-flagged by `FeatureFlags.calendar`. |
| `/calendar/:id` | Parent-Matome redirect with `RecordingDetailScreen` fallback when local resolution returns null | Compatibility | None while legacy-only | Covered by UC-04/UC-10; route exists only with Calendar branch. |
| `/spaces` | `SpacesPage` shell branch wrapper | Required | `SpacesPage` | Feature-flagged by `FeatureFlags.spaces`. |
| `/spaces/recording/:id` | Parent-Matome redirect with `SpaceRecordingScreen` fallback when local resolution returns null | Compatibility | None while legacy-only | Covered by UC-04/UC-10; route exists only with Spaces branch. |
| `/spaces/:spaceId` | `SpaceDetailPage(spaceId)` | Required | `SpaceDetailPage` | Space detail route. |
| `/satori` | `SatoriScreen` shell branch when present | Deferred | `SatoriPage` if route is restored | Under `FeatureFlags.newNavShell` the Satori branch is compiled out and `/satori` safety-redirects home. |
| `/contacts` | `ContactsPage` shell branch | Required | `ContactsPage` | Feature-flagged by `FeatureFlags.contacts`. |
| `/contacts/:id` | `ContactDetailPage(id)` | Required | `ContactDetailPage` | Contact detail route. |

## Journey Coverage

Widgetbook `Journeys/Mobile` and `Journeys/Desktop` are review/documentation
surfaces only. They sequence the same canonical Pages listed above with explicit
catalog-local fixtures; they do not define shippable UI and they do not replace
route tests. Each journey flow is cataloged as one Widgetbook 4 component per
viewport, each screen is an ordered story inside that component, and the ordered
sequence is documented in the native docs for the journey component.

- `Journeys/Mobile/Auth` and `Journeys/Desktop/Auth` cover `/`, `/login`, and
  `/signup` with `WelcomePage`, `LoginPage`, and `SignupPage`.
  `/unlock`, `/forgot-password`, and `/reset-password` remain covered as canonical
  Widgetbook Pages but are not yet ordered steps in the Auth Journey.
- `Journeys/Mobile/Capture` and `Journeys/Desktop/Capture` cover `/recording`,
  `/inbox`, and `/matome/:id` with `RecordingPage`, `InboxPage`, and
  `MatomeDetailPage`.
- `Journeys/Mobile/Organize` and `Journeys/Desktop/Organize` cover `/inbox`,
  `/matome/:id`, and `/spaces/:spaceId` with `InboxPage`, `MatomeDetailPage`,
  and `SpaceDetailPage`.
- `Journeys/Mobile/Review` and `Journeys/Desktop/Review` cover `/files` and
  `/items/audio/:id` with `FilesPage` and `FileDetailPage.audio`; text item
  plus image/document/video detail coverage is registered under Widgetbook
  `[Pages]` rather than duplicating every media variant in the audio review
  journey.
- `Journeys/Mobile/Recovery` and `Journeys/Desktop/Recovery` cover
  `/inbox/settings`, `/inbox`, and `/files` with `SettingsPage`, `InboxPage`,
  and `FilesPage`.

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
  relevant Widgetbook component/story docs, add the smallest representative
  smoke case if the surface introduces new layout risk, then run
  `mise run flutter-design-system-check`.

## Remaining Deferred And Compatibility Routes

No Required route has pending Page/Journey migration debt. The remaining
non-Required rows are either documented redirect-first compatibility entries or
a deferred feature route with an explicit re-review trigger.

- `/inbox/:id`, `/calendar/:id`, and `/spaces/recording/:id` are Compatibility
  routes. They perform an owner-scoped local parent-Matome lookup and redirect
  when possible; missing owner/row/parent returns null and intentionally renders
  the corresponding legacy detail fallback. UC-04/UC-10 document both outcomes.
  Re-review when these old links can be removed or a fallback gains new product
  behavior that warrants a canonical Page.
- `/satori` is Deferred because `FeatureFlags.newNavShell` compiles the Satori
  branch out of the active app and safety-redirects `/satori` home. Re-review if
  the Satori route is restored, enters primary navigation, or the feature is
  scheduled for release.

## Sustainment Boundary

Do not rename existing `*Screen` classes only to satisfy naming preference. A
current `*Screen` can remain the body of a canonical Page. Future migrations must
preserve the source-of-truth rule above: app Pages own shipped UI; Widgetbook
renders those Pages and never reimplements them.
