// Foundations reference pages for the design system (#1476): Colors, Typography,
// and Icons. These render the REAL theme tokens — every value is read from
// `context.colors` (MatomeColors ThemeExtension) and `context.typography`
// (AppTypography), NOT hardcoded — so the MaterialThemeAddon's Light/Dark themes
// drive them automatically and they can never drift from the app's theme.

import 'package:flutter/material.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────

Widget colorsUseCase(BuildContext context) {
  return const _FoundationsSurface(child: _ColorTokens());
}

/// A labeled swatch grid of EVERY MatomeColors field. Each swatch reads the
/// Color from the live theme extension and derives its hex at runtime, so the
/// grid stays correct under both Light and Dark without any hardcoded values.
class _ColorTokens extends StatelessWidget {
  const _ColorTokens();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final spacing = context.spacing;

    // (name, value) drawn straight from the live extension.
    final tokens = <(String, Color)>[
      ('primary', c.primary),
      ('accent', c.accent),
      ('accentDark', c.accentDark),
      ('accentSoft', c.accentSoft),
      ('onAccent', c.onAccent),
      ('background', c.background),
      ('surface', c.surface),
      ('border', c.border),
      ('subtleFill', c.subtleFill),
      ('subtleFillStrong', c.subtleFillStrong),
      ('textPrimary', c.textPrimary),
      ('textSecondary', c.textSecondary),
      ('textMuted', c.textMuted),
      ('onTextPrimary', c.onTextPrimary),
      ('failed', c.failed),
      ('badgeWork', c.badgeWork),
      ('badgeWorkText', c.badgeWorkText),
      ('badgePersonal', c.badgePersonal),
      ('badgeIdeas', c.badgeIdeas),
      ('badgeDefault', c.badgeDefault),
      ('spaceGold', c.spaceGold),
      ('spaceGreen', c.spaceGreen),
      ('spaceBlue', c.spaceBlue),
      ('spaceOrange', c.spaceOrange),
      ('spaceRose', c.spaceRose),
      ('spacePurple', c.spacePurple),
      ('spaceTeal', c.spaceTeal),
      ('spaceRed', c.spaceRed),
    ];

    return _FoundationsHeader(
      title: 'Colors',
      subtitle:
          'MatomeColors ThemeExtension · ${tokens.length} tokens · '
          'switch the theme addon to see Light / Dark',
      child: Wrap(
        spacing: spacing.md,
        runSpacing: spacing.md,
        children: [
          for (final (name, value) in tokens) _Swatch(name: name, value: value),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.value});

  final String name;
  final Color value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final spacing = context.spacing;
    final typography = context.typography;

    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A checker backdrop so translucent fills read honestly.
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius.md),
              border: Border.all(color: colors.border),
              color: colors.surface,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius.md),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _CheckerPainter()),
                  ),
                  Container(height: 56, color: value),
                ],
              ),
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.label.copyWith(
              color: colors.textPrimary,
              letterSpacing: 0,
            ),
          ),
          Text(
            _hex(value),
            style: typography.label.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Derives an `#AARRGGBB` (or `#RRGGBB` when fully opaque) string from a Color
/// at runtime — no hardcoded hex literals anywhere.
String _hex(Color color) {
  int channel(double v) => (v * 255.0).round() & 0xff;
  final a = channel(color.a);
  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  String two(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
  final rgb = '#${two(r)}${two(g)}${two(b)}';
  return a == 0xff ? rgb : '#${two(a)}${two(r)}${two(g)}${two(b)}';
}

/// A light/dark-neutral checker pattern behind swatches so translucent fills
/// (subtleFill / subtleFillStrong) are visible rather than reading as solid.
class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 8.0;
    final light = Paint()..color = const Color(0xFFE9E9E9);
    final dark = Paint()..color = const Color(0xFFCFCFCF);
    canvas.drawRect(Offset.zero & size, light);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final odd = ((x / cell).floor() + (y / cell).floor()).isOdd;
        if (odd) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), dark);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Typography ──────────────────────────────────────────────────────────────

Widget typographyUseCase(BuildContext context) {
  return const _FoundationsSurface(child: _TypographyTokens());
}

/// One sample line per AppTypography style, each rendered with the REAL
/// `context.typography.<style>` and labeled with the style name + its
/// fontSize/fontWeight read from the live TextStyle.
class _TypographyTokens extends StatelessWidget {
  const _TypographyTokens();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = context.typography;
    final spacing = context.spacing;

    final styles = <(String, TextStyle)>[
      ('display', t.display),
      ('title', t.title),
      ('body', t.body),
      ('bodySmall', t.bodySmall),
      ('label', t.label),
    ];

    return _FoundationsHeader(
      title: 'Typography',
      subtitle: 'AppTypography ThemeExtension · ${styles.length} styles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (name, style) in styles) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name · ${_describe(style)}',
                    style: t.label.copyWith(
                      color: colors.textMuted,
                      letterSpacing: 0,
                    ),
                  ),
                  SizedBox(height: spacing.xxs),
                  Text(
                    'The quick brown fox',
                    style: style.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
          ],
        ],
      ),
    );
  }
}

/// Reads size + weight off the live TextStyle so the label never hardcodes the
/// scale.
String _describe(TextStyle style) {
  final size = style.fontSize?.toStringAsFixed(0) ?? '?';
  final weight = style.fontWeight?.value.toString() ?? 'regular';
  return '${size}px · w$weight';
}

// ─── Icons ───────────────────────────────────────────────────────────────────

Widget iconsUseCase(BuildContext context) {
  return const _FoundationsSurface(child: _IconTokens());
}

/// The curated set of icons actually USED across `apps/flutter/lib` — nav
/// destinations, file/media kinds, sync states, item/panel affordances,
/// playback, and common actions. This is the app's iconography reference, not
/// the entire Material set. Each tile shows the glyph + its `Icons.*` name.
class _IconTokens extends StatelessWidget {
  const _IconTokens();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return _FoundationsHeader(
      title: 'Icons',
      subtitle: 'App iconography · ${_appIcons.length} glyphs in active use',
      child: Wrap(
        spacing: spacing.md,
        runSpacing: spacing.md,
        children: [
          for (final (name, icon) in _appIcons)
            _IconTile(name: name, icon: icon),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.name, required this.icon});

  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final spacing = context.spacing;
    final typography = context.typography;

    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: colors.subtleFill,
              borderRadius: BorderRadius.circular(radius.md),
              border: Border.all(color: colors.border),
            ),
            child: Icon(icon, color: colors.textPrimary),
          ),
          SizedBox(height: spacing.xs),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: typography.label.copyWith(
              color: colors.textMuted,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Curated from `grep -rhoE "Icons\.[a-zA-Z0-9_]+" apps/flutter/lib` (#1476),
/// deduped and grouped by role. The `Icons.*` name label matches the grep so the
/// reference stays auditable against real usage.
const _appIcons = <(String, IconData)>[
  // Nav destinations (outline + filled selected).
  ('inbox_outlined', Icons.inbox_outlined),
  ('inbox', Icons.inbox),
  ('calendar_today_outlined', Icons.calendar_today_outlined),
  ('calendar_today', Icons.calendar_today),
  ('description_outlined', Icons.description_outlined),
  ('description', Icons.description),
  ('contacts_outlined', Icons.contacts_outlined),
  ('contacts', Icons.contacts),
  ('folder_outlined', Icons.folder_outlined),
  ('folder', Icons.folder),
  ('folder_open_outlined', Icons.folder_open_outlined),
  ('workspaces_outlined', Icons.workspaces_outlined),
  // File / media kinds.
  ('mic_none_rounded', Icons.mic_none_rounded),
  ('mic_none_outlined', Icons.mic_none_outlined),
  ('mic', Icons.mic),
  ('mic_off', Icons.mic_off),
  ('image_outlined', Icons.image_outlined),
  ('broken_image_outlined', Icons.broken_image_outlined),
  ('insert_drive_file_outlined', Icons.insert_drive_file_outlined),
  ('picture_as_pdf_outlined', Icons.picture_as_pdf_outlined),
  ('text_snippet_outlined', Icons.text_snippet_outlined),
  ('slideshow_outlined', Icons.slideshow_outlined),
  ('notes_outlined', Icons.notes_outlined),
  // Sync states.
  ('cloud_done_outlined', Icons.cloud_done_outlined),
  ('cloud_sync_outlined', Icons.cloud_sync_outlined),
  ('cloud_off_outlined', Icons.cloud_off_outlined),
  ('cloud_off', Icons.cloud_off),
  // People.
  ('person_outline', Icons.person_outline),
  ('person_add_alt_outlined', Icons.person_add_alt_outlined),
  ('people_outline', Icons.people_outline),
  ('groups_outlined', Icons.groups_outlined),
  ('business_outlined', Icons.business_outlined),
  // Item / panel actions.
  ('add', Icons.add),
  ('add_photo_alternate_outlined', Icons.add_photo_alternate_outlined),
  ('edit_outlined', Icons.edit_outlined),
  ('ios_share', Icons.ios_share),
  ('share_outlined', Icons.share_outlined),
  ('delete_outline', Icons.delete_outline),
  ('drive_file_move_outlined', Icons.drive_file_move_outlined),
  ('merge_outlined', Icons.merge_outlined),
  ('archive_outlined', Icons.archive_outlined),
  ('download_outlined', Icons.download_outlined),
  ('upload_file_outlined', Icons.upload_file_outlined),
  ('attach_file', Icons.attach_file),
  ('copy_outlined', Icons.copy_outlined),
  ('more_horiz', Icons.more_horiz),
  // Playback / capture.
  ('play_arrow_rounded', Icons.play_arrow_rounded),
  ('pause', Icons.pause),
  ('stop', Icons.stop),
  // Misc / system.
  ('close', Icons.close),
  ('check', Icons.check),
  ('arrow_back', Icons.arrow_back),
  ('chevron_right', Icons.chevron_right),
  ('expand_more', Icons.expand_more),
  ('unfold_more', Icons.unfold_more),
  ('search', Icons.search),
  ('refresh', Icons.refresh),
  ('schedule', Icons.schedule),
  ('place_outlined', Icons.place_outlined),
  ('auto_awesome', Icons.auto_awesome),
  ('settings_outlined', Icons.settings_outlined),
  ('warning_amber_rounded', Icons.warning_amber_rounded),
  ('error_outline', Icons.error_outline),
  ('grid_view_outlined', Icons.grid_view_outlined),
  ('table_rows_outlined', Icons.table_rows_outlined),
];

// ─── Shared scaffolding ──────────────────────────────────────────────────────

/// Top-aligned, scrollable surface for the foundations pages.
class _FoundationsSurface extends StatelessWidget {
  const _FoundationsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: child,
        ),
      ),
    );
  }
}

/// A title + subtitle header above a foundations grid/list.
class _FoundationsHeader extends StatelessWidget {
  const _FoundationsHeader({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: typography.title.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xxs),
        Text(
          subtitle,
          style: typography.bodySmall.copyWith(color: colors.textMuted),
        ),
        SizedBox(height: spacing.lg),
        child,
      ],
    );
  }
}
