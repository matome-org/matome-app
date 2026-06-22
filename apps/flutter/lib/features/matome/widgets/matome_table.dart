// A *real* tabular view of the Matome list — the columnar counterpart to the
// card / "letter" list (ADR-0005). Where cards answer "what is this matome
// about", the table answers "let me scan, sort, and act on many matomes at
// once": a header row of sortable columns, per-row selection with a bulk-action
// bar, a per-row overflow menu, and aligned data cells.
//
// CONVERGENCE (DR-000 / DR-001): graduated from the approved
// `matome_table_proposal.dart` mockup into the shipping app. It is the single
// implementation the live host screen, the Widgetbook use-cases, and the shared
// goldens all render — there is no mock to drift from.
//
// Strictly presentational: it takes a list of [MatomeTableRow] view-models the
// host builds from `MatomeItem`, and emits typed callbacks ([onOpen],
// [onSort], [onSelectionChanged], [onBulk]) — it holds NO providers and does NO
// navigation. The host wires open → go_router, move/archive/delete → DAO, and a
// timed Undo SnackBar. The widget owns only EPHEMERAL UI state (the current
// sort, the live selection, and the in-table Undo stash) so it is fully
// demonstrable in Widgetbook with no host wiring, and reusable across surfaces.
//
// Columns: Title + summary peek · When · Items (audio/image/doc mix) · People ·
// Space · Sync. Sortable: Title, When, Items, People. "When" defaults to
// most-recent-first.
//
// Responsive, not amputated (#82): at >= 720dp the full table renders with its
// header row; below that each matome collapses into a condensed two-line row + a
// compact sort selector. Selection, the bulk bar, the per-row menu, and undo all
// survive both layouts.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/db/matome_card.dart' show MatomeItem, MatomeSyncRollup;
import '../../../core/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart' show MatomeSyncChip;
import '../../../ui/app_dialog.dart';
import '../../../ui/space_chip.dart';

/// Presentational view-model for one row of the [MatomeTable]. The host builds
/// these from `MatomeItem`; the table never reads the DB or a provider.
class MatomeTableRow {
  const MatomeTableRow({
    required this.id,
    required this.title,
    required this.summary,
    required this.when,
    required this.whenSort,
    required this.audio,
    required this.image,
    required this.doc,
    required this.people,
    required this.rollup,
    this.space,
    this.peopleNames = const [],
  });

  /// Stable selection / undo key — survives sort and removal.
  final String id;
  final String title;

  /// Summary peek; empty → the muted "No summary yet" placeholder.
  final String summary;

  /// Display label for the When column (relative, host-formatted).
  final String when;

  /// Sort key for When — higher = more recent.
  final int whenSort;
  final int audio;
  final int image;
  final int doc;
  final int people;

  /// Filed space (folder) name, or null → Inbox.
  final String? space;

  /// Tagged contact display names for the People cluster (optional; the count
  /// [people] is authoritative for the numeric column).
  final List<String> peopleNames;

  final MatomeSyncRollup rollup;

  int get itemCount => audio + image + doc;
}

/// Sortable columns. "When" is the default sort (most-recent-first).
enum MatomeTableSort { title, when, items, people }

/// Per-row overflow-menu actions and the targets of the bulk-action bar.
enum MatomeTableAction { open, moveToSpace, archive, delete }

class _ToggleSelectIntent extends Intent {
  const _ToggleSelectIntent();
}

// ─── Column geometry (shared by header + cells so columns stay aligned) ───────

const double _wCheck = 44;
const double _wWhen = 64;
const double _wItems = 128;
const double _wPeople = 64;
const double _wSpace = 132;
const double _wSync = 116;
const double _wActions = 40;

/// Below this the table folds into condensed rows (a phone-width fallback).
const double kMatomeTableCompactBreakpoint = 720;

// ─── The table ───────────────────────────────────────────────────────────────

class MatomeTable extends StatefulWidget {
  const MatomeTable({
    super.key,
    required this.rows,
    this.initialSelection = const {},
    this.onOpen,
    this.onSort,
    this.onSelectionChanged,
    this.onBulk,
  });

  /// The rows to render, in master order. Sort is applied for display only; the
  /// master order is preserved so an Undo can reinsert removed rows in place.
  final List<MatomeTableRow> rows;

  /// Rows selected when the table first mounts (e.g. a restored selection).
  final Set<String> initialSelection;

  /// Open one matome (row tap / Enter / per-row Open). Host → navigation.
  final ValueChanged<String>? onOpen;

  /// The active sort changed (column header / compact pill).
  final void Function(MatomeTableSort sort, bool ascending)? onSort;

  /// The live selection changed.
  final ValueChanged<Set<String>>? onSelectionChanged;

  /// A destructive / move op was confirmed on a set of row ids. Host → DAO +
  /// timed Undo SnackBar. (The table also keeps an in-table Undo affordance so
  /// the recovery path is demonstrable with no host wiring.)
  final void Function(MatomeTableAction action, Set<String> ids)? onBulk;

  @override
  State<MatomeTable> createState() => _MatomeTableState();
}

/// What Undo restores: rows removed by the last destructive op, with the index
/// they held in the master list so reinsert keeps original order.
class _UndoStash {
  const _UndoStash(this.message, this.removed, this.priorSelection);
  final String message;
  final List<MapEntry<int, MatomeTableRow>> removed; // (masterIndex, row), asc
  final Set<String> priorSelection;
}

class _MatomeTableState extends State<MatomeTable> {
  late List<MatomeTableRow> _rows = [...widget.rows];
  late Set<String> _selected = {...widget.initialSelection};
  MatomeTableSort _sortKey = MatomeTableSort.when;
  bool _ascending = false; // most-recent first by default
  _UndoStash? _undo;

  @override
  void didUpdateWidget(MatomeTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The host owns the data; when it re-reads (e.g. after a real archive), the
    // master list is reseeded and any stale selection / undo dropped.
    if (!identical(oldWidget.rows, widget.rows)) {
      _rows = [...widget.rows];
      final ids = _rows.map((r) => r.id).toSet();
      _selected = _selected.intersection(ids);
      _undo = null;
    }
  }

  /// Display order — keeps the master list (`_rows`) stable for undo while
  /// presenting a sorted view.
  List<MatomeTableRow> get _sortedRows {
    final view = [..._rows];
    int cmp(MatomeTableRow a, MatomeTableRow b) {
      final v = switch (_sortKey) {
        MatomeTableSort.title =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        MatomeTableSort.when => a.whenSort.compareTo(b.whenSort),
        MatomeTableSort.items => a.itemCount.compareTo(b.itemCount),
        MatomeTableSort.people => a.people.compareTo(b.people),
      };
      return _ascending ? v : -v;
    }

    view.sort(cmp);
    return view;
  }

  void _toggleSort(MatomeTableSort key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = key == MatomeTableSort.title; // text A→Z, others high→low
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
      _selected = (on ?? false) ? _rows.map((r) => r.id).toSet() : <String>{};
    });
    _emitSelection();
  }

  /// Removes rows by id from the working copy, stashing them (with original
  /// positions) for the in-table Undo.
  void _remove(Set<String> ids, String message) {
    final removed = <MapEntry<int, MatomeTableRow>>[];
    for (var i = 0; i < _rows.length; i++) {
      if (ids.contains(_rows[i].id)) removed.add(MapEntry(i, _rows[i]));
    }
    setState(() {
      final prior = {..._selected};
      _rows = [
        for (final r in _rows)
          if (!ids.contains(r.id)) r,
      ];
      _selected.removeAll(ids);
      _undo = _UndoStash(message, removed, prior);
    });
    _emitSelection();
  }

  void _restoreUndo() {
    final stash = _undo;
    if (stash == null) return;
    final next = [..._rows];
    for (final entry in stash.removed) {
      final at = entry.key.clamp(0, next.length);
      next.insert(at, entry.value);
    }
    setState(() {
      _rows = next;
      _selected = stash.priorSelection;
      _undo = null;
    });
    _emitSelection();
  }

  Future<void> _bulkArchive() async {
    final n = _selected.length;
    final ids = {..._selected};
    _remove(ids, t.matome.table.archivedMsg(n: n));
    widget.onBulk?.call(MatomeTableAction.archive, ids);
  }

  Future<void> _bulkMove() async {
    final ids = {..._selected};
    widget.onBulk?.call(MatomeTableAction.moveToSpace, ids);
  }

  Future<void> _bulkDelete() async {
    final n = _selected.length;
    final ids = {..._selected};
    final ok = await _confirmDelete(n);
    if (!ok || !mounted) return;
    _remove(ids, t.matome.table.deletedMsg(n: n));
    widget.onBulk?.call(MatomeTableAction.delete, ids);
  }

  Future<bool> _confirmDelete(int n) async {
    final colors = context.colors;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: colors.surface,
        title: Text(t.matome.table.deleteTitle),
        content: Text(t.matome.table.deleteBody(n: n)),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.matome.table.cancel),
          ),
          PrimaryButton(
            key: const ValueKey('matome-table-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colors.failed),
            child: Text(t.matome.table.delete),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _rowAction(MatomeTableRow row, MatomeTableAction action) async {
    switch (action) {
      case MatomeTableAction.open:
        widget.onOpen?.call(row.id);
      case MatomeTableAction.moveToSpace:
        widget.onBulk?.call(MatomeTableAction.moveToSpace, {row.id});
      case MatomeTableAction.archive:
        _remove({row.id}, t.matome.table.archivedMsg(n: 1));
        widget.onBulk?.call(MatomeTableAction.archive, {row.id});
      case MatomeTableAction.delete:
        if (await _confirmDelete(1) && mounted) {
          _remove({row.id}, t.matome.table.deletedMsg(n: 1));
          widget.onBulk?.call(MatomeTableAction.delete, {row.id});
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_rows.isEmpty && _undo == null) {
      return const _TableShell(child: _EmptyRows());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < kMatomeTableCompactBreakpoint;
        final rows = _sortedRows;
        final allSelected =
            _rows.isNotEmpty && _selected.length == _rows.length;
        final anySelected = _selected.isNotEmpty;

        return _TableShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bulk bar floats ABOVE the header so column labels + current
              // sort stay visible while a selection is active.
              if (anySelected) ...[
                _BulkBar(
                  count: _selected.length,
                  onClear: () {
                    setState(() => _selected = {});
                    _emitSelection();
                  },
                  onMove: _bulkMove,
                  onArchive: _bulkArchive,
                  onDelete: _bulkDelete,
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
                        row: rows[i],
                        selected: _selected.contains(rows[i].id),
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _rowAction(rows[i], a),
                      )
                    : _DataRow(
                        row: rows[i],
                        selected: _selected.contains(rows[i].id),
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _rowAction(rows[i], a),
                      ),
              ],
              if (_undo != null) ...[
                Divider(height: 1, color: colors.border),
                _UndoBar(
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

/// The bordered, rounded container that frames the whole table.
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

  final MatomeTableSort sortKey;
  final bool ascending;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool?> onToggleAll;
  final ValueChanged<MatomeTableSort> onSort;

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
              label: t.matome.table.colTitle,
              active: sortKey == MatomeTableSort.title,
              ascending: ascending,
              onTap: () => onSort(MatomeTableSort.title),
            ),
          ),
          SizedBox(
            width: _wWhen,
            child: _SortHeader(
              label: t.matome.table.colWhen,
              active: sortKey == MatomeTableSort.when,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(MatomeTableSort.when),
            ),
          ),
          SizedBox(
            width: _wItems,
            child: _SortHeader(
              label: t.matome.table.colItems,
              active: sortKey == MatomeTableSort.items,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(MatomeTableSort.items),
            ),
          ),
          SizedBox(
            width: _wPeople,
            child: _SortHeader(
              label: t.matome.table.colPeople,
              active: sortKey == MatomeTableSort.people,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(MatomeTableSort.people),
            ),
          ),
          SizedBox(
            width: _wSpace,
            child: _ColLabel(t.matome.table.colSpace),
          ),
          SizedBox(width: _wSync, child: _ColLabel(t.matome.table.colSync)),
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
    required this.row,
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });

  final MatomeTableRow row;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final ValueChanged<MatomeTableAction> onAction;

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
    final row = widget.row;

    final bg = widget.selected
        ? colors.accentSoft.withValues(alpha: 0.5)
        : (_hovered ? colors.subtleFill : colors.surface);

    return _RowFocus(
      focused: _focused,
      onFocusChange: (f) => setState(() => _focused = f),
      onActivate: () => widget.onAction(MatomeTableAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onAction(MatomeTableAction.open),
          child: Container(
            color: bg,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _wCheck,
                  child: _RowCheckbox(
                    value: widget.selected,
                    onChanged: widget.onSelect,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: spacing.xxs),
                      Text(
                        row.summary.isEmpty
                            ? t.matome.table.noSummary
                            : row.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodySmall.copyWith(
                          color: row.summary.isEmpty
                              ? colors.textMuted
                              : colors.textSecondary,
                          fontStyle: row.summary.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: _wWhen,
                  child: Text(
                    row.when,
                    textAlign: TextAlign.right,
                    style: typography.label
                        .copyWith(color: colors.textSecondary),
                  ),
                ),
                SizedBox(
                  width: _wItems,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ItemMix(row: row),
                  ),
                ),
                SizedBox(
                  width: _wPeople,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: row.people > 0
                        ? _IconCount(
                            icon: Icons.people_outline,
                            count: row.people,
                            tooltip: _itemTooltip(
                              row.people,
                              t.matome.table.peopleUnit,
                            ),
                          )
                        : const _MutedDash(),
                  ),
                ),
                SizedBox(
                  width: _wSpace,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SpaceChip(space: row.space),
                  ),
                ),
                SizedBox(
                  width: _wSync,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    // The reused MatomeSyncChip sizes to its label (no internal
                    // ellipsis); scale it down so a long sync label can't
                    // overflow the fixed Sync column.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MatomeSyncChip(rollup: row.rollup),
                    ),
                  ),
                ),
                SizedBox(
                  width: _wActions,
                  child: _RowActionsMenu(onAction: widget.onAction),
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
      label: t.matome.table.selectRow,
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

/// Per-row overflow menu — the real affordance, not a decorative icon.
class _RowActionsMenu extends StatelessWidget {
  const _RowActionsMenu({required this.onAction});

  final ValueChanged<MatomeTableAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget item(IconData icon, String label, MatomeTableAction action,
        {Color? color}) {
      return MenuItemButton(
        leadingIcon: Icon(icon, size: context.typography.body.fontSize, color: color ?? colors.textSecondary),
        onPressed: () => onAction(action),
        child: Text(
          label,
          style:
              typography.bodySmall.copyWith(color: color ?? colors.textPrimary),
        ),
      );
    }

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.radius.md),
            side: BorderSide(color: colors.border),
          ),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: spacing.xs),
        ),
      ),
      builder: (context, controller, child) => IconButton(
        icon: Icon(Icons.more_horiz, size: context.typography.body.fontSize, color: colors.textMuted),
        tooltip: t.matome.table.rowActions,
        padding: EdgeInsets.zero,
        constraints:
            BoxConstraints(minWidth: spacing.xl, minHeight: spacing.xl),
        visualDensity: VisualDensity.compact,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        item(Icons.open_in_new, t.matome.table.open, MatomeTableAction.open),
        item(Icons.drive_file_move_outlined, t.matome.table.moveToSpace,
            MatomeTableAction.moveToSpace),
        item(Icons.archive_outlined, t.matome.table.archive,
            MatomeTableAction.archive),
        Divider(height: spacing.sm, color: colors.border),
        item(Icons.delete_outline, t.matome.table.delete,
            MatomeTableAction.delete,
            color: colors.failed),
      ],
    );
  }
}

String _itemTooltip(int n, String unit) => '$n $unit';

/// The audio/image/doc mix as up-to-three compact icon+count tokens, each with
/// a tooltip so the glyphs don't depend on recall.
class _ItemMix extends StatelessWidget {
  const _ItemMix({required this.row});
  final MatomeTableRow row;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final tokens = <Widget>[
      if (row.audio > 0)
        _IconCount(
          icon: Icons.mic_none_rounded,
          count: row.audio,
          tooltip: _itemTooltip(row.audio, t.matome.table.audioUnit),
        ),
      if (row.image > 0)
        _IconCount(
          icon: Icons.image_outlined,
          count: row.image,
          tooltip: _itemTooltip(row.image, t.matome.table.imageUnit),
        ),
      if (row.doc > 0)
        _IconCount(
          icon: Icons.description_outlined,
          count: row.doc,
          tooltip: _itemTooltip(row.doc, t.matome.table.docUnit),
        ),
    ];
    if (tokens.isEmpty) return const _MutedDash();
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.xxs,
      alignment: WrapAlignment.end,
      children: tokens,
    );
  }
}

class _IconCount extends StatelessWidget {
  const _IconCount({required this.icon, required this.count, this.tooltip});
  final IconData icon;
  final int count;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final token = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: context.typography.bodySmall.fontSize, color: colors.textMuted),
        SizedBox(width: context.spacing.xxs),
        Text('$count',
            style: typography.label.copyWith(color: colors.textSecondary)),
      ],
    );
    return tooltip == null ? token : Tooltip(message: tooltip!, child: token);
  }
}

class _MutedDash extends StatelessWidget {
  const _MutedDash();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text('—',
        style: typography.label.copyWith(color: colors.textMuted));
  }
}

// ─── Compact (mobile) ────────────────────────────────────────────────────────

class _CompactSortBar extends StatelessWidget {
  const _CompactSortBar({
    required this.sortKey,
    required this.ascending,
    required this.onSort,
  });

  final MatomeTableSort sortKey;
  final bool ascending;
  final ValueChanged<MatomeTableSort> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final options = <(MatomeTableSort, String)>[
      (MatomeTableSort.when, t.matome.table.colWhen),
      (MatomeTableSort.title, t.matome.table.colTitle),
      (MatomeTableSort.items, t.matome.table.colItems),
      (MatomeTableSort.people, t.matome.table.colPeople),
    ];

    return Container(
      color: colors.subtleFill,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          Text(
            t.matome.table.sortBy.toUpperCase(),
            style: typography.label.copyWith(
              color: colors.textMuted,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: _EdgeFade(
              color: colors.subtleFill,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (key, label) in options) ...[
                      _SortPill(
                        label: label,
                        active: sortKey == key,
                        ascending: ascending,
                        onTap: () => onSort(key),
                      ),
                      SizedBox(width: spacing.xs),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A right-edge gradient mask hinting that the row scrolls horizontally. Not
/// decorative — it signals hidden content. (Gradient on a fill, not on text.)
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: spacing.lg,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [color.withValues(alpha: 0), color],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
          border: Border.all(
            color: active ? colors.textPrimary : colors.border,
          ),
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
    required this.row,
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });

  final MatomeTableRow row;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final ValueChanged<MatomeTableAction> onAction;

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
    final row = widget.row;

    return _RowFocus(
      focused: _focused,
      onFocusChange: (f) => setState(() => _focused = f),
      onActivate: () => widget.onAction(MatomeTableAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: GestureDetector(
        onTap: () => widget.onAction(MatomeTableAction.open),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        Text(
                          row.when,
                          style: typography.label
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xxs),
                    Text(
                      row.summary.isEmpty
                          ? t.matome.table.noSummary
                          : row.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        color: row.summary.isEmpty
                            ? colors.textMuted
                            : colors.textSecondary,
                        fontStyle: row.summary.isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Wrap(
                      spacing: spacing.sm,
                      runSpacing: spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (row.audio > 0)
                          _IconCount(
                            icon: Icons.mic_none_rounded,
                            count: row.audio,
                            tooltip:
                                _itemTooltip(row.audio, t.matome.table.audioUnit),
                          ),
                        if (row.image > 0)
                          _IconCount(
                            icon: Icons.image_outlined,
                            count: row.image,
                            tooltip:
                                _itemTooltip(row.image, t.matome.table.imageUnit),
                          ),
                        if (row.doc > 0)
                          _IconCount(
                            icon: Icons.description_outlined,
                            count: row.doc,
                            tooltip:
                                _itemTooltip(row.doc, t.matome.table.docUnit),
                          ),
                        if (row.people > 0)
                          _IconCount(
                            icon: Icons.people_outline,
                            count: row.people,
                            tooltip: _itemTooltip(
                                row.people, t.matome.table.peopleUnit),
                          ),
                        SpaceChip(space: row.space),
                        MatomeSyncChip(rollup: row.rollup),
                      ],
                    ),
                  ],
                ),
              ),
              _RowActionsMenu(onAction: widget.onAction),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bulk-action bar ─────────────────────────────────────────────────────────

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onClear,
    required this.onMove,
    required this.onArchive,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      key: const ValueKey('matome-table-bulk-bar'),
      color: colors.accentSoft,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: _wCheck,
            child: IconButton(
              icon: Icon(Icons.close, size: context.typography.body.fontSize, color: colors.accentDark),
              visualDensity: VisualDensity.compact,
              tooltip: t.matome.table.clear,
              onPressed: onClear,
            ),
          ),
          Text(
            t.matome.table.selected(n: count),
            style: typography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _BulkAction(
                icon: Icons.drive_file_move_outlined,
                label: t.matome.table.moveToSpace,
                onPressed: onMove,
              ),
              _BulkAction(
                icon: Icons.archive_outlined,
                label: t.matome.table.archive,
                onPressed: onArchive,
              ),
              _BulkAction(
                icon: Icons.delete_outline,
                label: t.matome.table.delete,
                onPressed: onDelete,
                danger: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BulkAction extends StatelessWidget {
  const _BulkAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final fg = danger ? colors.failed : colors.textPrimary;

    return AppTextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: context.typography.body.fontSize, color: fg),
      label: Text(label, style: typography.label.copyWith(color: fg)),
      style: TextButton.styleFrom(
        padding:
            EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xxs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ─── Undo bar (the recovery half of destructive ops) ─────────────────────────

class _UndoBar extends StatelessWidget {
  const _UndoBar({
    required this.message,
    required this.onUndo,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      key: const ValueKey('matome-table-undo-bar'),
      color: colors.subtleFill,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          Icon(Icons.history, size: context.typography.body.fontSize, color: colors.textSecondary),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              message,
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
          AppTextButton(onPressed: onUndo, child: Text(t.matome.table.undo)),
          IconButton(
            icon: Icon(Icons.close, size: context.typography.body.fontSize, color: colors.textMuted),
            visualDensity: VisualDensity.compact,
            tooltip: t.matome.table.clear,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyRows extends StatelessWidget {
  const _EmptyRows();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_rows_outlined, size: context.spacing.xl, color: colors.border),
          SizedBox(height: spacing.sm),
          Text(
            t.matome.table.emptyTitle,
            style: typography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            t.matome.table.emptyBody,
            textAlign: TextAlign.center,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── MatomeItem → MatomeTableRow ─────────────────────────────────────────────

/// Builds the presentational [MatomeTableRow] from a domain [MatomeItem]. Kept
/// next to the widget so the host's mapping and the table's contract stay in one
/// place. [relativeWhen] is the host-formatted relative label for the When cell;
/// `happenedAt` doubles as the When sort key (epoch ms, higher = more recent).
MatomeTableRow matomeTableRowFromItem(
  MatomeItem item, {
  required String relativeWhen,
  List<String> peopleNames = const [],
}) {
  return MatomeTableRow(
    id: item.id,
    title: item.title,
    summary: item.aggregatedSummary?.trim() ?? '',
    when: relativeWhen,
    whenSort: item.happenedAt,
    audio: item.audioCount,
    image: item.imageCount,
    doc: item.documentCount,
    people: item.peopleCount,
    space: item.spaceName,
    peopleNames: peopleNames,
    rollup: item.syncRollup,
  );
}
