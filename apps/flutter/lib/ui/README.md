# Matome Flutter Design System

This package is the Flutter catalog surface for Matome's shared UI. It is intentionally small: product screens consume tokens from `apps/flutter/lib/core/theme/app_theme.dart`, catalog widgets from `apps/flutter/lib/ui/`, and verification from `apps/flutter_widgetbook` plus local golden tests.

## Source Of Truth

| Layer | Owns | Does not own |
| --- | --- | --- |
| Code | Canonical token values in `MatomeColors`, `AppSpacing`, `AppRadius`, `AppTypography`, and `AppElevation` ThemeExtensions. | Visual exploration or unapproved new semantics. |
| Figma | Visual intent, component states, spacing intent, and product review language. | Runtime token values after implementation. |
| Widgetbook | Verification surface for light/dark themes, locales, device frames, and catalog state coverage. | New token values or product-only behavior. |
| Alchemist goldens | Local regression gate for shared widget rendering. | Design intent or semantic naming. |

When these disagree, update Figma intent first if the design changed, then update code-owned tokens, then update Widgetbook and goldens to verify the result.

## Token Reference

Token values are code-canonical in `apps/flutter/lib/core/theme/app_theme.dart`. The color table is verified by `apps/flutter/test/core/theme/design_system_docs_test.dart`, which reads this README and compares the rows against `ThemeExtension` values. Ratios are computed against `MatomeColors.light.surface`, `MatomeColors.dark.background`, and `MatomeColors.dark.surface`. Alpha fill rows are included for drift detection; they are not text contrast targets.

<!-- color-tokens:start -->
| Token | Light | Dark | Light surface ratio | Dark background ratio | Dark surface ratio |
| --- | --- | --- | ---: | ---: | ---: |
| `primary` | `0xFFE1B346` | `0xFFB98A1F` | 1.91:1 | 5.71:1 | 5.13:1 |
| `accent` | `0xFFE1B346` | `0xFFE1B346` | 1.91:1 | 9.13:1 | 8.20:1 |
| `accentDark` | `0xFFB98A1F` | `0xFFB98A1F` | 3.05:1 | 5.71:1 | 5.13:1 |
| `accentSoft` | `0xFFF6E8C0` | `0xFFF6E8C0` | 1.19:1 | 14.64:1 | 13.14:1 |
| `onAccent` | `0xFF221E16` | `0xFF221E16` | 16.18:1 | 1.08:1 | 1.04:1 |
| `onTextPrimary` | `0xFFFDFCF9` | `0xFF1A1714` | 1.00:1 | 1.00:1 | 1.11:1 |
| `background` | `0xFFF6F4EF` | `0xFF1A1714` | 1.07:1 | 1.00:1 | 1.11:1 |
| `surface` | `0xFFFDFCF9` | `0xFF252119` | 1.00:1 | 1.11:1 | 1.00:1 |
| `border` | `0xFFE7E2D7` | `0xFF38322A` | 1.26:1 | 1.41:1 | 1.27:1 |
| `subtleFill` | `0x0F1A1712` | `0x14F4F1E9` | 17.42:1 | 15.81:1 | 14.20:1 |
| `subtleFillStrong` | `0x1A1A1712` | `0x29F4F1E9` | 17.42:1 | 15.81:1 | 14.20:1 |
| `textPrimary` | `0xFF221E16` | `0xFFF4F1E9` | 16.18:1 | 15.81:1 | 14.20:1 |
| `textSecondary` | `0xFF585249` | `0xFFC4BCAD` | 7.53:1 | 9.47:1 | 8.51:1 |
| `textMuted` | `0xFF655D4F` | `0xFFAAA08D` | 6.33:1 | 6.90:1 | 6.20:1 |
| `failed` | `0xFFB23A2E` | `0xFFFF6B75` | 5.79:1 | 6.47:1 | 5.81:1 |
| `badgeWork` | `0xFFE1B346` | `0xFFE1B346` | 1.91:1 | 9.13:1 | 8.20:1 |
| `badgeWorkText` | `0xFF8F6D2A` | `0xFFE1B346` | 4.66:1 | 9.13:1 | 8.20:1 |
| `badgePersonal` | `0xFF3A7150` | `0xFF6FB180` | 5.60:1 | 7.03:1 | 6.32:1 |
| `badgeIdeas` | `0xFF4A6FC0` | `0xFF7899E8` | 4.73:1 | 6.39:1 | 5.74:1 |
| `badgeDefault` | `0xFF6B7280` | `0xFFA6ADB8` | 4.71:1 | 7.90:1 | 7.09:1 |
| `spaceGold` | `0xFFC8A24E` | `0xFFC8A24E` | 2.34:1 | 7.42:1 | 6.67:1 |
| `spaceGreen` | `0xFF7E9B6E` | `0xFF7E9B6E` | 3.01:1 | 5.78:1 | 5.19:1 |
| `spaceBlue` | `0xFF6E86A8` | `0xFF6E86A8` | 3.63:1 | 4.79:1 | 4.30:1 |
| `spaceOrange` | `0xFFC68A5E` | `0xFFC68A5E` | 2.84:1 | 6.12:1 | 5.49:1 |
| `spaceRose` | `0xFFBC8497` | `0xFFBC8497` | 2.97:1 | 5.85:1 | 5.26:1 |
| `spacePurple` | `0xFF9587AE` | `0xFF9587AE` | 3.22:1 | 5.40:1 | 4.85:1 |
| `spaceTeal` | `0xFF6FA39A` | `0xFF6FA39A` | 2.77:1 | 6.27:1 | 5.63:1 |
| `spaceRed` | `0xFFC2705F` | `0xFFC2705F` | 3.54:1 | 4.91:1 | 4.41:1 |
<!-- color-tokens:end -->

Non-color token ratios are `n/a` because WCAG contrast applies to rendered foreground/background color pairs, not spacing, radius, type metrics, or elevation levels.

<!-- spacing-tokens:start -->
| Token | Light | Dark | Light surface ratio | Dark background ratio | Dark surface ratio |
| --- | --- | --- | ---: | ---: | ---: |
| `spacing.xxs` | `4` | `4` | n/a | n/a | n/a |
| `spacing.xs` | `8` | `8` | n/a | n/a | n/a |
| `spacing.sm` | `12` | `12` | n/a | n/a | n/a |
| `spacing.md` | `16` | `16` | n/a | n/a | n/a |
| `spacing.lg` | `24` | `24` | n/a | n/a | n/a |
| `spacing.xl` | `32` | `32` | n/a | n/a | n/a |
| `spacing.xxl` | `48` | `48` | n/a | n/a | n/a |
<!-- spacing-tokens:end -->

<!-- radius-tokens:start -->
| Token | Light | Dark | Light surface ratio | Dark background ratio | Dark surface ratio |
| --- | --- | --- | ---: | ---: | ---: |
| `radius.sm` | `8` | `8` | n/a | n/a | n/a |
| `radius.md` | `12` | `12` | n/a | n/a | n/a |
| `radius.lg` | `16` | `16` | n/a | n/a | n/a |
| `radius.xl` | `24` | `24` | n/a | n/a | n/a |
| `radius.pill` | `999` | `999` | n/a | n/a | n/a |
<!-- radius-tokens:end -->

<!-- typography-tokens:start -->
| Token | Light | Dark | Light surface ratio | Dark background ratio | Dark surface ratio |
| --- | --- | --- | ---: | ---: | ---: |
| `typography.display` | `Schibsted Grotesk; size 44; weight w700; height 1.04; letter -1` | `Schibsted Grotesk; size 44; weight w700; height 1.04; letter -1` | n/a | n/a | n/a |
| `typography.title` | `Schibsted Grotesk; size 24; weight w700; height 1.16; letter -0.4` | `Schibsted Grotesk; size 24; weight w700; height 1.16; letter -0.4` | n/a | n/a | n/a |
| `typography.body` | `Hanken Grotesk; size 16; weight w400; height 1.5; letter default` | `Hanken Grotesk; size 16; weight w400; height 1.5; letter default` | n/a | n/a | n/a |
| `typography.bodySmall` | `Hanken Grotesk; size 14; weight w400; height 1.45; letter default` | `Hanken Grotesk; size 14; weight w400; height 1.45; letter default` | n/a | n/a | n/a |
| `typography.label` | `Hanken Grotesk; size 12; weight w600; height 1.25; letter 0.4` | `Hanken Grotesk; size 12; weight w600; height 1.25; letter 0.4` | n/a | n/a | n/a |
<!-- typography-tokens:end -->

<!-- elevation-tokens:start -->
| Token | Light | Dark | Light surface ratio | Dark background ratio | Dark surface ratio |
| --- | --- | --- | ---: | ---: | ---: |
| `elevation.level0` | `0` | `0` | n/a | n/a | n/a |
| `elevation.level1` | `1` | `1` | n/a | n/a | n/a |
| `elevation.level2` | `3` | `3` | n/a | n/a | n/a |
| `elevation.level3` | `8` | `8` | n/a | n/a | n/a |
<!-- elevation-tokens:end -->

## Component Usage

| Component | Source | Widgetbook coverage | Use when | Avoid when |
| --- | --- | --- | --- | --- |
| `PrimaryButton` | `apps/flutter/lib/ui/app_button.dart` | `[Catalog]/Buttons`, `[Shared widgets]/Auth` | A primary filled action, full-width submit, icon-leading action, or disabled primary state is needed. | A low-emphasis inline action is needed; use `AppTextButton`. |
| `AppTextButton` | `apps/flutter/lib/ui/app_button.dart` | `[Catalog]/Buttons`, card retry, dialog actions | A secondary, retry, cancel, or destructive text action is needed. | The action is the only or highest-emphasis call to action. |
| `AppTextField` | `apps/flutter/lib/ui/app_text_field.dart` | `[Catalog]/Inputs`, `[Shared widgets]/Auth` | A labeled Material text input needs Matome fill, border, hint, disabled, autofill, or submit behavior. | A form needs custom validation layout not expressible through the wrapper. Add a wrapper prop first if the pattern recurs. |
| `Avatar` | `apps/flutter/lib/ui/avatar.dart` | `[Catalog]/Avatars`, `AppCard.recording` | A circular icon, initials, progress, or status glyph needs a fixed accessible surface. | The content is not square or needs a rectangular media thumbnail. |
| `AppCard.recording` | `apps/flutter/lib/ui/app_card.dart` | `[Catalog]/Cards` states: done, pending upload, processing, failed | Rendering inbox/home recording rows with status badges, retry affordance, media icon, and sync state. | A screen needs only a generic Material card with unrelated content. |
| `AppCard.calendar` | `apps/flutter/lib/ui/app_card.dart` | `[Catalog]/Cards` calendar row | Rendering compact calendar recording rows with badge dot, status label, duration, and chevron. | The row needs recording upload/retry state; use `AppCard.recording`. |
| `StatusBadge.label` | `apps/flutter/lib/ui/status_badge.dart` | `[Catalog]/Status`, cards | Showing a short category/status label with an optional dot and explicit semantic label. | The status represents cloud/local sync; use `StatusBadge.sync`. |
| `StatusBadge.sync` | `apps/flutter/lib/ui/status_badge.dart` | `[Catalog]/Status`, recording cards | Showing cloud vs on-device sync from `coreId` and `processingStatus`. | The state is not sync-derived; use `StatusBadge.label`. |
| `showAppBottomSheet` and `AppBottomSheet` | `apps/flutter/lib/ui/app_bottom_sheet.dart` | `[Catalog]/Overlays` | Presenting safe-area action lists and short modal sheet content. | A blocking confirmation is needed; use `AppDialog`. |
| `AppDialog` | `apps/flutter/lib/ui/app_dialog.dart` | `[Catalog]/Overlays` | Confirmation or form dialogs that should inherit Matome themes and actions. | A mobile action list or non-blocking picker is needed. |
| `LoadingIndicator` | `apps/flutter/lib/ui/loading_indicator.dart` | `[Catalog]/Feedback`, auth submit, cards | Indeterminate progress at fixed sizes or inside buttons/cards. | Progress is determinate or needs custom semantics. |
| `EmptyState` | `apps/flutter/lib/ui/empty_state.dart` | `[Catalog]/Feedback` | A centered icon, title, and optional message for empty list surfaces. | The state needs actions, illustration variants, or screen-specific layout. Add props only after a second caller appears. |
| `AuthErrorBanner` | `apps/flutter/lib/features/auth/auth_widgets.dart` | `[Shared widgets]/Auth` | Showing localized auth errors above submit controls. | Error content is not auth-related. |
| `AuthSubmitButton` | `apps/flutter/lib/features/auth/auth_widgets.dart` | `[Shared widgets]/Auth` | A full-width auth submit button with a built-in loading spinner. | A non-auth primary button is needed; use `PrimaryButton`. |

## Enforcement Policy

Run the unified local gate from the repo root before review:

```bash
mise run flutter-design-system-check
```

The gate is intentionally blocking. It runs `flutter analyze`, the source guard, token documentation drift checks, WCAG contrast checks, shared widget goldens, UI component coverage, Widgetbook Chrome smoke, and the Widgetbook web build with `CHROME_EXECUTABLE=/usr/bin/chromium`.

Design-system source of truth stays in `apps/flutter/lib/core/theme/app_theme.dart` for token values and `apps/flutter/lib/ui/` for reusable widgets. Product screens in `lib/app/**` and `lib/features/**` must consume those tokens and widgets instead of introducing new visual primitives.

## Forbidden Patterns

The source guard blocks these patterns in `lib/main.dart`, `lib/app/**`, and `lib/features/**`:

| Pattern | Required replacement |
| --- | --- |
| `Color(0x...)`, `Color.fromARGB`, `Color.fromRGBO`, and `Colors.*` visual literals | Add or reuse `MatomeColors` and consume `context.colors`. |
| Inline `TextStyle` visual values such as `fontSize`, `fontWeight`, `height`, `letterSpacing`, or `color` | Use `context.typography` or theme text styles configured by the design system. |
| Ad-hoc `EdgeInsets`, `SizedBox`, widget dimensions, `BoxConstraints`, `Icon(size:)`, `BorderRadius`, `Radius`, `elevation`, or numeric `BoxShadow` values | Use `context.spacing`, `context.radius`, and `context.elevation`. |
| Direct `FilledButton`, `TextButton`, `TextField`, `Card`, `AlertDialog`, or `showModalBottomSheet` where a wrapper exists | Use `PrimaryButton`, `AppTextButton`, `AppTextField`, `AppCard`, `AppDialog`, or `showAppBottomSheet`. |
| `Theme.of(context).extension<T>() ?? ...` and `?? MatomeColors.light/dark` fallbacks | Use the design-system context helpers and fail loudly if a required extension is missing. |
| Widgetbook dependencies or `package:widgetbook` imports in `apps/flutter` | Keep Widgetbook isolated in `apps/flutter_widgetbook`. |

## Exceptions And Allowlists

Exceptions are narrow, reviewed, and time-bound. Do not bypass the gate with broad path exclusions.

| Gate | Exception rule |
| --- | --- |
| Source guard | Add to the `_baseline` in `design_system_source_guard_test.dart` only when migration is not safe in the same change. Each entry must include owner, reason, exact path/line/snippet, and an ISO expiry date. The current baseline is empty, so new entries require explicit review. |
| Widgetbook coverage | Add to `_widgetbookExemptions` in `ui_component_coverage_guard_test.dart` only for a current public `lib/ui/**` widget with a documented reason of at least 12 characters. |
| Shared golden coverage | Add to `_goldenExemptions` in `ui_component_coverage_guard_test.dart` only when the widget has no meaningful shared rendering risk, with the same documented-reason requirement. |
| Contrast | Do not waive WCAG AA failures for text or meaningful icon pairs. Adjust the token pair or add a more specific contrast assertion for the real rendered foreground/background combination. |
| Token docs | Do not hand-edit around drift. Update `app_theme.dart`, this README table, and the docs test expectation together. |

## Contribution Guide

1. Add or rename tokens only in `apps/flutter/lib/core/theme/app_theme.dart` by extending the relevant `ThemeExtension` constructor, fields, `copyWith`, `lerp`, and light/dark extension lists.
2. Update the token table in this README after changing tokens. Run `flutter test test/core/theme/design_system_docs_test.dart` from `apps/flutter`; it fails if the documented rows drift from code.
3. For color tokens that render text or icons, update `apps/flutter/test/core/theme/app_theme_contrast_test.dart` so light and dark WCAG AA checks cover the real foreground/background pair.
4. Add reusable components under `apps/flutter/lib/ui/` unless the API is feature-specific. Keep product data fetching and navigation out of catalog widgets.
5. Add a Widgetbook use case in `apps/flutter_widgetbook/lib/widgetbook.dart` for every new reusable component state. Regenerate directories if annotations change.
6. Update or add Alchemist goldens under `apps/flutter/test/goldens/` when shared widget rendering changes. The golden gate is local-only for this migration wave.
7. Before review, run the unified local gate from the repo root: `mise run flutter-design-system-check`.

## Review Checklist

| Check | Required evidence |
| --- | --- |
| Unified gate is listed | `mise tasks` includes `flutter-design-system-check` |
| Full local gate passes | `mise run flutter-design-system-check` from the repo root |
| Source guard stays blocking | `flutter test test/core/theme/design_system_source_guard_test.dart` |
| Token table matches code | `flutter test test/core/theme/design_system_docs_test.dart` |
| WCAG AA text/icon pairs still pass | `flutter test test/core/theme/app_theme_contrast_test.dart` |
| Catalog states render locally | `CHROME_EXECUTABLE=/usr/bin/chromium flutter build web -t lib/widgetbook.dart` in `apps/flutter_widgetbook` |
| Golden gate remains stable | `flutter test test/goldens/shared_widgets_golden_test.dart` |
| ADR stays current | `.docs/decisions/ADR-0002-flutter-design-system-foundation.md` |
