import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_text_field.dart';
import '../../ui/loading_indicator.dart';
import '../../ui/status_badge.dart';
import 'audio_player_bar.dart';
import 'details_controller.dart';
import 'markdown_helpers.dart';

/// Which segmented tab is active.
enum DetailsTab { summary, notes, transcript }

/// Details screen (S2): audio player + 3 tabs (Summary / Notes / Transcript) +
/// markdown view/edit with insertMarkdown helpers, isDirty leave-guard, retry
/// transcription, and a more-options menu (delete / move-to-space).
///
/// Reachable as `/inbox/:id`, `/calendar/:id`, `/explore/recording/:id`.
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key, required this.id, this.embedded = false});

  final String id;

  /// When true the screen is rendered inside a desktop two-pane layout: the
  /// back affordance is dropped (there is no route to pop) and the body keeps a
  /// reading-width clamp so the notes/transcript don't sprawl across the pane.
  final bool embedded;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

/// Reading-width clamp for long-form detail content on wide panes.
const double _detailReadingMaxWidth = 720;

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  DetailsTab _tab = DetailsTab.notes;
  bool _isEditing = false;

  final TextEditingController _editController = TextEditingController();
  // The text last persisted to the stores — the isDirty baseline (mirrors RN
  // `savedTextRef.current`). Wrapped in a DirtyTracker so the comparison
  // semantics match the RN unit tests exactly.
  late DirtyTracker _dirty;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _dirty = DirtyTracker('');
    _editController.addListener(() {
      _dirty.setTranscript(_editController.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  bool get _isDirty => _dirty.isDirty;

  void _syncFromState(DetailsState state) {
    if (_initialized || state.isLoading || state.row == null) return;
    _initialized = true;
    final text = state.initialText;
    _dirty = DirtyTracker(text);
    _editController.text = text;
    // Start in edit mode when there is no content yet (parity with RN).
    _isEditing = text.isEmpty;
  }

  Future<void> _save() async {
    final controller = ref.read(detailsControllerProvider(widget.id).notifier);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.save(_editController.text);
      _dirty.save();
      if (!mounted) return;
      setState(() {});
      messenger.showSnackBar(SnackBar(content: Text(t.details.saved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.details.saveFailed)));
    }
  }

  /// insertMarkdown — ports the RN closure: wrap/prepend around the current
  /// selection, then re-focus and place the caret after the inserted prefix.
  void _insertMarkdown(String prefix, [String suffix = '']) {
    final selection = _editController.selection;
    final text = _editController.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    final next = applyInsertMarkdown(
      text,
      TextSelectionRange(start, end),
      prefix,
      suffix,
    );
    // Caret lands right after the opening prefix (before the selected slice),
    // matching the RN focus-then-reselect behaviour closely enough for editing.
    final caret = start + prefix.length;
    _editController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!_isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;

        return AppDialog(
          title: Text(t.details.unsavedTitle),
          content: Text(t.details.unsavedBody),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.details.keepEditing),
            ),
            AppTextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: colors.failed),
              child: Text(t.details.discard),
            ),
          ],
        );
      },
    );
    if (discard == true) {
      // Reset the baseline so a re-render on the way out doesn't re-trigger the
      // guard (W-02 avoidance, ported from RN).
      _dirty.discard(_editController.text);
    }
    return discard ?? false;
  }

  Future<void> _onRetry() async {
    await ref.read(detailsControllerProvider(widget.id).notifier).retry();
  }

  Future<void> _onMoreOptions() async {
    final action = await showAppBottomSheet<_MoreAction>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        final typography = context.typography;

        return AppBottomSheet(
          bottomPadding: 0,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.folder_outlined, color: colors.textSecondary),
              title: Text(t.details.moveToSpace),
              onTap: () => Navigator.of(context).pop(_MoreAction.move),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.failed),
              title: Text(
                t.details.delete,
                style: typography.bodySmall.copyWith(color: colors.failed),
              ),
              onTap: () => Navigator.of(context).pop(_MoreAction.delete),
            ),
          ],
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _MoreAction.delete:
        await _onDelete();
      case _MoreAction.move:
        await _onMove();
    }
  }

  Future<void> _onDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;

        return AppDialog(
          title: Text(t.details.deleteConfirmTitle),
          content: Text(t.details.deleteConfirmBody),
          actions: [
            AppTextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t.common.cancel),
            ),
            AppTextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: colors.failed),
              child: Text(t.details.delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final navigator = Navigator.of(context);
    // Clear dirty so the leave-guard doesn't block the post-delete pop.
    _dirty.discard(_editController.text);
    await ref.read(detailsControllerProvider(widget.id).notifier).delete();
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _onMove() async {
    final controller = ref.read(detailsControllerProvider(widget.id).notifier);
    final spaces = await controller.spaces();
    if (!mounted) return;
    final target = await showAppBottomSheet<WorkspaceRow>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        final spacing = context.spacing;
        final typography = context.typography;

        return AppBottomSheet(
          title: Text(
            t.details.moveToSpace,
            style: typography.body.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          children: [
            if (spaces.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.lg,
                  spacing.xs,
                  spacing.lg,
                  spacing.lg,
                ),
                child: Text(
                  t.spaces.empty,
                  style: typography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              )
            else
              ...spaces.map(
                (ws) => ListTile(
                  leading: Icon(
                    Icons.folder_outlined,
                    color: colors.textSecondary,
                  ),
                  title: Text(ws.name),
                  onTap: () => Navigator.of(context).pop(ws),
                ),
              ),
          ],
        );
      },
    );
    if (target == null) return;
    await controller.moveToSpace(target.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailsControllerProvider(widget.id));
    final colors = context.colors;
    final spacing = context.spacing;
    final dirtyDotOffset = -spacing.xs / spacing.xxs;
    final dirtyDotSize = spacing.xs + spacing.xs / spacing.xxs;
    _syncFromState(state);

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldLeave = await _confirmLeave();
        if (shouldLeave && mounted) {
          navigator.maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embedded,
          backgroundColor: colors.background,
          surfaceTintColor: colors.background,
          title: Text(
            state.title.isEmpty ? t.recording.title : state.title,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (!state.isLoading && !state.notFound)
              IconButton(
                icon: const Icon(Icons.more_horiz),
                tooltip: t.details.moveToSpace,
                onPressed: _onMoreOptions,
              ),
          ],
        ),
        floatingActionButton: (state.isLoading || state.notFound)
            ? null
            : FloatingActionButton(
                heroTag: 'details-save',
                onPressed: _save,
                backgroundColor: colors.accent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.check, color: colors.onAccent),
                    if (_isDirty)
                      Positioned(
                        right: dirtyDotOffset,
                        top: dirtyDotOffset,
                        child: Container(
                          width: dirtyDotSize,
                          height: dirtyDotSize,
                          decoration: BoxDecoration(
                            color: colors.failed,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.accent, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
        body: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(DetailsState state) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    if (state.isLoading) {
      return Center(child: LoadingIndicator(color: colors.accent));
    }
    if (state.notFound) {
      return Center(
        child: Text(
          t.details.notFound,
          style: typography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _detailReadingMaxWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.xs,
            spacing.md,
            spacing.xxl + spacing.xxl,
          ),
          children: [
        _MetaRow(
          badge: state.badge,
          coreId: state.coreId,
          processingStatus: state.row?.processingStatus,
        ),
        SizedBox(height: spacing.sm),
        AudioPlayerBar(source: state.audioSource),
        SizedBox(height: spacing.md),
        _SegmentedControl(
          active: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        SizedBox(height: spacing.md),
        _buildTab(state),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(DetailsState state) {
    switch (_tab) {
      case DetailsTab.summary:
        return _SummarySection(summary: state.summary);
      case DetailsTab.notes:
        return _NotesSection(
          isEditing: _isEditing,
          isProcessing: state.isProcessing,
          processingFailed: state.processingFailed,
          pendingUpload: state.pendingUpload,
          controller: _editController,
          onToggleEdit: () => setState(() => _isEditing = !_isEditing),
          onInsertMarkdown: _insertMarkdown,
          onRetry: _onRetry,
        );
      case DetailsTab.transcript:
        return _TranscriptSection(
          text: _editController.text,
          isProcessing: state.isProcessing,
        );
    }
  }
}

enum _MoreAction { delete, move }

// ─── Meta row ─────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.badge,
    required this.coreId,
    required this.processingStatus,
  });

  final String badge;
  final int? coreId;
  final String? processingStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final badgeAccent = colors.badgeColor(badge);

    // Folder/space badge and the sync-state badge sit side by side as peers.
    // Wrap so they fold onto a second line on a narrow screen rather than
    // overflowing.
    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusBadge.label(
          label: badge,
          color: badgeAccent,
          showDot: false,
          backgroundColor: badgeAccent.withValues(alpha: 0.15),
          textColor: badgeAccent,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xxs,
          ),
          borderRadius: radius.xl,
          fontSize: 12,
        ),
        StatusBadge.sync(coreId: coreId, processingStatus: processingStatus),
      ],
    );
  }
}

// ─── Segmented control ──────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.active, required this.onChanged});

  final DetailsTab active;
  final ValueChanged<DetailsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final transparent = colors.surface.withValues(alpha: 0);
    final segments = <(DetailsTab, String)>[
      (DetailsTab.summary, t.details.summary),
      (DetailsTab.notes, t.details.notes),
      (DetailsTab.transcript, t.details.transcript),
    ];
    return Container(
      padding: EdgeInsets.all(spacing.xxs),
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(radius.md),
      ),
      child: Row(
        children: segments.map((seg) {
          final selected = seg.$1 == active;
          return Expanded(
            child: GestureDetector(
              key: ValueKey('segment-${seg.$1.name}'),
              onTap: () => onChanged(seg.$1),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: spacing.xs),
                decoration: BoxDecoration(
                  color: selected ? colors.surface : transparent,
                  borderRadius: BorderRadius.circular(radius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  seg.$2,
                  style: typography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Summary section ────────────────────────────────────────────────────────

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final hasSummary = summary != null && summary!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.border),
      ),
      child: hasSummary
          ? MarkdownBody(data: summary!)
          : Text(
              t.details.noSummary,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
    );
  }
}

// ─── Notes section (markdown view/edit) ─────────────────────────────────────

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.isEditing,
    required this.isProcessing,
    required this.processingFailed,
    required this.pendingUpload,
    required this.controller,
    required this.onToggleEdit,
    required this.onInsertMarkdown,
    required this.onRetry,
  });

  final bool isEditing;
  final bool isProcessing;
  final bool processingFailed;
  final bool pendingUpload;
  final TextEditingController controller;
  final VoidCallback onToggleEdit;
  final void Function(String prefix, [String suffix]) onInsertMarkdown;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.details.notes,
              style: typography.label.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            if (processingFailed || pendingUpload)
              AppTextButton.icon(
                key: const ValueKey('details-retry'),
                onPressed: onRetry,
                icon: Icon(Icons.refresh, size: spacing.md),
                label: Text(t.common.retry),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onAccent,
                  backgroundColor: colors.accent,
                ),
              )
            else if (!isProcessing)
              AppTextButton.icon(
                key: const ValueKey('details-edit-toggle'),
                onPressed: onToggleEdit,
                icon: Icon(
                  isEditing ? Icons.visibility : Icons.edit,
                  size: spacing.md,
                ),
                label: Text(isEditing ? t.details.preview : t.details.edit),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.xs),
        if (pendingUpload)
          _PendingUploadRow(label: t.cardStatus.pendingUpload)
        else if (isProcessing)
          _ProcessingRow(label: t.recording.transcribing)
        else if (processingFailed)
          _ErrorRow(label: t.recording.transcriptionFailed)
        else if (isEditing)
          _MarkdownEditor(
            controller: controller,
            onInsertMarkdown: onInsertMarkdown,
          )
        else
          _NotesPreview(text: controller.text),
      ],
    );
  }
}

class _NotesPreview extends StatelessWidget {
  const _NotesPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final body = text.trim().isEmpty ? '*${t.details.noNotes}*' : text;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(spacing.xxs),
      child: MarkdownBody(data: body),
    );
  }
}

class _MarkdownEditor extends StatelessWidget {
  const _MarkdownEditor({
    required this.controller,
    required this.onInsertMarkdown,
  });

  final TextEditingController controller;
  final void Function(String prefix, [String suffix]) onInsertMarkdown;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(spacing.xxs),
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(radius.sm),
          ),
          child: Row(
            children: [
              _ToolbarButton(
                label: 'B',
                bold: true,
                onTap: () => onInsertMarkdown('**', '**'),
              ),
              _ToolbarButton(
                label: 'I',
                italic: true,
                onTap: () => onInsertMarkdown('*', '*'),
              ),
              _ToolbarButton(label: 'H', onTap: () => onInsertMarkdown('\n# ')),
              _ToolbarButton(label: '•', onTap: () => onInsertMarkdown('\n- ')),
              _ToolbarButton(
                label: '[ ]',
                onTap: () => onInsertMarkdown('\n- [ ] '),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.xs),
        AppTextField(
          key: const ValueKey('details-editor'),
          controller: controller,
          maxLines: null,
          minLines: 8,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: typography.body.copyWith(
            color: colors.textPrimary,
            height: 1.5,
          ),
          hint: t.details.notesPlaceholder,
          hintStyle: typography.bodySmall.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.onTap,
    this.bold = false,
    this.italic = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Expanded(
      child: InkWell(
        key: ValueKey('toolbar-$label'),
        borderRadius: BorderRadius.circular(radius.sm),
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: spacing.xxs),
          padding: EdgeInsets.symmetric(vertical: spacing.xs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(radius.sm),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: typography.label.copyWith(
              color: colors.textPrimary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Transcript section ─────────────────────────────────────────────────────

class _TranscriptSection extends StatelessWidget {
  const _TranscriptSection({required this.text, required this.isProcessing});

  final String text;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    if (isProcessing) {
      return _ProcessingRow(label: t.recording.transcribing);
    }
    return Text(
      text.trim().isEmpty ? t.recording.transcribing : text,
      style: typography.bodySmall.copyWith(
        height: 1.6,
        color: colors.textSecondary,
      ),
    );
  }
}

// ─── Shared rows ────────────────────────────────────────────────────────────

class _ProcessingRow extends StatelessWidget {
  const _ProcessingRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final inlineGap = spacing.xs + spacing.xs / spacing.xxs;
    final strokeWidth = spacing.xs / spacing.xxs;

    return Row(
      key: const ValueKey('details-processing'),
      children: [
        LoadingIndicator(
          size: spacing.md,
          strokeWidth: strokeWidth,
          color: colors.accent,
        ),
        SizedBox(width: inlineGap),
        Text(
          label,
          style: typography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _PendingUploadRow extends StatelessWidget {
  const _PendingUploadRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final inlineGap = spacing.xs + spacing.xs / spacing.xxs;

    return Row(
      key: const ValueKey('details-pending-upload'),
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: spacing.md,
          color: colors.textMuted,
        ),
        SizedBox(width: inlineGap),
        Expanded(
          child: Text(
            label,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final inlineGap = spacing.xs + spacing.xs / spacing.xxs;

    return Row(
      key: const ValueKey('details-error'),
      children: [
        Icon(
          Icons.error_outline,
          size: spacing.md + spacing.xxs,
          color: colors.failed,
        ),
        SizedBox(width: inlineGap),
        Text(label, style: typography.bodySmall.copyWith(color: colors.failed)),
      ],
    );
  }
}
