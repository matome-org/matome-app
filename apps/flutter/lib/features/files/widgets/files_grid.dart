// The visual "Grid" take on the Files view (DR-000 / DR-003, #1465). Tiles with
// a kind preview block, name, size·when meta, the THREE independent relation
// indicators (matome / space / people) plus the sync rollup, an audio duration
// tag, and a per-tile selection checkbox + overflow menu on hover/selection.
//
// CONVERGENCE: graduated from the approved `matome_files_proposal.dart` mockup.
// The single implementation the `/files` host and the Widgetbook stories render.
//
// Strictly presentational: takes a list of [FileRow] view-models and emits the
// typed callbacks from `files_view_shared.dart` ([onOpen], [onSelectionChanged],
// [onBulk]). No providers, no navigation, no DB. Owns only EPHEMERAL UI state
// (the live selection + the in-grid undo stash).
//
// DATA REALITY (#1461, flagged honestly):
//   * size is NOT persisted → [FileRow.sizeLabel] is null → a muted dash, never
//     a fabricated size.
//   * people are MATOME-MEDIATED (no per-file contact edge) → [FileRow.contacts]
//     is the file's matome's contacts, empty for an Unfiled file.

import 'package:flutter/material.dart';

import '../../../core/db/file_row.dart';
import '../../../core/db/matome_card.dart' show MatomeSyncRollup;
import '../../../core/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../../../ui/matome_chip.dart';
import '../../../ui/people_cluster.dart';
import '../../../ui/space_chip.dart';
import '../../../ui/space_sync_chip.dart';
import 'files_view_shared.dart';

/// Target tile width; the column count self-adjusts to fit (2 on phones, more on
/// wide). Component-owned layout constant, not a spacing token.
const double _kTileTarget = 200;

class FilesGrid extends StatefulWidget {
  const FilesGrid({
    super.key,
    required this.files,
    this.initialSelection = const {},
    this.onOpen,
    this.onSelectionChanged,
    this.onBulk,
  });

  /// The files to render, in master order. Undo reinserts removed tiles in this
  /// order.
  final List<FileRow> files;

  /// Files selected when the grid first mounts.
  final Set<String> initialSelection;

  final FileOpenCallback? onOpen;
  final FileSelectionCallback? onSelectionChanged;
  final FileBulkCallback? onBulk;

  @override
  State<FilesGrid> createState() => _FilesGridState();
}

class _FilesGridState extends State<FilesGrid> {
  late List<FileRow> _files = [...widget.files];
  late Set<String> _selected = {...widget.initialSelection};
  FilesUndoStash? _undo;

  @override
  void didUpdateWidget(FilesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.files, widget.files)) {
      _files = [...widget.files];
      final ids = _files.map((f) => f.id).toSet();
      _selected = _selected.intersection(ids);
      _undo = null;
    }
  }

  void _emitSelection() => widget.onSelectionChanged?.call({..._selected});

  void _toggle(String id, bool on) {
    setState(() => on ? _selected.add(id) : _selected.remove(id));
    _emitSelection();
  }

  void _remove(Set<String> ids, String message) {
    final removed = <MapEntry<int, FileRow>>[];
    for (var i = 0; i < _files.length; i++) {
      if (ids.contains(_files[i].id)) removed.add(MapEntry(i, _files[i]));
    }
    setState(() {
      final prior = {..._selected};
      _files = [
        for (final f in _files)
          if (!ids.contains(f.id)) f,
      ];
      _selected.removeAll(ids);
      _undo = FilesUndoStash(message, removed, prior);
    });
    _emitSelection();
  }

  void _restoreUndo() {
    final stash = _undo;
    if (stash == null) return;
    final next = [..._files];
    for (final e in stash.removed) {
      next.insert(e.key.clamp(0, next.length), e.value);
    }
    setState(() {
      _files = next;
      _selected = stash.priorSelection;
      _undo = null;
    });
    _emitSelection();
  }

  Future<void> _delete(Set<String> ids) async {
    final n = ids.length;
    if (await confirmDeleteFiles(context, n) && mounted) {
      _remove(ids, t.files.deletedMsg(n: n));
      widget.onBulk?.call(FileAction.delete, ids);
    }
  }

  void _move(Set<String> ids) => widget.onBulk?.call(FileAction.moveToMatome, ids);
  void _download(Set<String> ids) =>
      widget.onBulk?.call(FileAction.download, ids);

  Future<void> _fileAction(FileRow f, FileAction a) async {
    switch (a) {
      case FileAction.open:
        widget.onOpen?.call(f.id);
      case FileAction.moveToMatome:
        _move({f.id});
      case FileAction.download:
        _download({f.id});
      case FileAction.delete:
        await _delete({f.id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    if (_files.isEmpty && _undo == null) {
      return const FilesEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / _kTileTarget).floor().clamp(2, 6);
        final gap = spacing.md;
        final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selected.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: FilesBulkBar(
                  count: _selected.length,
                  onClear: () {
                    setState(() => _selected = {});
                    _emitSelection();
                  },
                  onMove: () => _move({..._selected}),
                  onDownload: () => _download({..._selected}),
                  onDelete: () => _delete({..._selected}),
                ),
              ),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final f in _files)
                  SizedBox(
                    width: tileW,
                    child: _FileTile(
                      file: f,
                      selected: _selected.contains(f.id),
                      onSelect: (on) => _toggle(f.id, on),
                      onAction: (a) => _fileAction(f, a),
                    ),
                  ),
              ],
            ),
            if (_undo != null) ...[
              SizedBox(height: spacing.sm),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(context.radius.md),
                  border: Border.all(color: colors.border),
                ),
                child: FilesUndoBar(
                  message: _undo!.message,
                  onUndo: _restoreUndo,
                  onDismiss: () => setState(() => _undo = null),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _FileTile extends StatefulWidget {
  const _FileTile({
    required this.file,
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });

  final FileRow file;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final ValueChanged<FileAction> onAction;

  @override
  State<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<_FileTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final f = widget.file;
    final vis = fileKindVisual(context, f);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onAction(FileAction.open),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(radius.lg),
            border: Border.all(
              color: widget.selected ? colors.accent : colors.border,
              width: widget.selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview block — tinted by kind, with the type glyph centered.
              // (An image would render a real thumbnail in a later pass.)
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: ColoredBox(
                      color: vis.color.withValues(alpha: 0.10),
                      child: Center(
                        child: Icon(vis.icon,
                            size: context.spacing.xl, color: vis.color),
                      ),
                    ),
                  ),
                  if (_hovered || widget.selected)
                    Positioned(
                      top: spacing.xxs,
                      left: spacing.xxs,
                      child: _TileCheckbox(
                        value: widget.selected,
                        onChanged: widget.onSelect,
                      ),
                    ),
                  if (f.duration != null)
                    Positioned(
                      right: spacing.xs,
                      bottom: spacing.xs,
                      child: _DurationTag(label: f.duration!),
                    ),
                  if (_hovered)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: FileActionsMenu(onAction: widget.onAction),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: EdgeInsets.all(spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: spacing.xxs),
                    Row(
                      children: [
                        // Size is not persisted (#1461) → a muted dash, never a
                        // fabricated size.
                        Text(
                          f.sizeLabel ?? t.files.noSize,
                          style:
                              typography.label.copyWith(color: colors.textMuted),
                        ),
                        Text(' · ',
                            style: typography.label
                                .copyWith(color: colors.textMuted)),
                        Text(
                          f.when,
                          style:
                              typography.label.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    // Matome (filled) + sync on one line; space (outlined) +
                    // people on the next — the three INDEPENDENT relations stay
                    // visually distinct and none is truncated. Sync renders as a
                    // bare dot here (not the full pill) so a long matome name
                    // keeps the line within a dense ~200dp tile (DR-003).
                    Row(
                      children: [
                        Flexible(child: MatomeChip(matome: f.matome)),
                        SizedBox(width: spacing.xs),
                        _SyncDot(rollup: f.rollup, localOnly: f.localOnly),
                      ],
                    ),
                    SizedBox(height: spacing.xxs),
                    Row(
                      children: [
                        Flexible(child: SpaceChip(space: f.space)),
                        if (f.contacts.isNotEmpty) ...[
                          SizedBox(width: spacing.xs),
                          PeopleCluster(
                              names: f.contacts, size: context.spacing.lg),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileCheckbox extends StatelessWidget {
  const _TileCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: t.files.selectFile,
      checked: value,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(context.radius.sm),
        ),
        child: Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: colors.textMuted, width: 1.5),
          activeColor: colors.textPrimary,
        ),
      ),
    );
  }
}

/// A bare sync dot for the dense grid footer (icon only) — the icon-only
/// counterpart to [MatomeSyncChip], using the SAME rollup→glyph/colour mapping
/// so a tile's sync state can never read differently from the table's pill.
class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.rollup, this.localOnly = false});
  final MatomeSyncRollup rollup;

  /// Local-first spaces (#102): a local-only file never syncs — show the `local`
  /// state instead of the cloud rollup.
  final bool localOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (localOnly) {
      return const SpaceSyncChip(state: SpaceSyncState.local, compact: true);
    }
    final (IconData icon, Color color) = switch (rollup) {
      MatomeSyncRollup.cloud => (Icons.cloud_done_outlined, colors.badgePersonal),
      MatomeSyncRollup.partial => (
          Icons.cloud_sync_outlined,
          colors.textSecondary,
        ),
      MatomeSyncRollup.onDevice => (Icons.cloud_off_outlined, colors.textMuted),
    };
    return Tooltip(
      message: t.cardStatus.syncState,
      child: Icon(icon, size: context.typography.bodySmall.fontSize, color: color),
    );
  }
}

class _DurationTag extends StatelessWidget {
  const _DurationTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xs,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(context.radius.sm),
      ),
      child: Text(
        label,
        style: typography.label.copyWith(color: colors.onTextPrimary),
      ),
    );
  }
}
