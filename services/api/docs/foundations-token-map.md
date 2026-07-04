# Foundations token-extraction map

**Wave 0 · #1868 · plan p2-core-backoffice**

This maps the Flutter design tokens to the server-side CSS variables that style
the `/admin` back-office, so the two never silently diverge.

- **Single source of truth:** `apps/flutter/lib/core/theme/app_theme.dart`
- **Server mirror (hand-maintained):** `services/api/assets/css/foundations.css`
- **Tailwind exposure:** `services/api/assets/css/app.css` (`@theme inline`)
- **Flutter live render (cross-check):**
  `apps/flutter_widgetbook/lib/foundations_stories.dart`
- **Visual drift guard:** `services/api/notebooks/foundations_catalog.livemd`

This is a **static, hand-maintained** file — there is deliberately **no code
generation pipeline**. When `app_theme.dart` changes, update the matching line
in `foundations.css` (each var carries an inline `app_theme.dart:LINE` ref) and
re-eyeball the Livebook catalog against the widgetbook.

Flutter colors are `0xAARRGGBB`. Opaque tokens map to `#RRGGBB`; the two
translucent fills map to `#RRGGBBAA`.

## MatomeColors → CSS vars (Light / Dark)

| CSS var (`--matome-*`) | Flutter field | Light value | Dark value | app_theme.dart |
|---|---|---|---|---|
| `--matome-primary` | `primary` | `#e1b346` (`_accent`) | `#b98a1f` (`_accentDark`) | 138 / 169 |
| `--matome-accent` | `accent` | `#e1b346` | `#e1b346` | 39 |
| `--matome-accent-dark` | `accentDark` | `#b98a1f` | `#b98a1f` | 40 |
| `--matome-accent-soft` | `accentSoft` | `#f6e8c0` | `#3a2d10` | 41 / 42 |
| `--matome-on-accent` | `onAccent` | `#221e16` | `#221e16` | 43 → 75 |
| `--matome-on-text-primary` | `onTextPrimary` | `#fdfcf9` | `#1a1714` | 57 / 58 |
| `--matome-background` | `background` | `#f6f4ef` | `#1a1714` | 47 / 52 |
| `--matome-surface` | `surface` | `#fdfcf9` | `#252119` | 48 / 53 |
| `--matome-border` | `border` | `#e7e2d7` | `#38322a` | 49 / 54 |
| `--matome-subtle-fill` | `subtleFill` | `#1a17120f` | `#f4f1e914` | 62 / 64 |
| `--matome-subtle-fill-strong` | `subtleFillStrong` | `#1a17121a` | `#f4f1e929` | 63 / 65 |
| `--matome-text-primary` | `textPrimary` | `#221e16` | `#f4f1e9` | 75 / 78 |
| `--matome-text-secondary` | `textSecondary` | `#585249` | `#c4bcad` | 76 / 79 |
| `--matome-text-muted` | `textMuted` | `#655d4f` | `#aaa08d` | 77 / 80 |
| `--matome-failed` | `failed` | `#b23a2e` | `#ff6b75` | 85 / 88 |
| `--matome-badge-work` | `badgeWork` | `#e1b346` | `#e1b346` | 97 / 112 |
| `--matome-badge-work-text` | `badgeWorkText` | `#8f6d2a` | `#e1b346` | 100 / 185 |
| `--matome-badge-personal` | `badgePersonal` | `#3a7150` | `#6fb180` | 103 / 114 |
| `--matome-badge-ideas` | `badgeIdeas` | `#4a6fc0` | `#7899e8` | 106 / 117 |
| `--matome-badge-default` | `badgeDefault` | `#6b7280` | `#a6adb8` | 109 / 120 |
| `--matome-space-gold` | `spaceGold` | `#c8a24e` | `#c8a24e` | 128 |
| `--matome-space-green` | `spaceGreen` | `#7e9b6e` | `#7e9b6e` | 129 |
| `--matome-space-blue` | `spaceBlue` | `#6e86a8` | `#6e86a8` | 130 |
| `--matome-space-orange` | `spaceOrange` | `#c68a5e` | `#c68a5e` | 131 |
| `--matome-space-rose` | `spaceRose` | `#bc8497` | `#bc8497` | 132 |
| `--matome-space-purple` | `spacePurple` | `#9587ae` | `#9587ae` | 133 |
| `--matome-space-teal` | `spaceTeal` | `#6fa39a` | `#6fa39a` | 134 |
| `--matome-space-red` | `spaceRed` | `#c2705f` | `#c2705f` | 135 |

**Notes**

- `onAccent` = `_textPrimary` (line 43 aliases line 75); identical in both themes.
- `onTextPrimary` maps to `_surface` (light) and `_backgroundDark` (dark).
- Dark `badgeWork` uses `_badgeWorkDark` which aliases `_badgeWork` (line 112);
  dark `badgeWorkText` uses `_badgeWorkDark` (line 185), i.e. the gold accent.
- The 8 `space*` tokens are theme-invariant (dark reuses the light values).

## AppTypography → CSS vars

`AppTypography.standard` (app_theme.dart:512). Families at lines 506–508;
`letterSpacing` (logical px in Flutter) maps to CSS `px`.

| Style | family var | `--text-*-size` | weight | line-height | tracking | app_theme.dart |
|---|---|---|---|---|---|---|
| display | `--matome-font-display` | `44px` | 700 | 1.04 | -1px | 513–520 |
| title | `--matome-font-display` | `24px` | 700 | 1.16 | -0.4px | 521–528 |
| body | `--matome-font-body` | `16px` | 400 | 1.5 | 0 | 529–535 |
| bodySmall | `--matome-font-body` | `14px` | 400 | 1.45 | 0 | 536–542 |
| label | `--matome-font-body` | `12px` | 600 | 1.25 | 0.4px | 543–550 |

- `--matome-font-display` = `Schibsted Grotesk`, `--matome-font-body` =
  `Hanken Grotesk`; both fall back to `Zen Kaku Gothic New` (JA), then
  `sans-serif`.

## AppSpacing / AppRadius / AppElevation → CSS vars

| CSS var | Flutter | value | app_theme.dart |
|---|---|---|---|
| `--matome-space-xxs … xxl` | `AppSpacing.standard` | 4 / 8 / 12 / 16 / 24 / 32 / 48 px | 379–387 |
| `--matome-radius-sm … pill` | `AppRadius.standard` | 8 / 12 / 16 / 24 / 999 px | 445–451 |
| `--matome-elevation-0 … 3` | `AppElevation.standard` | 0 / 1 / 3 / 8 | 600–605 |

Radius + elevation are theme-invariant and live in `:root` only.

## Tailwind exposure

`app.css` maps the tokens into Tailwind's theme via `@theme inline { … }` so
utilities resolve through the vars (and therefore honour `.dark`):

- colors → `bg-accent`, `text-text-primary`, `border-border`, `bg-space-gold`, …
- families → `font-display`, `font-body`
- type sizes → `text-display`, `text-title`, `text-body`, `text-body-small`, `text-label`
- spacing → `p-md`, `gap-lg`, `m-xl`, … radius → `rounded-md`, `rounded-pill`
