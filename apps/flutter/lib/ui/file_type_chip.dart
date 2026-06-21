import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../i18n/strings.g.dart';

/// FileTypeChip — the document media header for `FileView`.
///
/// A compact "file chip" promoted into the design-system layer (`lib/ui/`) so it
/// mirrors how the audio/image media headers swap into [FileView] by media kind.
/// It renders, left → right:
///   * a type icon chosen from the persisted source [extension]
///     (`original_extension`, #1449) — `.pdf` and `.md` get distinct glyphs, and
///     an unknown extension falls back to a generic file icon,
///   * the [fileName] and a [sizeLabel] (or an em-dash placeholder when the size
///     is unknown),
///   * an **"Open" affordance rendered DISABLED** with a "soon" tag — preview /
///     open is a deferred wave (#1455), so the button carries a null handler and
///     can never route into a path that does not exist yet.
///
/// Strictly presentational: it reads its theme through
/// `context.colors/spacing/radius/typography` only. The host maps the recording
/// row (name / size / extension) into these fields.
class FileTypeChip extends StatelessWidget {
  const FileTypeChip({
    super.key,
    required this.fileName,
    this.extension,
    this.sizeLabel,
  });

  /// The display file name (e.g. `Q3 roadmap.pdf`).
  final String fileName;

  /// The lower-case source extension (no dot) driving the type icon. Null /
  /// unknown falls back to a generic file glyph.
  final String? extension;

  /// A pre-formatted human size (e.g. `2.4 MB`). Null renders the unknown-size
  /// placeholder rather than a blank slot.
  final String? sizeLabel;

  /// Pure extension → icon mapping. Kept static so widget tests can assert the
  /// chosen glyph per extension without pumping the widget, and so the mapping
  /// has a single source of truth. A null / unrecognised extension maps to the
  /// generic file icon.
  static IconData iconForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'md':
      case 'markdown':
        return Icons.notes_outlined;
      case 'doc':
      case 'docx':
      case 'rtf':
      case 'odt':
        return Icons.description_outlined;
      case 'txt':
        return Icons.text_snippet_outlined;
      case 'csv':
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: const ValueKey('file-type-chip'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          _TypeIcon(extension: extension),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  key: const ValueKey('file-type-chip-name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.body.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  sizeLabel ?? t.fileView.fileChip.unknownSize,
                  key: const ValueKey('file-type-chip-size'),
                  style: typography.label.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          const _OpenSoon(),
        ],
      ),
    );
  }
}

/// The leading type-icon tile, tinted from the accent-soft surface.
class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.extension});

  final String? extension;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(radius.md),
      ),
      child: Icon(
        FileTypeChip.iconForExtension(extension),
        size: typography.title.fontSize,
        color: colors.accentDark,
      ),
    );
  }
}

/// The DISABLED "Open" affordance with a trailing "soon" tag. Open/preview is a
/// deferred wave (#1455); the button carries a null handler so it reads as
/// available-soon without routing anywhere.
class _OpenSoon extends StatelessWidget {
  const _OpenSoon();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextButton.icon(
          key: const ValueKey('file-type-chip-open'),
          // Disabled: open/preview is deferred (#1455).
          onPressed: null,
          icon: Icon(Icons.open_in_new, size: typography.label.fontSize),
          label: Text(t.fileView.fileChip.open),
          style: TextButton.styleFrom(
            foregroundColor: colors.textSecondary,
            disabledForegroundColor: colors.textMuted,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.xs,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.xxs,
          ),
          decoration: BoxDecoration(
            color: colors.subtleFill,
            borderRadius: BorderRadius.circular(radius.pill),
          ),
          child: Text(
            t.fileView.fileChip.soon,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}
