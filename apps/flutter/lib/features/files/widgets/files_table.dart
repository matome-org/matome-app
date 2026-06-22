// The columnar "Table" take on the Files view (DR-000 / DR-003, #1465) — the
// same machinery as the Matome table: sortable columns (Name · When · Size),
// select-all + per-row selection, a bulk-action bar (move / download / delete)
// with confirm + undo, a per-row overflow menu, keyboard focus (`x` selects),
// right-aligned numeric cells, and a compact two-line layout below 720dp.
// Matome / Space / People / Sync are display-only columns surfaced by their own
// independent atoms.
//
// CONVERGENCE: graduated from the approved `matome_files_proposal.dart` mockup;
// the single implementation the `/files` host and the Widgetbook stories render.
//
// Strictly presentational: takes [FileRow] view-models and emits the typed
// callbacks from `files_view_shared.dart` ([onOpen], [onSort],
// [onSelectionChanged], [onBulk]). No providers, no navigation, no DB. Owns only
// EPHEMERAL UI state (sort, selection, the in-table undo stash).
//
// DATA REALITY (#1461): size is not persisted → the Size cell shows a dash;
// people are matome-mediated → the People cell is the file's matome's contacts
// (a dash when none / Unfiled). Neither is fabricated.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/db/file_row.dart';
import '../../../core/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../../../ui/app_card.dart' show MatomeSyncChip;
import '../../../ui/matome_chip.dart';
import '../../../ui/people_cluster.dart';
import '../../../ui/space_chip.dart';
import 'files_view_shared.dart';

// ─── Column geometry (shared by header + cells so columns stay aligned) ───────

const double _wCheck = 44;
const double _wMatome = 148;
const double _wSpace = 112;
const double _wPeople = 84;
const double _wWhen = 64;
const double _wSize = 72;
const double _wSync = 112;
const double _wActions = 40;

/// Below this the table folds into condensed two-line rows (a phone fallback).
const double kFilesTableCompactBreakpoint = 720;

class _ToggleSelectIntent extends Intent {
  const _ToggleSelectIntent();
}

class FilesTable extends StatefulWidget {
  const FilesTable({
    super.key,
    required this.files,
    this.initialSelection = const {},
    this.onOpen,
    this.onSort,
    this.onSelectionChanged,
    this.onBulk,
  });

  /// Rows in master order; sort is display-only so undo reinserts in place.
  final List<FileRow> files;

  /// Files selected when the table first mounts.
  final Set<String> initialSelection;

  final FileOpenCallback? onOpen;
  final FileSortCallback? onSort;
  final FileSelectionCallback? onSelectionChanged;
  final FileBulkCallback? onBulk;

  @override
  State<FilesTable> createState() => _FilesTableState();
}

class _FilesTableState extends State<FilesTable> {
  late List<FileRow> _files = [...widget.files];
  late Set<String> _selected = {...widget.initialSelection};
  FileSortKey _sortKey = FileSortKey.when;
  bool _ascending = false; // most-recent first by default
  FilesUndoStash? _undo;

  @override
  void didUpdateWidget(FilesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.files, widget.files)) {
      _files = [...widget.files];
      final ids = _files.map((f) => f.id).toSet();
      _selected = _selected.intersection(ids);
      _undo = null;
    }
  }

  List<FileRow> get _sorted {
    final view = [..._files];
    int cmp(FileRow a, FileRow b) {
      final v = switch (_sortKey) {
        FileSortKey.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        FileSortKey.when => a.whenSort.compareTo(b.whenSort),
        // Size is not persisted (#1461): the column stays present + sortable but
        // every label is a dash, so size-sort is a stable no-op until a size
        // column lands. Falls back to recency so the order is never random.
        FileSortKey.size => a.whenSort.compareTo(b.whenSort),
      };
      return _ascending ? v : -v;
    }

    view.sort(cmp);
    return view;
  }

  void _toggleSort(FileSortKey key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = key == FileSortKey.name; // text A→Z, others high→low
      }
    });
    widget.onSort?.call(_sortKey, _ascending);
  }

  void _emitSelection() => widget.onSelectionChanged?.call({..._selected});

  void _toggleRow(String id, bool on) {
    setState(() => on ? _selected.add(id) : _selected.remove(id));
    _emitSelection();
  }

  void _toggleAll(bool? on) {
    setState(() {
      _selected = (on ?? false) ? _files.map((f) => f.id).toSet() : <String>{};
    });
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

  void _move(Set<String> ids) =>
      widget.onBulk?.call(FileAction.moveToMatome, ids);
  void _download(Set<String> ids) =>
      widget.onBulk?.call(FileAction.download, ids);

  Future<void> _delete(Set<String> ids) async {
    final n = ids.length;
    if (await confirmDeleteFiles(context, n) && mounted) {
      _remove(ids, t.files.deletedMsg(n: n));
      widget.onBulk?.call(FileAction.delete, ids);
    }
  }

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

    if (_files.isEmpty && _undo == null) {
      return const _TableShell(child: FilesEmptyState());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < kFilesTableCompactBreakpoint;
        final rows = _sorted;
        final allSelected =
            _files.isNotEmpty && _selected.length == _files.length;
        final anySelected = _selected.isNotEmpty;

        return _TableShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (anySelected) ...[
                FilesBulkBar(
                  count: _selected.length,
                  leadingWidth: _wCheck,
                  onClear: () {
                    setState(() => _selected = {});
                    _emitSelection();
                  },
                  onMove: () => _move({..._selected}),
                  onDownload: () => _download({..._selected}),
                  onDelete: () => _delete({..._selected}),
                ),
                Divider(height: 1, color: colors.border),
              ],
              if (compact)
                _CompactSortBar(
                  sortKey: _sortKey,
                  ascending: _ascending,
                  onSort: _toggleSort,
                )
              else
                _HeaderRow(
                  sortKey: _sortKey,
                  ascending: _ascending,
                  allSelected: allSelected,
                  someSelected: anySelected && !allSelected,
                  onToggleAll: _toggleAll,
                  onSort: _toggleSort,
                ),
              Divider(height: 1, color: colors.border),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                compact
                    ? _CompactRow(
                        file: rows[i],
                        selected: _selected.contains(rows[i].id),
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _fileAction(rows[i], a),
                      )
                    : _DataRow(
                        file: rows[i],
                        selected: _selected.contains(rows[i].id),
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _fileAction(rows[i], a),
                      ),
              ],
              if (_undo != null) ...[
                Divider(height: 1, color: colors.border),
                FilesUndoBar(
                  message: _undo!.message,
                  onUndo: _restoreUndo,
                  onDismiss: () => setState(() => _undo = null),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.lg),
        child: child,
      ),
    );
  }
}

// ─── Header row (desktop) ────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sortKey,
    required this.ascending,
    required this.allSelected,
    required this.someSelected,
    required this.onToggleAll,
    required this.onSort,
  });

  final FileSortKey sortKey;
  final bool ascending;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool?> onToggleAll;
  final ValueChanged<FileSortKey> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Container(
      color: colors.subtleFill,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: _wCheck,
            child: _HeaderCheckbox(
              value: allSelected ? true : (someSelected ? null : false),
              onChanged: onToggleAll,
            ),
          ),
          Expanded(
            child: _SortHeader(
              label: t.files.colName,
              active: sortKey == FileSortKey.name,
              ascending: ascending,
              onTap: () => onSort(FileSortKey.name),
            ),
          ),
          SizedBox(width: _wMatome, child: _ColLabel(t.files.colMatome)),
          SizedBox(width: _wSpace, child: _ColLabel(t.files.colSpace)),
          SizedBox(width: _wPeople, child: _ColLabel(t.files.colPeople)),
          SizedBox(
            width: _wWhen,
            child: _SortHeader(
              label: t.files.colWhen,
              active: sortKey == FileSortKey.when,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(FileSortKey.when),
            ),
          ),
          SizedBox(
            width: _wSize,
            child: _SortHeader(
              label: t.files.colSize,
              active: sortKey == FileSortKey.size,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(FileSortKey.size),
            ),
          ),
          SizedBox(width: _wSync, child: _ColLabel(t.files.colSync)),
          const SizedBox(width: _wActions),
        ],
      ),
    );
  }
}

class _ColLabel extends StatelessWidget {
  const _ColLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      label.toUpperCase(),
      style: typography.label.copyWith(
        color: colors.textMuted,
        letterSpacing: 0.6,
        fontSize: 11,
      ),
    );
  }
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.radius.sm),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.spacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: typography.label.copyWith(
                    color: active ? colors.textPrimary : colors.textMuted,
                    letterSpacing: 0.6,
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: context.spacing.xxs),
              Icon(
                active
                    ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: context.typography.bodySmall.fontSize,
                color: active ? colors.accentDark : colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCheckbox extends StatelessWidget {
  const _HeaderCheckbox({required this.value, required this.onChanged});

  final bool? value; // null = indeterminate
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Checkbox(
      value: value,
      tristate: true,
      onChanged: onChanged,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: colors.textMuted, width: 1.5),
      activeColor: colors.textPrimary,
    );
  }
}

// ─── Data row (desktop) ──────────────────────────────────────────────────────

class _DataRow extends StatefulWidget {
  const _DataRow({
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
  State<_DataRow> createState() => _DataRowState();
}

class _DataRowState extends State<_DataRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final f = widget.file;
    final vis = fileKindVisual(context, f);

    final bg = widget.selected
        ? colors.accentSoft.withValues(alpha: 0.5)
        : (_hovered ? colors.subtleFill : colors.surface);

    return _RowFocus(
      focused: _focused,
      onFocusChange: (v) => setState(() => _focused = v),
      onActivate: () => widget.onAction(FileAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onAction(FileAction.open),
          child: Container(
            color: bg,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: _wCheck,
                  child: _RowCheckbox(
                    value: widget.selected,
                    onChanged: widget.onSelect,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(vis.icon,
                          size: context.typography.body.fontSize,
                          color: vis.color),
                      SizedBox(width: spacing.sm),
                      Expanded(
                        child: Text(
                          f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodySmall.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: _wMatome,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MatomeChip(matome: f.matome),
                  ),
                ),
                SizedBox(
                  width: _wSpace,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SpaceChip(space: f.space),
                  ),
                ),
                SizedBox(
                  width: _wPeople,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: f.contacts.isEmpty
                        ? const FilesMutedDash()
                        : PeopleCluster(
                            names: f.contacts, size: context.spacing.lg),
                  ),
                ),
                SizedBox(
                  width: _wWhen,
                  child: Text(
                    f.when,
                    textAlign: TextAlign.right,
                    style:
                        typography.label.copyWith(color: colors.textSecondary),
                  ),
                ),
                SizedBox(
                  width: _wSize,
                  child: Text(
                    f.sizeLabel ?? t.files.noSize,
                    textAlign: TextAlign.right,
                    style:
                        typography.label.copyWith(color: colors.textSecondary),
                  ),
                ),
                SizedBox(
                  width: _wSync,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MatomeSyncChip(rollup: f.rollup),
                    ),
                  ),
                ),
                SizedBox(
                  width: _wActions,
                  child: FileActionsMenu(onAction: widget.onAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a row with keyboard focus: Tab to reach, Enter/Space to open, `x` to
/// toggle selection, and a visible focus ring (no reliance on hover/mouse).
class _RowFocus extends StatelessWidget {
  const _RowFocus({
    required this.focused,
    required this.onFocusChange,
    required this.onActivate,
    required this.onToggleSelect,
    required this.child,
  });

  final bool focused;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onActivate;
  final VoidCallback onToggleSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FocusableActionDetector(
      onShowFocusHighlight: onFocusChange,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyX): _ToggleSelectIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onActivate();
            return null;
          },
        ),
        _ToggleSelectIntent: CallbackAction<_ToggleSelectIntent>(
          onInvoke: (_) {
            onToggleSelect();
            return null;
          },
        ),
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: focused ? colors.accent : colors.surface.withValues(alpha: 0),
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _RowCheckbox extends StatelessWidget {
  const _RowCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: t.files.selectFile,
      checked: value,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: colors.textMuted, width: 1.5),
        activeColor: colors.textPrimary,
      ),
    );
  }
}

// ─── Compact (mobile) ────────────────────────────────────────────────────────

class _CompactSortBar extends StatelessWidget {
  const _CompactSortBar({
    required this.sortKey,
    required this.ascending,
    required this.onSort,
  });

  final FileSortKey sortKey;
  final bool ascending;
  final ValueChanged<FileSortKey> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final options = <(FileSortKey, String)>[
      (FileSortKey.when, t.files.colWhen),
      (FileSortKey.name, t.files.colName),
      (FileSortKey.size, t.files.colSize),
    ];

    return Container(
      color: colors.subtleFill,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          Text(
            t.files.sortBy.toUpperCase(),
            style: typography.label.copyWith(
              color: colors.textMuted,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Wrap(
              spacing: spacing.xs,
              children: [
                for (final (key, label) in options)
                  _SortPill(
                    label: label,
                    active: sortKey == key,
                    ascending: ascending,
                    onTap: () => onSort(key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius.pill),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
        decoration: BoxDecoration(
          color: active ? colors.textPrimary : colors.surface,
          borderRadius: BorderRadius.circular(radius.pill),
          border:
              Border.all(color: active ? colors.textPrimary : colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: typography.label.copyWith(
                color: active ? colors.onTextPrimary : colors.textSecondary,
              ),
            ),
            if (active) ...[
              SizedBox(width: spacing.xxs),
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: context.typography.label.fontSize,
                color: colors.onTextPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactRow extends StatefulWidget {
  const _CompactRow({
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
  State<_CompactRow> createState() => _CompactRowState();
}

class _CompactRowState extends State<_CompactRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final f = widget.file;
    final vis = fileKindVisual(context, f);

    return _RowFocus(
      focused: _focused,
      onFocusChange: (v) => setState(() => _focused = v),
      onActivate: () => widget.onAction(FileAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: GestureDetector(
        onTap: () => widget.onAction(FileAction.open),
        child: Container(
          color: widget.selected
              ? colors.accentSoft.withValues(alpha: 0.5)
              : colors.surface,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _wCheck,
                child: _RowCheckbox(
                  value: widget.selected,
                  onChanged: widget.onSelect,
                ),
              ),
              Icon(vis.icon,
                  size: context.typography.body.fontSize, color: vis.color),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        Text(
                          f.when,
                          style: typography.label
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xxs),
                    Wrap(
                      spacing: spacing.sm,
                      runSpacing: spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          f.sizeLabel ?? t.files.noSize,
                          style: typography.label
                              .copyWith(color: colors.textMuted),
                        ),
                        MatomeChip(matome: f.matome),
                        SpaceChip(space: f.space),
                        if (f.contacts.isNotEmpty)
                          PeopleCluster(
                              names: f.contacts, size: context.spacing.lg),
                        MatomeSyncChip(rollup: f.rollup),
                      ],
                    ),
                  ],
                ),
              ),
              FileActionsMenu(onAction: widget.onAction),
            ],
          ),
        ),
      ),
    );
  }
}
