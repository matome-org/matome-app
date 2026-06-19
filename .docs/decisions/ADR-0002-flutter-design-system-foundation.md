# ADR-0002 - Flutter design-system foundation

> Status: **Accepted** | Date: 2026-06-19 | Plans: `design-system-foundation`, `flutter-design-system-enforcement`

## Context

Matome is consolidating client UI into `apps/flutter` under ADR-0001. W2.5 established the contrast-remediated Flutter token foundation, W3 burned down app and feature drift against the source guard, and W4 introduced reusable catalog coverage plus the isolated Widgetbook package at `apps/flutter_widgetbook`.

The design system now needs a stable authority model so future work does not split token values across Figma, app code, Widgetbook examples, and golden fixtures.

## Decision

Use Flutter `ThemeExtension` classes as the canonical runtime token store:

| Token family | Canonical class | Runtime source |
| --- | --- | --- |
| Color | `MatomeColors` | `apps/flutter/lib/core/theme/app_theme.dart` |
| Spacing | `AppSpacing` | `apps/flutter/lib/core/theme/app_theme.dart` |
| Radius | `AppRadius` | `apps/flutter/lib/core/theme/app_theme.dart` |
| Typography | `AppTypography` | `apps/flutter/lib/core/theme/app_theme.dart` |
| Elevation | `AppElevation` | `apps/flutter/lib/core/theme/app_theme.dart` |

The hierarchy is:

1. Code owns token values. Flutter `ThemeExtension` values are canonical for runtime behavior and documentation tables.
2. Figma owns visual intent. Figma can propose token changes, but the accepted value is the one merged in code.
3. Widgetbook owns visual verification. `apps/flutter_widgetbook` renders catalog states under light/dark themes, locales, and device frames.
4. Alchemist goldens own regression detection. Golden changes are local proof that shared widget rendering changes intentionally.

Widgetbook remains isolated in `apps/flutter_widgetbook` so catalog dependencies and generated Widgetbook files do not inflate the production app package. Build it locally with:

```bash
CHROME_EXECUTABLE=/usr/bin/chromium flutter build web -t lib/widgetbook.dart
```

Golden verification is local-only for this migration wave. No cloud CI gate is required before the legacy clients are retired, matching ADR-0001's local parity constraint.

The local enforcement command is the repo-root mise task:

```bash
mise run flutter-design-system-check
```

That task is the reviewer-facing gate. It must run Flutter analyzer, source guard, token documentation drift checks, WCAG contrast checks, shared widget goldens, UI component coverage, Widgetbook Chrome smoke, and Widgetbook web build with `CHROME_EXECUTABLE=/usr/bin/chromium`.

## Consequences

Positive:

| Area | Effect |
| --- | --- |
| Token drift | Documentation can be checked against `ThemeExtension` values rather than manually trusted. |
| Theme switching | Light and dark token sets travel through Flutter's native theme system. |
| Component review | Widgetbook provides a focused surface for shared widgets without opening product screens. |
| Regression checks | Alchemist goldens catch unintended shared-widget rendering changes locally. |

Tradeoffs:

| Area | Cost |
| --- | --- |
| Manual table updates | The README still stores the table in Markdown, so token edits must update docs and pass the doc-verification test. |
| Flutter-only binding | Legacy RN/Next token packages are not canonical during the Flutter consolidation work. |
| Local-only gate | Reviewers depend on recorded local command output until a future CI decision exists. |

## Rules

1. A new token must be added to the relevant `ThemeExtension`, `copyWith`, `lerp`, light/dark extension lists, README token table, and targeted tests.
2. A new reusable component must live under `apps/flutter/lib/ui/`, have at least one Widgetbook use case, and participate in goldens when its rendered state is a shared regression risk.
3. Feature-specific wrappers can live under their feature directory, but they must compose catalog widgets instead of duplicating token values.
4. Color tokens used for text or meaningful icons must have an explicit WCAG AA assertion for the actual foreground/background pair.
5. Widgetbook remains a verification surface, not the source of token values.
6. Golden files are review artifacts. Updating them without explaining the visual change is not sufficient evidence.
7. Product code in `lib/main.dart`, `lib/app/**`, and `lib/features/**` must not introduce hardcoded colors, Material `Colors.*`, inline typography values, ad-hoc spacing/radius/elevation/shadow literals, covered direct Material primitives, or ThemeExtension fallback defaults.
8. Widgetbook packages and imports are forbidden in production `apps/flutter`; they belong only in `apps/flutter_widgetbook`.

## Exception Policy

Exceptions are allowed only through the reviewed allowlists that the tests validate:

| Allowlist | Location | Requirements |
| --- | --- | --- |
| Source guard baseline | `apps/flutter/test/core/theme/design_system_source_guard_test.dart` | Exact rule/path/line/snippet plus owner, reason, and ISO expiry. Use only when the visual migration is unsafe in the same change. |
| Widgetbook component exemption | `apps/flutter/test/core/theme/ui_component_coverage_guard_test.dart` | Current public `lib/ui/**` widget name and documented reason of at least 12 characters. |
| Shared golden exemption | `apps/flutter/test/core/theme/ui_component_coverage_guard_test.dart` | Current public `lib/ui/**` widget name and documented reason explaining why shared rendering risk is absent. |

No broad path exclusions, permanent suppressions, or undocumented analyzer ignores are accepted as design-system exceptions. WCAG AA contrast failures for text or meaningful icons are not waived; adjust the token pair or the rendered foreground/background contract.

## Verification Gate

Before moving design-system foundation work to review, run the unified local gate from the repo root:

```bash
mise tasks
mise run flutter-design-system-check
```

The mise task must fail if the source guard fails. It is intentionally broader than the focused historical command because it also proves analyzer health, UI coverage policy, Widgetbook browser smoke, and the production web build for the catalog.

## Status Of Related Docs

`apps/flutter/lib/ui/README.md` is the operator-facing design-system reference. This ADR records why code-owned ThemeExtensions, isolated Widgetbook verification, Alchemist goldens, and local-only gates are the chosen foundation.
