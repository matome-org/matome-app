// A *real* tabular view of the Matome list — the columnar counterpart to the
// card / "letter" list we ship today. Where cards answer "what is this matome
// about", the table answers "let me scan, sort, and act on many matomes at
// once": a header row of sortable columns, per-row selection with a bulk-action
// bar, per-row overflow menu, and aligned data cells.
//
// This is the implementation-ready proposal: it carries the production
// interaction model (confirm + undo on destructive ops, keyboard focus + an
// `x`-to-select shortcut, real per-row menu, tooltips on the icon columns) so
// the eventual host screen is a thin wiring layer over `MatomeTable`. It stays
// in Widgetbook as a static, provider-free mockup driven by sample rows; the
// destructive ops mutate the in-memory sample list so Undo is demonstrable.
//
// Columns (per the design brief): Title + summary peek · When · Items
// (audio/image/doc mix) · People · Space · Sync. Sortable: Title, When, Items,
// People. "When" is added on top of the brief's column set because a table of
// time-stamped content needs a sortable date column to be useful.
//
// Responsive, not amputated (#82 single-codebase, mobile + desktop): at >=720dp
// the full table renders with its header row; below that each matome collapses
// into a condensed two-line row + a compact sort selector. Selection, the bulk
// bar, the per-row menu, and undo all survive both layouts.
//
// Sync vocabulary is the one normalized set used everywhere: Synced / Syncing /
// On device. Copy switches with the Widgetbook Localization addon (en / ja).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matome_flutter/core/db/matome_card.dart' show MatomeSyncRollup;
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/app_button.dart';
import 'package:matome_flutter/ui/app_dialog.dart';

// ─── Sample model ────────────────────────────────────────────────────────────

class _Row {
  const _Row({
    required this.id,
    required this.title,
    required this.summary,
    required this.when,
    required this.whenSort,
    required this.audio,
    required this.image,
    required this.doc,
    required this.people,
    required this.space,
    required this.rollup,
  });

  final String id; // stable selection / undo key, survives sort + removal
  final String title;
  final String summary; // empty → "No summary yet"
  final String when; // display label (relative)
  final int whenSort; // higher = more recent (sort key)
  final int audio;
  final int image;
  final int doc;
  final int people;
  final String? space; // null → Inbox
  final MatomeSyncRollup rollup;

  int get itemCount => audio + image + doc;
}

enum _SortKey { title, when, items, people }

enum _RowAction { open, moveToSpace, archive, delete }

// ─── Keyboard intents ────────────────────────────────────────────────────────

class _ToggleSelectIntent extends Intent {
  const _ToggleSelectIntent();
}

// ─── Localized sample copy ───────────────────────────────────────────────────

class _Copy {
  const _Copy({
    required this.colTitle,
    required this.colWhen,
    required this.colItems,
    required this.colPeople,
    required this.colSpace,
    required this.colSync,
    required this.selectedSuffix,
    required this.moveToSpace,
    required this.archive,
    required this.delete,
    required this.clear,
    required this.cancel,
    required this.undo,
    required this.open,
    required this.sortBy,
    required this.synced,
    required this.syncing,
    required this.onDevice,
    required this.inboxLabel,
    required this.noSummary,
    required this.emptyTitle,
    required this.emptyBody,
    required this.deleteTitle,
    required this.audioUnit,
    required this.imageUnit,
    required this.docUnit,
    required this.peopleUnit,
    required this.selectRow,
    required this.rowActions,
    required this.rows,
  });

  final String colTitle;
  final String colWhen;
  final String colItems;
  final String colPeople;
  final String colSpace;
  final String colSync;
  final String selectedSuffix; // "selected" / "件選択中"
  final String moveToSpace;
  final String archive;
  final String delete;
  final String clear;
  final String cancel;
  final String undo;
  final String open;
  final String sortBy;
  final String synced;
  final String syncing;
  final String onDevice;
  final String inboxLabel;
  final String noSummary;
  final String emptyTitle;
  final String emptyBody;
  final String deleteTitle;
  final String audioUnit; // "audio" / "音声"
  final String imageUnit;
  final String docUnit;
  final String peopleUnit;
  final String selectRow; // a11y label
  final String rowActions; // a11y / tooltip
  final List<_Row> rows;

  String syncLabel(MatomeSyncRollup r) => switch (r) {
        MatomeSyncRollup.cloud => synced,
        MatomeSyncRollup.partial => syncing,
        MatomeSyncRollup.onDevice => onDevice,
      };

  // Pluralised-ish messages. Real impl uses slang/ICU; the mock keeps it simple.
  bool get _ja => deleteTitle.contains('削除');
  String deleteBody(int n) => _ja
      ? '$n 件のまとめを削除します。元に戻せます。'
      : 'Delete $n matome${n == 1 ? '' : 's'}? You can undo this.';
  String archivedMsg(int n) => _ja ? '$n 件をアーカイブしました' : 'Archived $n';
  String deletedMsg(int n) => _ja ? '$n 件を削除しました' : 'Deleted $n';
  String itemTooltip(int n, String unit) => _ja ? '$unit $n' : '$n $unit';

  static const en = _Copy(
    colTitle: 'Matome',
    colWhen: 'When',
    colItems: 'Items',
    colPeople: 'People',
    colSpace: 'Space',
    colSync: 'Sync',
    selectedSuffix: 'selected',
    moveToSpace: 'Move to space',
    archive: 'Archive',
    delete: 'Delete',
    clear: 'Clear',
    cancel: 'Cancel',
    undo: 'Undo',
    open: 'Open',
    sortBy: 'Sort',
    synced: 'Synced',
    syncing: 'Syncing',
    onDevice: 'On device',
    inboxLabel: 'Inbox',
    noSummary: 'No summary yet',
    emptyTitle: 'Nothing to show',
    emptyBody: 'Matomes you capture or file will appear here as rows.',
    deleteTitle: 'Delete matomes?',
    audioUnit: 'audio',
    imageUnit: 'images',
    docUnit: 'documents',
    peopleUnit: 'people',
    selectRow: 'Select row',
    rowActions: 'Row actions',
    rows: _rowsEn,
  );

  static const ja = _Copy(
    colTitle: 'まとめ',
    colWhen: '日時',
    colItems: '項目',
    colPeople: '関係者',
    colSpace: '保存先',
    colSync: '同期',
    selectedSuffix: '件選択中',
    moveToSpace: '空間へ移動',
    archive: 'アーカイブ',
    delete: '削除',
    clear: '解除',
    cancel: 'キャンセル',
    undo: '元に戻す',
    open: '開く',
    sortBy: '並び替え',
    synced: '同期済み',
    syncing: '同期中',
    onDevice: '端末のみ',
    inboxLabel: '受信箱',
    noSummary: '要約はまだありません',
    emptyTitle: '表示する項目がありません',
    emptyBody: '取り込んだまとめや整理したまとめがここに行として表示されます。',
    deleteTitle: 'まとめを削除しますか？',
    audioUnit: '音声',
    imageUnit: '画像',
    docUnit: '書類',
    peopleUnit: '人',
    selectRow: '行を選択',
    rowActions: '行の操作',
    rows: _rowsJa,
  );
}

const _rowsEn = <_Row>[
  _Row(
    id: 'r1',
    title: 'Client X — weekly sync',
    summary: 'Q3 budget approved. Ken to draft the proposal before next week.',
    when: '2h',
    whenSort: 100,
    audio: 2,
    image: 1,
    doc: 1,
    people: 2,
    space: 'Marketing',
    rollup: MatomeSyncRollup.cloud,
  ),
  _Row(
    id: 'r2',
    title: 'Design review',
    summary: 'Walking through the new onboarding screens with the team.',
    when: '4h',
    whenSort: 90,
    audio: 1,
    image: 0,
    doc: 0,
    people: 1,
    space: null,
    rollup: MatomeSyncRollup.partial,
  ),
  _Row(
    id: 'r3',
    title: 'Quick voice memo',
    summary: '',
    when: '5h',
    whenSort: 80,
    audio: 1,
    image: 0,
    doc: 0,
    people: 0,
    space: null,
    rollup: MatomeSyncRollup.onDevice,
  ),
  _Row(
    id: 'r4',
    title: 'Sales call — Acme',
    summary: 'Deal slips to next quarter. Revisit the terms in the contract.',
    when: '1d',
    whenSort: 50,
    audio: 1,
    image: 0,
    doc: 2,
    people: 3,
    space: 'Sales',
    rollup: MatomeSyncRollup.cloud,
  ),
  _Row(
    id: 'r5',
    title: 'Workshop notes',
    summary: 'Roadmap prioritisation exercise with the whole product team.',
    when: '1d',
    whenSort: 49,
    audio: 3,
    image: 2,
    doc: 0,
    people: 4,
    space: 'Product',
    rollup: MatomeSyncRollup.partial,
  ),
];

const _rowsJa = <_Row>[
  _Row(
    id: 'r1',
    title: 'クライアントX 定例会議',
    summary: 'Q3 予算が承認。Ken が来週までに提案書を作成。',
    when: '2時間前',
    whenSort: 100,
    audio: 2,
    image: 1,
    doc: 1,
    people: 2,
    space: 'マーケ',
    rollup: MatomeSyncRollup.cloud,
  ),
  _Row(
    id: 'r2',
    title: 'デザインレビュー',
    summary: '新しいオンボーディング画面をチームで確認中。',
    when: '4時間前',
    whenSort: 90,
    audio: 1,
    image: 0,
    doc: 0,
    people: 1,
    space: null,
    rollup: MatomeSyncRollup.partial,
  ),
  _Row(
    id: 'r3',
    title: '音声メモ',
    summary: '',
    when: '5時間前',
    whenSort: 80,
    audio: 1,
    image: 0,
    doc: 0,
    people: 0,
    space: null,
    rollup: MatomeSyncRollup.onDevice,
  ),
  _Row(
    id: 'r4',
    title: '商談 — Acme',
    summary: '契約は来四半期へ。条件を再確認する。',
    when: '昨日',
    whenSort: 50,
    audio: 1,
    image: 0,
    doc: 2,
    people: 3,
    space: '営業',
    rollup: MatomeSyncRollup.cloud,
  ),
  _Row(
    id: 'r5',
    title: 'ワークショップ メモ',
    summary: 'ロードマップの優先順位付け演習をチームで実施。',
    when: '昨日',
    whenSort: 49,
    audio: 3,
    image: 2,
    doc: 0,
    people: 4,
    space: 'プロダクト',
    rollup: MatomeSyncRollup.partial,
  ),
];

_Copy _copyOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja' ? _Copy.ja : _Copy.en;

// ─── Column geometry (shared by header + cells so columns stay aligned) ───────

const double _wCheck = 44;
const double _wWhen = 64;
const double _wItems = 128;
const double _wPeople = 64;
const double _wSpace = 132;
const double _wSync = 116;
const double _wActions = 40;

/// Below this the table folds into condensed rows (a phone-width fallback).
const double _kCompactBreakpoint = 720;

// ─── The table ───────────────────────────────────────────────────────────────

class MatomeTable extends StatefulWidget {
  const MatomeTable({
    super.key,
    required this.rows,
    this.initialSelection = const {},
  });

  final List<_Row> rows;
  final Set<String> initialSelection;

  @override
  State<MatomeTable> createState() => _MatomeTableState();
}

/// What Undo restores: rows removed by the last destructive op, with the index
/// they held in the master list so reinsert keeps original order.
class _UndoStash {
  const _UndoStash(this.message, this.removed, this.priorSelection);
  final String message;
  final List<MapEntry<int, _Row>> removed; // (masterIndex, row), ascending
  final Set<String> priorSelection;
}

class _MatomeTableState extends State<MatomeTable> {
  late List<_Row> _rows = [...widget.rows];
  late Set<String> _selected = {...widget.initialSelection};
  _SortKey _sortKey = _SortKey.when;
  bool _ascending = false; // most-recent first by default
  _UndoStash? _undo;

  /// Display order — keeps the master list (`_rows`) stable for undo while
  /// presenting a sorted view.
  List<_Row> get _sortedRows {
    final view = [..._rows];
    int cmp(_Row a, _Row b) {
      final v = switch (_sortKey) {
        _SortKey.title => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        _SortKey.when => a.whenSort.compareTo(b.whenSort),
        _SortKey.items => a.itemCount.compareTo(b.itemCount),
        _SortKey.people => a.people.compareTo(b.people),
      };
      return _ascending ? v : -v;
    }

    view.sort(cmp);
    return view;
  }

  void _toggleSort(_SortKey key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = key == _SortKey.title; // text A→Z, others high→low
      }
    });
  }

  void _toggleRow(String id, bool on) {
    setState(() => on ? _selected.add(id) : _selected.remove(id));
  }

  void _toggleAll(bool? on) {
    setState(() {
      _selected = (on ?? false) ? _rows.map((r) => r.id).toSet() : <String>{};
    });
  }

  /// Removes rows by id, stashing them (with original positions) for Undo.
  void _remove(Set<String> ids, String message) {
    final removed = <MapEntry<int, _Row>>[];
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
  }

  Future<void> _bulkArchive() async {
    final c = _copyOf(context);
    _remove({..._selected}, c.archivedMsg(_selected.length));
  }

  Future<void> _bulkDelete() async {
    final c = _copyOf(context);
    final n = _selected.length;
    final ok = await _confirmDelete(n, c);
    if (!ok || !mounted) return;
    _remove({..._selected}, c.deletedMsg(n));
  }

  Future<bool> _confirmDelete(int n, _Copy c) async {
    final colors = context.colors;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: colors.surface,
        title: Text(c.deleteTitle),
        content: Text(c.deleteBody(n)),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(c.cancel),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: colors.failed),
            child: Text(c.delete),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _rowAction(_Row row, _RowAction action) async {
    final c = _copyOf(context);
    switch (action) {
      case _RowAction.open:
      case _RowAction.moveToSpace:
        break; // mock — host wires navigation / move sheet
      case _RowAction.archive:
        _remove({row.id}, c.archivedMsg(1));
      case _RowAction.delete:
        if (await _confirmDelete(1, c) && mounted) {
          _remove({row.id}, c.deletedMsg(1));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = _copyOf(context);

    if (_rows.isEmpty && _undo == null) {
      return _TableShell(child: _EmptyRows(copy: c));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _kCompactBreakpoint;
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
                  copy: c,
                  onClear: () => setState(() => _selected = {}),
                  onMove: () {}, // mock — host wires the move sheet
                  onArchive: _bulkArchive,
                  onDelete: _bulkDelete,
                ),
                Divider(height: 1, color: colors.border),
              ],
              if (compact)
                _CompactSortBar(
                  sortKey: _sortKey,
                  ascending: _ascending,
                  copy: c,
                  onSort: _toggleSort,
                )
              else
                _HeaderRow(
                  copy: c,
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
                        copy: c,
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _rowAction(rows[i], a),
                      )
                    : _DataRow(
                        row: rows[i],
                        selected: _selected.contains(rows[i].id),
                        copy: c,
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _rowAction(rows[i], a),
                      ),
              ],
              if (_undo != null) ...[
                Divider(height: 1, color: colors.border),
                _UndoBar(
                  message: _undo!.message,
                  copy: c,
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
    required this.copy,
    required this.sortKey,
    required this.ascending,
    required this.allSelected,
    required this.someSelected,
    required this.onToggleAll,
    required this.onSort,
  });

  final _Copy copy;
  final _SortKey sortKey;
  final bool ascending;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool?> onToggleAll;
  final ValueChanged<_SortKey> onSort;

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
              label: copy.colTitle,
              active: sortKey == _SortKey.title,
              ascending: ascending,
              onTap: () => onSort(_SortKey.title),
            ),
          ),
          SizedBox(
            width: _wWhen,
            child: _SortHeader(
              label: copy.colWhen,
              active: sortKey == _SortKey.when,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(_SortKey.when),
            ),
          ),
          SizedBox(
            width: _wItems,
            child: _SortHeader(
              label: copy.colItems,
              active: sortKey == _SortKey.items,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(_SortKey.items),
            ),
          ),
          SizedBox(
            width: _wPeople,
            child: _SortHeader(
              label: copy.colPeople,
              active: sortKey == _SortKey.people,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(_SortKey.people),
            ),
          ),
          SizedBox(width: _wSpace, child: _ColLabel(copy.colSpace)),
          SizedBox(width: _wSync, child: _ColLabel(copy.colSync)),
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
                size: 13,
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
    required this.copy,
    required this.onSelect,
    required this.onAction,
  });

  final _Row row;
  final bool selected;
  final _Copy copy;
  final ValueChanged<bool> onSelect;
  final ValueChanged<_RowAction> onAction;

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
    final c = widget.copy;

    final bg = widget.selected
        ? colors.accentSoft.withValues(alpha: 0.5)
        : (_hovered ? colors.subtleFill : colors.surface);

    return _RowFocus(
      focused: _focused,
      onFocusChange: (f) => setState(() => _focused = f),
      onActivate: () => widget.onAction(_RowAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onAction(_RowAction.open),
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
                    label: c.selectRow,
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
                        row.summary.isEmpty ? c.noSummary : row.summary,
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
                    child: _ItemMix(row: row, copy: c),
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
                            tooltip: c.itemTooltip(row.people, c.peopleUnit),
                          )
                        : _MutedDash(),
                  ),
                ),
                SizedBox(
                  width: _wSpace,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _PlaceChip(space: row.space, copy: c),
                  ),
                ),
                SizedBox(
                  width: _wSync,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SyncChip(rollup: row.rollup, copy: c),
                  ),
                ),
                SizedBox(
                  width: _wActions,
                  child: _RowActionsMenu(
                    copy: c,
                    onAction: widget.onAction,
                  ),
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
            color: focused ? colors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _RowCheckbox extends StatelessWidget {
  const _RowCheckbox({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: label,
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
  const _RowActionsMenu({required this.copy, required this.onAction});

  final _Copy copy;
  final ValueChanged<_RowAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget item(IconData icon, String label, _RowAction action,
        {Color? color}) {
      return MenuItemButton(
        leadingIcon: Icon(icon, size: 18, color: color ?? colors.textSecondary),
        onPressed: () => onAction(action),
        child: Text(
          label,
          style: typography.bodySmall.copyWith(color: color ?? colors.textPrimary),
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
        icon: Icon(Icons.more_horiz, size: 18, color: colors.textMuted),
        tooltip: copy.rowActions,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        item(Icons.open_in_new, copy.open, _RowAction.open),
        item(Icons.drive_file_move_outlined, copy.moveToSpace,
            _RowAction.moveToSpace),
        item(Icons.archive_outlined, copy.archive, _RowAction.archive),
        Divider(height: spacing.sm, color: colors.border),
        item(Icons.delete_outline, copy.delete, _RowAction.delete,
            color: colors.failed),
      ],
    );
  }
}

/// The audio/image/doc mix as up-to-three compact icon+count tokens, each with
/// a tooltip so the glyphs don't depend on recall.
class _ItemMix extends StatelessWidget {
  const _ItemMix({required this.row, required this.copy});
  final _Row row;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final tokens = <Widget>[
      if (row.audio > 0)
        _IconCount(
          icon: Icons.mic_none_rounded,
          count: row.audio,
          tooltip: copy.itemTooltip(row.audio, copy.audioUnit),
        ),
      if (row.image > 0)
        _IconCount(
          icon: Icons.image_outlined,
          count: row.image,
          tooltip: copy.itemTooltip(row.image, copy.imageUnit),
        ),
      if (row.doc > 0)
        _IconCount(
          icon: Icons.description_outlined,
          count: row.doc,
          tooltip: copy.itemTooltip(row.doc, copy.docUnit),
        ),
    ];
    if (tokens.isEmpty) return _MutedDash();
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.xxs,
      alignment: WrapAlignment.end,
      children: tokens,
    );
  }
}

class _IconCount extends StatelessWidget {
  const _IconCount({
    required this.icon,
    required this.count,
    this.tooltip,
  });
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
        Icon(icon, size: 14, color: colors.textMuted),
        SizedBox(width: context.spacing.xxs),
        Text('$count',
            style: typography.label.copyWith(color: colors.textSecondary)),
      ],
    );
    return tooltip == null ? token : Tooltip(message: tooltip!, child: token);
  }
}

class _MutedDash extends StatelessWidget {
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
    required this.copy,
    required this.onSort,
  });

  final _SortKey sortKey;
  final bool ascending;
  final _Copy copy;
  final ValueChanged<_SortKey> onSort;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    final options = <(_SortKey, String)>[
      (_SortKey.when, copy.colWhen),
      (_SortKey.title, copy.colTitle),
      (_SortKey.items, copy.colItems),
      (_SortKey.people, copy.colPeople),
    ];

    return Container(
      color: colors.subtleFill,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          Text(
            copy.sortBy.toUpperCase(),
            style: typography.label.copyWith(
              color: colors.textMuted,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          SizedBox(width: spacing.sm),
          // Scroller + a right edge fade so off-screen options read as scrollable.
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
    return Stack(
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              width: 24,
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
                size: 12,
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
    required this.copy,
    required this.onSelect,
    required this.onAction,
  });

  final _Row row;
  final bool selected;
  final _Copy copy;
  final ValueChanged<bool> onSelect;
  final ValueChanged<_RowAction> onAction;

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
    final c = widget.copy;

    return _RowFocus(
      focused: _focused,
      onFocusChange: (f) => setState(() => _focused = f),
      onActivate: () => widget.onAction(_RowAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: GestureDetector(
        onTap: () => widget.onAction(_RowAction.open),
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
                  label: c.selectRow,
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
                      row.summary.isEmpty ? c.noSummary : row.summary,
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
                            tooltip: c.itemTooltip(row.audio, c.audioUnit),
                          ),
                        if (row.image > 0)
                          _IconCount(
                            icon: Icons.image_outlined,
                            count: row.image,
                            tooltip: c.itemTooltip(row.image, c.imageUnit),
                          ),
                        if (row.doc > 0)
                          _IconCount(
                            icon: Icons.description_outlined,
                            count: row.doc,
                            tooltip: c.itemTooltip(row.doc, c.docUnit),
                          ),
                        if (row.people > 0)
                          _IconCount(
                            icon: Icons.people_outline,
                            count: row.people,
                            tooltip: c.itemTooltip(row.people, c.peopleUnit),
                          ),
                        _PlaceChip(space: row.space, copy: c),
                        _SyncChip(rollup: row.rollup, copy: c),
                      ],
                    ),
                  ],
                ),
              ),
              _RowActionsMenu(copy: c, onAction: widget.onAction),
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
    required this.copy,
    required this.onClear,
    required this.onMove,
    required this.onArchive,
    required this.onDelete,
  });

  final int count;
  final _Copy copy;
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
      color: colors.accentSoft,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: _wCheck,
            child: IconButton(
              icon: Icon(Icons.close, size: 18, color: colors.accentDark),
              visualDensity: VisualDensity.compact,
              tooltip: copy.clear,
              onPressed: onClear,
            ),
          ),
          Text(
            '$count ${copy.selectedSuffix}',
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
                label: copy.moveToSpace,
                onPressed: onMove,
              ),
              _BulkAction(
                icon: Icons.archive_outlined,
                label: copy.archive,
                onPressed: onArchive,
              ),
              _BulkAction(
                icon: Icons.delete_outline,
                label: copy.delete,
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

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: fg),
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
    required this.copy,
    required this.onUndo,
    required this.onDismiss,
  });

  final String message;
  final _Copy copy;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    // Host wires this to a timed SnackBar; the mock keeps it pinned so the
    // recovery affordance is inspectable in Widgetbook.
    return Container(
      color: colors.subtleFill,
      padding:
          EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
      child: Row(
        children: [
          Icon(Icons.history, size: 16, color: colors.textSecondary),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              message,
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
          AppTextButton(onPressed: onUndo, child: Text(copy.undo)),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: colors.textMuted),
            visualDensity: VisualDensity.compact,
            tooltip: copy.clear,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

// ─── Shared cell widgets ─────────────────────────────────────────────────────

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.space, required this.copy});

  final String? space;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final filed = space != null;
    final icon = filed ? Icons.folder_outlined : Icons.inbox_outlined;
    final label = filed ? space! : copy.inboxLabel;
    final color = filed ? colors.textSecondary : colors.textMuted;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: spacing.xxs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.label.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.rollup, required this.copy});

  final MatomeSyncRollup rollup;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final (IconData icon, Color color) = switch (rollup) {
      MatomeSyncRollup.cloud => (Icons.cloud_done_outlined, colors.badgePersonal),
      MatomeSyncRollup.partial => (
          Icons.cloud_sync_outlined,
          colors.textSecondary
        ),
      MatomeSyncRollup.onDevice => (Icons.cloud_off_outlined, colors.textMuted),
    };

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          SizedBox(width: spacing.xxs),
          Flexible(
            child: Text(
              copy.syncLabel(rollup),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.label.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyRows extends StatelessWidget {
  const _EmptyRows({required this.copy});
  final _Copy copy;

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
          Icon(Icons.table_rows_outlined, size: 32, color: colors.border),
          SizedBox(height: spacing.sm),
          Text(
            copy.emptyTitle,
            style: typography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            copy.emptyBody,
            textAlign: TextAlign.center,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

