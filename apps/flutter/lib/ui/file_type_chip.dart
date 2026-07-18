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
///   * a policy-derived external open/download action. It never renders file
///     contents internally.
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
    this.action = FileTypeChipAction.open,
    this.state = FileTypeChipState.ready,
    this.onAction,
  });

  /// The display file name (e.g. `Q3 roadmap.pdf`).
  final String fileName;

  /// The lower-case source extension (no dot) driving the type icon. Null /
  /// unknown falls back to a generic file glyph.
  final String? extension;

  /// A pre-formatted human size (e.g. `2.4 MB`). Null renders the unknown-size
  /// placeholder rather than a blank slot.
  final String? sizeLabel;
  final FileTypeChipAction action;
  final FileTypeChipState state;
  final VoidCallback? onAction;

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
          _OpenAction(action: action, state: state, onAction: onAction),
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

enum FileTypeChipAction {
  open,
  openInApp,
  download,
  downloadWithWarning,
  unavailable,
}

enum FileTypeChipState { ready, loading, failed, disabled }

class _OpenAction extends StatelessWidget {
  const _OpenAction({
    required this.action,
    required this.state,
    required this.onAction,
  });

  final FileTypeChipAction action;
  final FileTypeChipState state;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final label = switch ((state, action)) {
      (FileTypeChipState.failed, _) => t.common.retry,
      (FileTypeChipState.disabled, _) => t.fileView.fileChip.unavailable,
      (_, FileTypeChipAction.open) => t.fileView.fileChip.open,
      (_, FileTypeChipAction.openInApp) => t.fileView.fileChip.openInApp,
      (
        _,
        FileTypeChipAction.download || FileTypeChipAction.downloadWithWarning,
      ) =>
        t.fileView.fileChip.download,
      (_, FileTypeChipAction.unavailable) => t.fileView.fileChip.unavailable,
    };
    final icon = switch ((state, action)) {
      (FileTypeChipState.disabled, _) ||
      (_, FileTypeChipAction.unavailable) => Icons.block_outlined,
      (_, FileTypeChipAction.open) => Icons.open_in_new,
      (_, FileTypeChipAction.openInApp) => Icons.launch,
      (
        _,
        FileTypeChipAction.download || FileTypeChipAction.downloadWithWarning,
      ) =>
        Icons.download_outlined,
    };
    final enabled =
        state != FileTypeChipState.loading &&
        state != FileTypeChipState.disabled &&
        action != FileTypeChipAction.unavailable &&
        onAction != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (state == FileTypeChipState.loading)
          SizedBox.square(
            dimension: typography.title.fontSize,
            child: CircularProgressIndicator(
              key: const ValueKey('file-type-chip-loading'),
              strokeWidth: spacing.xxs,
            ),
          )
        else
          TextButton.icon(
            key: const ValueKey('file-type-chip-open'),
            onPressed: enabled ? onAction : null,
            icon: Icon(icon, size: typography.label.fontSize),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor: colors.textSecondary,
              disabledForegroundColor: colors.textMuted,
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xs,
              ),
            ),
          ),
        if (state == FileTypeChipState.failed)
          Text(
            t.fileView.fileChip.openFailed,
            key: const ValueKey('file-type-chip-error'),
            style: typography.label.copyWith(color: colors.failed),
          ),
        if (action == FileTypeChipAction.downloadWithWarning)
          Container(
            constraints: BoxConstraints(maxWidth: spacing.xxl * 4),
            padding: EdgeInsets.symmetric(
              horizontal: spacing.xs,
              vertical: spacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.subtleFill,
              borderRadius: BorderRadius.circular(radius.sm),
            ),
            child: Text(
              t.fileView.fileChip.activeContentWarning,
              key: const ValueKey('file-type-chip-warning'),
              textAlign: TextAlign.end,
              style: typography.label.copyWith(color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}
