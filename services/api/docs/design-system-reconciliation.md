# Design-System Reconciliation — Base + composite components (W1 #1869, W2 #1870)

Server-side HEEx components vs the Flutter `flutter_widgetbook`. This note
records **what matches** and **every accepted deviation**, so a reviewer can
trust the drift-guard catalogs (`notebooks/components_catalog.livemd` for the
base tier, `notebooks/composites_catalog.livemd` for the composite tier) rather
than re-deriving parity by hand.

- **Flutter SSOT:** `apps/flutter/lib/ui/*.dart`, `apps/flutter/lib/features/**`, `apps/flutter/lib/features/auth/auth_widgets.dart`
- **Widgetbook source:** `apps/flutter_widgetbook/lib/widgetbook.dart` (`Components/Atoms/*`, `[Molecules]`, `[Screens]`, graduated proposals)
- **Server port:** `lib/matome_api_web/components/matome_components.ex` (base) + `matome_composites.ex` (composite) + `assets/css/{components,composites}.css`
- **Tokens:** `assets/css/foundations.css` (hand-mirrored from `app_theme.dart`, W0 #1868)

The base tier (W1) is documented below; the **composite tier (W2)** is a new
section farther down. The composite tier is assembled entirely FROM the base
atoms — no composite re-styles an atom from scratch.

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

# Composite tier (W2 #1870)

Server-side HEEx composites (`matome_composites.ex` + `composites.css`) vs the
Flutter composite widgets. Each composite is **assembled from the W1 base
atoms** — it only adds layout scaffolding. Catalog: `composites_catalog.livemd`
(Light + Dark, every variant).

## Composite tier ported (Flutter widget → server composite → W1 atoms composed)

| Flutter widget (file) | Server composite | Variants covered | W1 atoms composed |
| --- | --- | --- | --- |
| `MatomeTable` / `FilesTable` (`features/**/widgets`) | `data_table/1` (+ `table_primary_cell`, `table_count`) | sortable header (active asc/desc), selection + bulk bar, active-row tint, empty state; column-slot parameterized for both tables | `checkbox` (box), `icon`, `icon_button`, `empty_state` |
| `MatomeSidebar` (`features/shell`) | `nav_sidebar/1` | expanded / collapsed rail, active destination, add button, settings + account footer | `avatar`, `icon`, `icon_button` |
| `MatomeBottomDock` (`features/shell`) | `nav_dock/1` | icon-only items, active tint, settings avatar | `avatar`, `icon` |
| `MatomeAddFab` (`features/shell`) | `nav_fab/1` | accent add FAB | `icon` |
| `MasterDetailScaffold` (`ui`) | `master_detail/1` | master + detail/empty slots, optional close bar | `icon_button` |
| `InboxItemCard` (`ui`) | `list_row/1` | leading icon/slot, kind tag, meta, footer + trailing slots | `icon` (+ slots take `sync_chip`, etc.) |
| `ContactTile` (`features/contacts`) | `contact_tile/1` | tinted spaces-band swatch, name, optional notes, chevron | `icon` |
| `AppCard` (`ui`) | `app_card/1` | matome (summary + meta strip + trailing), calendar (badge dot + status badge + duration), recording (done/processing/failed/pending) (+ `place_chip`, `meta_token`) | `status_badge`, `sync_chip`, `loading_indicator`, `icon`, `icon_button`, `text_button` |
| `MatomeDetailPanel` (`ui`) | `detail_panel/1` | fixed IA: header, Items, People, Space (filed vs inbox), Notes, Share | `panel_section`, `panel_row`, `panel_add_row`, `sync_chip`, `avatar`, `text_button`, `icon_button` |
| `ContactDetail` (`features/contacts`, proposal) | `contact_detail/1` (+ `info_row`) | header sync chip + actions; identity column (info rows / notes); relations column (role chips, space chips, files); sparse muted placeholders | `avatar`, `sync_chip`, `role_chip`, `space_chip`, `panel_section`, `panel_row`, `text_button`, `icon_button` |
| `FilesGrid` `_FileTile` (`features/files`, proposal) | `file_card/1` | kind-tinted preview + audio duration tag; name/size·when; matome + sync + space + people relation rows; filed vs unfiled | `matome_chip`, `space_chip`, `sync_chip`, `people_cluster`, `icon` |

### Graduated proposals (widgetbook proposal stories → server composite)

The proposal mocks were deleted at convergence (DR-000..004); the proposal
stories render the real widgets, so parity is against those:

- **"matome table"** / **"files table"** → `data_table/1`.
- **"nav rework"** → `nav_sidebar/1` + `nav_dock/1` + `nav_fab/1`.
- **"contact detail"** → `contact_detail/1`.
- **"files grid"** → `file_card/1`.

## Composite-tier accepted deviations

1. **Static render, not interactive.** These are stateless HEEx function
   components: sort direction, selection set, hover/focus rings, menu anchors,
   and the FAB/add popover MENUS are rendered as MARKUP (classes + affordances),
   not wired behaviour. The admin data-LiveViews (W6/W7) own the events. So the
   Flutter `_RowFocus` keyboard model (`x`=select, Enter/Space=open, 2px focus
   ring), `MenuAnchor` popovers, and the undo-bar timers are represented by their
   resting-state markup only. `data_table` exposes `selected` / `active_id` /
   `sort_key` / `sort_dir` as inputs the LiveView drives.

2. **Fixed structural widths use raw `px`.** `composites.css` sets the
   table secondary-column widths (`--when 64`, `--items 128`, `--people 84`,
   `--space 132`, `--sync 116`, `--size 72`, `--matome 148`; checkbox/actions =
   spacing tokens) and the sidebar rail widths (`248` expanded / `76` collapsed)
   as literal `px`. These mirror the Flutter geometry constants verbatim
   (`matome_table.dart` L99 / `files_table.dart` L36; `kSidebarExpandedWidth` /
   `kSidebarRailWidth` in `matome_nav.dart`) — they are structural layout
   geometry, NOT design-scale values, and there is no foundations token for them
   (same class as the W1 hairline `1px` deviation). The flexible primary column
   and all paddings/gaps stay token-driven.

3. **Spaces-band swatch tints are inline `style`, token-referenced.** The
   contact-tile swatch and file-card previews tint a spaces-band token at a low
   alpha via `color-mix(in srgb, var(--matome-space-*) N%, transparent)`. The
   tile swatch computes the token name at runtime (`swatch_style/1`), so it lands
   as an inline `style` attribute — but the value is a `var(--matome-*)` token,
   not a hardcoded color. The `N%` is an opacity, not a design value.

4. **`AudioPlayerBar` peek, `FilesTable` size-sort, deep menus dropped.** The
   recording card omits the inline audio-player scrubber (deferred with the
   player); `data_table`'s size column is a plain sort header (Flutter's
   size-sort is a documented no-op → recency); per-row/action MENUS render as a
   single `more_horiz` `icon_button` affordance, not the expanded menu.

5. **Icon set extended (additively).** `icon/1` gained ~30 composite glyphs
   (sort arrows, `more_horiz`, `menu`/`menu_open`, `settings`, `chevron_right`,
   `expand_more`, media/`schedule`/`group`/`warning`/`refresh`, `mail`/`phone`/
   `business`, `download`/`edit`/`archive`/`delete`/`drive_file_move`). Same
   inline-SVG approximation caveat as the base tier (deviation #1 above): glyph
   shape may differ from Material; color + size stay token-driven. The composite
   catalog duplicates the SVG set and must be kept in sync.

## Deliberately deferred (still out of scope — later waves)

Listed so composite coverage is honest. These are interaction-/overlay-heavy or
belong to feature screens, and the admin data-LiveViews do not need them as
static primitives:

- **Overlays / menus / bars (interactive):** `FileActionsMenu`,
  `MatomeActionsMenu`, the sidebar/FAB add MENUS, `FilesUndoBar` timer,
  `AppBottomSheet`, `AppDialog`, `RelationshipPicker`.
- **Media:** `AudioPlayerBar` scrubber, `FileView` (full assembled file screen).
- **Sync/space composites:** `SpaceSyncChoice`, `SpaceSyncTile`,
  `FilesScopeFilter` (the base `SpaceChip`/`sync_chip` cover the chip surface).
- **Screens / frames / flows:** `FilesScreen` and other `[Screens]` pages,
  `PhoneFrame` / `WindowFrame` / `AuthPageFrame` / `RouteFrame`, and `[Flows]`.

`FilesTable` shares `data_table/1` (same geometry/machinery), so it is covered
rather than deferred; only its interactive layer is deferred per deviation #1.
