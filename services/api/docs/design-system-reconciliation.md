# Design-System Reconciliation — Base-tier components (W1 #1869)

Server-side HEEx base components vs the Flutter `flutter_widgetbook` base tier
(`Components/Atoms/*`). This note records **what matches** and **every accepted
deviation**, so a reviewer can trust the drift-guard catalog
(`notebooks/components_catalog.livemd`) rather than re-deriving parity by hand.

- **Flutter SSOT:** `apps/flutter/lib/ui/*.dart`, `apps/flutter/lib/features/auth/auth_widgets.dart`
- **Widgetbook source:** `apps/flutter_widgetbook/lib/widgetbook.dart` (path `Components/Atoms/*`)
- **Server port:** `lib/matome_api_web/components/matome_components.ex` + `assets/css/components.css`
- **Tokens:** `assets/css/foundations.css` (hand-mirrored from `app_theme.dart`, W0 #1868)

## Base tier ported (widgetbook atom → server component → variants)

| Widgetbook atom (path) | Flutter widget | Server component | Variants covered |
| --- | --- | --- | --- |
| PrimaryButton (Buttons) | `PrimaryButton` | `primary_button/1` | default, leading-icon, disabled |
| AppTextButton (Buttons) | `AppTextButton` | `text_button/1` | default, leading-icon, disabled |
| AuthSubmitButton (Auth) | `AuthSubmitButton` | `submit_button/1` | idle, loading (spinner), disabled |
| AppTextField (Inputs) / AuthField (Auth) | `AppTextField` / `AuthField` | `text_field/1` | label, hint, obscure (password), disabled |
| AuthErrorBanner (Auth) | `AuthErrorBanner` | `error_banner/1` | error |
| AuthNoticeBanner (Auth) | `AuthNoticeBanner` | `notice_banner/1` | notice/positive |
| EmptyState (Feedback) | `EmptyState` | `empty_state/1` | icon slot, title, optional message |
| LoadingIndicator (Feedback) | `LoadingIndicator` | `loading_indicator/1` | sm / md / lg |
| Avatar (Avatars) | `Avatar` | `avatar/1` | initials, icon; sm / md / lg |
| PeopleCluster (Relations) | `PeopleCluster` | `people_cluster/1` | overlap, +N overflow |
| StatusBadge (Status) | `StatusBadge.label` | `status_badge/1` | work / personal / ideas / default; dot toggle |
| MatomeSyncChip (Status) | `MatomeSyncChip` / `StatusBadge.sync` | `sync_chip/1` | cloud / syncing / on_device |
| MatomeChip (Relations) | `MatomeChip` | `matome_chip/1` | filed (filled), Unfiled (italic muted) |
| SpaceChip (Relations) | `SpaceChip` | `space_chip/1` | filed (outlined), Inbox (italic muted) |
| RoleChip (Relations) | `RoleChip` | `role_chip/1` | organizer / speaker / attendee |
| FileTypeChip (File view) | `FileTypeChip` | `file_type_chip/1` | name, size (+ unknown), disabled "Open · soon" |
| MatomePanelSection (Panel atoms) | `MatomePanelSection` | `panel_section/1` | label, action slot, divider toggle |
| MatomePanelRow (Panel atoms) | `MatomePanelRow` | `panel_row/1` | icon/leading, title, meta, trailing slot |
| MatomePanelAddRow (Panel atoms) | `MatomePanelAddRow` | `panel_add_row/1` | accent add affordance |

### Admin-generic additions (no widgetbook atom; task-mandated back-office needs)

| Server component | Rationale |
| --- | --- |
| `icon_button/1` | Icon-only action the admin toolbars need; styled as the icon sibling of `text_button`. |
| `select/1` | Native `<select>` in the `text_field` field family; the widgetbook has no select atom. |
| `checkbox/1` | Form checkbox in the field family; no widgetbook atom. |
| `icon/1` | Inline-SVG glyph primitive (private-ish) standing in for the Material icon font (see below). |

## What matches (token-for-token)

Every component consumes **only** `var(--matome-*)` tokens via the semantic
classes in `components.css` — the same tokens `app_theme.dart` feeds the Flutter
widgets. Directly matched: pill radius (`--matome-radius-pill`), field radius
(`--matome-radius-md`), file-chip radius (`--matome-radius-lg`), all paddings
(spacing scale), the label/body/body-small type steps, the accent/surface/border/
subtle-fill/failed/badge color roles, the outlined-vs-filled MatomeChip/SpaceChip
contrast, the role-chip 12% tint, the sync-chip color mapping
(cloud→`badge-personal`, syncing→`text-secondary`, on-device→`text-muted`), and
the submit button's `text-primary` fill / `on-text-primary` label. Light + Dark
are exercised side-by-side in the catalog and flip purely via the `.dark` token
block (no per-component dark overrides).

## Accepted deviations

1. **Icons are inline-SVG approximations, not Material glyphs.** The server has no
   Material icon font (same constraint the foundations catalog's icon inventory
   records). `icon/1` hand-draws ~15 recognizable 24×24 line glyphs with
   `currentColor` at `1em`, so icon **color and size stay token-driven** even
   though the exact glyph paths differ from Material. Glyph shape is the only
   thing that can drift; the catalog mirrors the same SVGs.

2. **Off-scale Flutter literals rounded to the nearest token.** A few Flutter
   widgets bake non-scale pixel values that have no matching foundations token;
   the server rounds them to the nearest token to stay 100% token-driven:
   - `EmptyState` title `15px` → `--matome-type-body-size` (16); message `13px` →
     `--matome-type-body-small-size` (14).
   - `Avatar` default `36px` → `md` = `--matome-space-xl` (32); sizes map to the
     spacing scale (sm 24 / md 32 / lg 48).
   - `LoadingIndicator` sizes map to spacing tokens (sm `md`=16 / md `lg`=24 /
     lg `xl`=32).
   - `MatomePanelSection` label letter-spacing `0.6` → `--matome-type-label-tracking`
     (0.4); status-badge dot `6px` → `--matome-space-xxs` (4).

3. **Structural hairline/stroke widths use raw `px`.** Foundations has no
   border-width or stroke token (it mirrors `app_theme.dart`, which uses Flutter's
   default `BorderSide` width `1.0`). Borders use `1px`, the people-cluster ring
   `2px`, and the spinner ring `2px`/`3px`. These are non-scale structural
   geometry, not design values — and W0's `app.css` (`.admin-empty`) already sets
   the `border: 1px solid var(--matome-border)` precedent. All color still comes
   from tokens.

4. **Catalog mirrors class markup, not the compiled components.** The standalone
   Livebook can't load the compiled app, so — like `foundations_catalog.livemd` —
   `components_catalog.livemd` emits the SAME semantic classes over the SAME
   `components.css`. The class contract is the shared drift surface; the `icon/1`
   SVG set is duplicated in the notebook and must be kept in sync when glyphs
   change (called out in the notebook).

5. **Sync chip follows `MatomeSyncChip`, not `StatusBadge.sync`.** Both exist in
   Flutter; the canonical rollup chip (`MatomeSyncChip`: `subtle-fill` background
   + colored icon/label) was chosen. `StatusBadge.sync`'s alternative
   12%-alpha-background treatment is intentionally not ported (single chip idiom).

## Deliberately deferred (out of the base/atom tier — later waves)

These are **not** base atoms (they sit under `Components/Composite/*`,
`[Screens]`, `[Layouts]`, or `[Flows]` in the widgetbook) and are out of scope
for W1; listed here so coverage is honest:

- **Composite cards/details:** `AppCard` (+ calendar/done/failed/processing/
  pending states), `AudioPlayerBar`, `MatomeDetailPanel` (assembled), `FileView`,
  `InboxItemCard`, `ContactTile`, `ContactDetail`.
- **Menus / bars / overlays:** `FileActionsMenu`, `MatomeActionsMenu`,
  `FilesBulkBar`, `FilesUndoBar`, `MatomeAddFab`, `AppBottomSheet`, `AppDialog`.
- **Tables / grids / navigation:** `MatomeTable` (and table-cell primitives),
  `FilesTable`, `FilesGrid`, `FilesScreen`, `FilesScopeFilter`,
  `MasterDetailScaffold`, `MatomeSidebar`, `MatomeBottomDock`, `RelationshipPicker`.
- **Sync/space composites:** `SpaceSyncChip`, `SpaceSyncChoice`, `SpaceSyncTile`.
- **Frames / pages / flows:** `PhoneFrame` / `WindowFrame` / `AuthPageFrame` /
  `RouteFrame`, all `[Screens]` pages, and the `[Flows]` walkthroughs.

Table-cell primitives specifically (called out in the admin-priority list) are
deferred with `MatomeTable`, its composite owner — there is no standalone
table-cell atom in the widgetbook to port in isolation.
