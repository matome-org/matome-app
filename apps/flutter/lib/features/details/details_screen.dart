import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../home/widgets/sync_badge.dart';
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
  const DetailsScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

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
      builder: (context) => AlertDialog(
        title: Text(t.details.unsavedTitle),
        content: Text(t.details.unsavedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.details.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.failed),
            child: Text(t.details.discard),
          ),
        ],
      ),
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
    final action = await showModalBottomSheet<_MoreAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_outlined,
                  color: AppColors.textSecondary),
              title: Text(t.details.moveToSpace),
              onTap: () => Navigator.of(context).pop(_MoreAction.move),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.failed),
              title: Text(t.details.delete,
                  style: const TextStyle(color: AppColors.failed)),
              onTap: () => Navigator.of(context).pop(_MoreAction.delete),
            ),
          ],
        ),
      ),
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
      builder: (context) => AlertDialog(
        title: Text(t.details.deleteConfirmTitle),
        content: Text(t.details.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.failed),
            child: Text(t.details.delete),
          ),
        ],
      ),
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
    final target = await showModalBottomSheet<WorkspaceRow>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(t.details.moveToSpace,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            if (spaces.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(t.spaces.empty,
                    style: const TextStyle(color: AppColors.textSecondary)),
              )
            else
              ...spaces.map(
                (ws) => ListTile(
                  leading: const Icon(Icons.folder_outlined,
                      color: AppColors.textSecondary),
                  title: Text(ws.name),
                  onTap: () => Navigator.of(context).pop(ws),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null) return;
    await controller.moveToSpace(target.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detailsControllerProvider(widget.id));
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
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
                backgroundColor: AppColors.accent,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.check, color: AppColors.textPrimary),
                    if (_isDirty)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.failed,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.accent, width: 2),
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
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (state.notFound) {
      return Center(
        child: Text(
          t.details.notFound,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _MetaRow(
          badge: state.badge,
          coreId: state.coreId,
          processingStatus: state.row?.processingStatus,
        ),
        const SizedBox(height: 12),
        AudioPlayerBar(source: state.audioSource),
        const SizedBox(height: 16),
        _SegmentedControl(
          active: _tab,
          onChanged: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 16),
        _buildTab(state),
      ],
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
    // Folder/space badge and the sync-state badge sit side by side as peers.
    // Wrap so they fold onto a second line on a narrow screen rather than
    // overflowing.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor(badge).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor(badge),
            ),
          ),
        ),
        SyncBadge(coreId: coreId, processingStatus: processingStatus),
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
    final segments = <(DetailsTab, String)>[
      (DetailsTab.summary, t.details.summary),
      (DetailsTab.notes, t.details.notes),
      (DetailsTab.transcript, t.details.transcript),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: segments.map((seg) {
          final selected = seg.$1 == active;
          return Expanded(
            child: GestureDetector(
              key: ValueKey('segment-${seg.$1.name}'),
              onTap: () => onChanged(seg.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  seg.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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
    final hasSummary = summary != null && summary!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: hasSummary
          ? MarkdownBody(data: summary!)
          : Text(
              t.details.noSummary,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              t.details.notes,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (processingFailed || pendingUpload)
              TextButton.icon(
                key: const ValueKey('details-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(t.common.retry),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.accent,
                ),
              )
            else if (!isProcessing)
              TextButton.icon(
                key: const ValueKey('details-edit-toggle'),
                onPressed: onToggleEdit,
                icon: Icon(isEditing ? Icons.visibility : Icons.edit, size: 16),
                label: Text(isEditing ? t.details.preview : t.details.edit),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
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
    final body = text.trim().isEmpty ? '*${t.details.noNotes}*' : text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(8),
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
              _ToolbarButton(
                label: 'H',
                onTap: () => onInsertMarkdown('\n# '),
              ),
              _ToolbarButton(
                label: '•',
                onTap: () => onInsertMarkdown('\n- '),
              ),
              _ToolbarButton(
                label: '[ ]',
                onTap: () => onInsertMarkdown('\n- [ ] '),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('details-editor'),
          controller: controller,
          maxLines: null,
          minLines: 8,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: t.details.notesPlaceholder,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
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
    return Expanded(
      child: InkWell(
        key: ValueKey('toolbar-$label'),
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
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
    if (isProcessing) {
      return _ProcessingRow(label: t.recording.transcribing);
    }
    return Text(
      text.trim().isEmpty ? t.recording.transcribing : text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: AppColors.textSecondary,
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
    return Row(
      key: const ValueKey('details-processing'),
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _PendingUploadRow extends StatelessWidget {
  const _PendingUploadRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('details-pending-upload'),
      children: [
        const Icon(Icons.cloud_off_outlined,
            size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary)),
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
    return Row(
      key: const ValueKey('details-error'),
      children: [
        const Icon(Icons.error_outline, size: 20, color: AppColors.failed),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.failed)),
      ],
    );
  }
}
