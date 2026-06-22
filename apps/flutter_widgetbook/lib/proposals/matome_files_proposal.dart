// Proposal use-cases for the **Files** view — two takes (Grid + Table), each
// mobile + desktop. Files is the cross-cutting view of every captured/imported
// artifact: audio, images, documents. A file usually belongs to a matome, but
// it can also be loose (not in any matome) — that "Unfiled" state is the thing
// this view makes visible, so the two proposals both surface a matome / Unfiled
// chip on every file.
//
//   * Grid  → visual browsing. Tiles with a type/preview block, name, meta, and
//             the matome/Unfiled chip. Best for scanning images + mixed media.
//   * Table → the columnar counterpart (same machinery as the Matome table):
//             sortable columns, selection + bulk bar, per-row menu, confirm +
//             undo on destructive ops. Best for managing many files at once.
//
// Both adapt to width (desktop multi-column / mobile condensed) and share the
// selection / bulk-action / undo model. Static provider-free mockup — sample
// data, no DB; destructive ops mutate the in-memory list so Undo is real.
// Copy switches with the Widgetbook Localization addon (en / ja).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matome_flutter/core/db/matome_card.dart' show MatomeSyncRollup;
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/app_button.dart';
import 'package:matome_flutter/ui/app_dialog.dart';
import 'package:matome_flutter/ui/file_type_chip.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// ─── Model ───────────────────────────────────────────────────────────────────

enum FileKind { audio, image, document }

class _File {
  const _File({
    required this.id,
    required this.name,
    required this.kind,
    required this.ext,
    required this.sizeLabel,
    required this.sizeSort,
    required this.when,
    required this.whenSort,
    required this.matome, // null → not in a matome ("Unfiled")
    required this.rollup,
    this.space, // null → not filed into a space ("Inbox") — independent of matome
    this.contacts = const [], // people tagged on the file — independent too
    this.duration, // audio only
  });

  final String id;
  final String name;
  final FileKind kind;
  final String ext; // lowercase, no dot ('pdf', 'm4a', 'jpg')
  final String sizeLabel;
  final int sizeSort; // bytes-ish, for sort
  final String when;
  final int whenSort;
  final String? matome;
  final MatomeSyncRollup rollup;

  /// Filed Space (folder) name — null = Inbox. A file's space is INDEPENDENT of
  /// its matome: a loose (unfiled) file can still live in a space, and a matome
  /// carries its own space too. Surfaced as its own chip, not merged with the
  /// matome chip.
  final String? space;

  /// People tagged on this file (contact display names). INDEPENDENT of matome
  /// and space — a file can be tied to a person directly. Surfaced as its own
  /// avatar cluster. Empty = nobody tagged.
  final List<String> contacts;
  final String? duration;

  bool get unfiled => matome == null;
  bool get inInbox => space == null;
}

enum _SortKey { name, when, size }

enum _FileAction { open, moveToMatome, download, delete }

// ─── Localized copy ──────────────────────────────────────────────────────────

class _Copy {
  const _Copy({
    required this.colName,
    required this.colMatome,
    required this.colSpace,
    required this.inbox,
    required this.colPeople,
    required this.colWhen,
    required this.colSize,
    required this.colSync,
    required this.unfiled,
    required this.selectedSuffix,
    required this.moveToMatome,
    required this.download,
    required this.delete,
    required this.clear,
    required this.cancel,
    required this.undo,
    required this.open,
    required this.sortBy,
    required this.synced,
    required this.syncing,
    required this.onDevice,
    required this.emptyTitle,
    required this.emptyBody,
    required this.deleteTitle,
    required this.selectFile,
    required this.fileActions,
    required this.files,
  });

  final String colName;
  final String colMatome;
  final String colSpace;
  final String inbox;
  final String colPeople;
  final String colWhen;
  final String colSize;
  final String colSync;
  final String unfiled;
  final String selectedSuffix;
  final String moveToMatome;
  final String download;
  final String delete;
  final String clear;
  final String cancel;
  final String undo;
  final String open;
  final String sortBy;
  final String synced;
  final String syncing;
  final String onDevice;
  final String emptyTitle;
  final String emptyBody;
  final String deleteTitle;
  final String selectFile;
  final String fileActions;
  final List<_File> files;

  bool get _ja => deleteTitle.contains('削除');

  String syncLabel(MatomeSyncRollup r) => switch (r) {
        MatomeSyncRollup.cloud => synced,
        MatomeSyncRollup.partial => syncing,
        MatomeSyncRollup.onDevice => onDevice,
      };
  String deleteBody(int n) => _ja
      ? '$n 件のファイルを削除します。元に戻せます。'
      : 'Delete $n file${n == 1 ? '' : 's'}? You can undo this.';
  String deletedMsg(int n) => _ja ? '$n 件を削除しました' : 'Deleted $n';

  static const en = _Copy(
    colName: 'Name',
    colMatome: 'Matome',
    colSpace: 'Space',
    inbox: 'Inbox',
    colPeople: 'People',
    colWhen: 'When',
    colSize: 'Size',
    colSync: 'Sync',
    unfiled: 'Unfiled',
    selectedSuffix: 'selected',
    moveToMatome: 'Move to matome',
    download: 'Download',
    delete: 'Delete',
    clear: 'Clear',
    cancel: 'Cancel',
    undo: 'Undo',
    open: 'Open',
    sortBy: 'Sort',
    synced: 'Synced',
    syncing: 'Syncing',
    onDevice: 'On device',
    emptyTitle: 'No files',
    emptyBody: 'Files you capture or import appear here, in or out of a matome.',
    deleteTitle: 'Delete files?',
    selectFile: 'Select file',
    fileActions: 'File actions',
    files: _filesEn,
  );

  static const ja = _Copy(
    colName: '名前',
    colMatome: 'まとめ',
    colSpace: '保存先',
    inbox: '受信箱',
    colPeople: '関係者',
    colWhen: '日時',
    colSize: 'サイズ',
    colSync: '同期',
    unfiled: '未整理',
    selectedSuffix: '件選択中',
    moveToMatome: 'まとめへ移動',
    download: 'ダウンロード',
    delete: '削除',
    clear: '解除',
    cancel: 'キャンセル',
    undo: '元に戻す',
    open: '開く',
    sortBy: '並び替え',
    synced: '同期済み',
    syncing: '同期中',
    onDevice: '端末のみ',
    emptyTitle: 'ファイルがありません',
    emptyBody: '取り込んだファイルは、まとめの有無に関わらずここに表示されます。',
    deleteTitle: 'ファイルを削除しますか？',
    selectFile: 'ファイルを選択',
    fileActions: 'ファイルの操作',
    files: _filesJa,
  );
}

const _filesEn = <_File>[
  _File(
    id: 'f1',
    name: 'Q3 roadmap.pdf',
    contacts: ['Ana', 'Ken'],
    kind: FileKind.document,
    ext: 'pdf',
    sizeLabel: '2.4 MB',
    sizeSort: 2400000,
    when: '2h',
    whenSort: 100,
    matome: 'Client X — weekly sync',
    space: 'Marketing',
    rollup: MatomeSyncRollup.cloud,
  ),
  _File(
    id: 'f2',
    name: 'Design sync.m4a',
    contacts: ['Mika'],
    kind: FileKind.audio,
    ext: 'm4a',
    sizeLabel: '8.1 MB',
    sizeSort: 8100000,
    when: '4h',
    whenSort: 90,
    matome: 'Design review',
    space: 'Product',
    rollup: MatomeSyncRollup.partial,
    duration: '12:04',
  ),
  _File(
    id: 'f3',
    name: 'whiteboard.jpg',
    kind: FileKind.image,
    ext: 'jpg',
    sizeLabel: '1.2 MB',
    sizeSort: 1200000,
    when: '5h',
    whenSort: 80,
    matome: null, // unfiled, no space → Inbox
    space: null,
    rollup: MatomeSyncRollup.onDevice,
  ),
  _File(
    id: 'f4',
    name: 'contract-acme.docx',
    contacts: ['Leo', 'Ana', 'Ken'],
    kind: FileKind.document,
    ext: 'docx',
    sizeLabel: '320 KB',
    sizeSort: 320000,
    when: '1d',
    whenSort: 50,
    matome: 'Sales call — Acme',
    space: 'Sales',
    rollup: MatomeSyncRollup.cloud,
  ),
  _File(
    id: 'f5',
    name: 'voice-memo.m4a',
    kind: FileKind.audio,
    ext: 'm4a',
    sizeLabel: '640 KB',
    sizeSort: 640000,
    when: '1d',
    whenSort: 49,
    matome: null, // unfiled but still filed into a space (space ≠ matome)
    space: 'Personal',
    rollup: MatomeSyncRollup.onDevice,
    duration: '00:48',
  ),
  _File(
    id: 'f6',
    name: 'reference-shot.png',
    contacts: ['Yui', 'Mika'],
    kind: FileKind.image,
    ext: 'png',
    sizeLabel: '3.0 MB',
    sizeSort: 3000000,
    when: '2d',
    whenSort: 30,
    matome: 'Workshop notes',
    space: 'Product',
    rollup: MatomeSyncRollup.partial,
  ),
  _File(
    id: 'f7',
    name: 'budget.xlsx',
    kind: FileKind.document,
    ext: 'xlsx',
    sizeLabel: '88 KB',
    sizeSort: 88000,
    when: '3d',
    whenSort: 20,
    matome: null, // unfiled, no space → Inbox
    space: null,
    rollup: MatomeSyncRollup.cloud,
  ),
  _File(
    id: 'f8',
    name: 'notes.md',
    contacts: ['Ana'],
    kind: FileKind.document,
    ext: 'md',
    sizeLabel: '4 KB',
    sizeSort: 4000,
    when: '4d',
    whenSort: 10,
    matome: 'Client X — weekly sync',
    space: 'Marketing',
    rollup: MatomeSyncRollup.cloud,
  ),
];

const _filesJa = <_File>[
  _File(
    id: 'f1',
    name: 'Q3ロードマップ.pdf',
    contacts: ['田中', '佐藤'],
    kind: FileKind.document,
    ext: 'pdf',
    sizeLabel: '2.4 MB',
    sizeSort: 2400000,
    when: '2時間前',
    whenSort: 100,
    matome: 'クライアントX 定例会議',
    space: 'マーケ',
    rollup: MatomeSyncRollup.cloud,
  ),
  _File(
    id: 'f2',
    name: 'デザイン定例.m4a',
    contacts: ['鈴木'],
    kind: FileKind.audio,
    ext: 'm4a',
    sizeLabel: '8.1 MB',
    sizeSort: 8100000,
    when: '4時間前',
    whenSort: 90,
    matome: 'デザインレビュー',
    space: 'プロダクト',
    rollup: MatomeSyncRollup.partial,
    duration: '12:04',
  ),
  _File(
    id: 'f3',
    name: 'ホワイトボード.jpg',
    kind: FileKind.image,
    ext: 'jpg',
    sizeLabel: '1.2 MB',
    sizeSort: 1200000,
    when: '5時間前',
    whenSort: 80,
    matome: null,
    space: null,
    rollup: MatomeSyncRollup.onDevice,
  ),
  _File(
    id: 'f4',
    name: '契約書-acme.docx',
    contacts: ['高橋', '田中', '佐藤'],
    kind: FileKind.document,
    ext: 'docx',
    sizeLabel: '320 KB',
    sizeSort: 320000,
    when: '昨日',
    whenSort: 50,
    matome: '商談 — Acme',
    space: '営業',
    rollup: MatomeSyncRollup.cloud,
  ),
  _File(
    id: 'f5',
    name: '音声メモ.m4a',
    kind: FileKind.audio,
    ext: 'm4a',
    sizeLabel: '640 KB',
    sizeSort: 640000,
    when: '昨日',
    whenSort: 49,
    matome: null,
    space: '個人',
    rollup: MatomeSyncRollup.onDevice,
    duration: '00:48',
  ),
  _File(
    id: 'f6',
    name: '参考写真.png',
    contacts: ['山本', '鈴木'],
    kind: FileKind.image,
    ext: 'png',
    sizeLabel: '3.0 MB',
    sizeSort: 3000000,
    when: '2日前',
    whenSort: 30,
    matome: 'ワークショップ メモ',
    space: 'プロダクト',
    rollup: MatomeSyncRollup.partial,
  ),
  _File(
    id: 'f7',
    name: '予算.xlsx',
    kind: FileKind.document,
    ext: 'xlsx',
    sizeLabel: '88 KB',
    sizeSort: 88000,
    when: '3日前',
    whenSort: 20,
    matome: null,
    space: null,
    rollup: MatomeSyncRollup.cloud,
  ),
  _File(
    id: 'f8',
    name: 'メモ.md',
    contacts: ['田中'],
    kind: FileKind.document,
    ext: 'md',
    sizeLabel: '4 KB',
    sizeSort: 4000,
    when: '4日前',
    whenSort: 10,
    matome: 'クライアントX 定例会議',
    space: 'マーケ',
    rollup: MatomeSyncRollup.cloud,
  ),
];

_Copy _copyOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja' ? _Copy.ja : _Copy.en;

// ─── Kind visual (icon + tint) ───────────────────────────────────────────────

({IconData icon, Color color}) _kindVisual(BuildContext context, _File f) {
  final colors = context.colors;
  return switch (f.kind) {
    FileKind.audio => (icon: Icons.mic_none_rounded, color: colors.accentDark),
    FileKind.image => (icon: Icons.image_outlined, color: colors.badgeIdeas),
    FileKind.document => (
        icon: FileTypeChip.iconForExtension(f.ext),
        color: colors.textSecondary,
      ),
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Use cases
// ═══════════════════════════════════════════════════════════════════════════

@widgetbook.UseCase(
  name: 'Grid — desktop',
  type: FilesGrid,
  path: '[Proposals]/Files',
)
Widget gridDesktopUseCase(BuildContext context) {
  return _Surface(width: 960, child: FilesGrid(files: _copyOf(context).files));
}

@widgetbook.UseCase(
  name: 'Grid — mobile',
  type: FilesGrid,
  path: '[Proposals]/Files',
)
Widget gridMobileUseCase(BuildContext context) {
  return _Surface(width: 380, child: FilesGrid(files: _copyOf(context).files));
}

@widgetbook.UseCase(
  name: 'Table — desktop',
  type: FilesTable,
  path: '[Proposals]/Files',
)
Widget tableDesktopUseCase(BuildContext context) {
  return _Surface(width: 960, child: FilesTable(files: _copyOf(context).files));
}

@widgetbook.UseCase(
  name: 'Table — mobile (compact)',
  type: FilesTable,
  path: '[Proposals]/Files',
)
Widget tableMobileUseCase(BuildContext context) {
  return _Surface(width: 380, child: FilesTable(files: _copyOf(context).files));
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared destructive-op helpers
// ═══════════════════════════════════════════════════════════════════════════

Future<bool> _confirmDelete(BuildContext context, int n, _Copy c) async {
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

class _UndoStash {
  const _UndoStash(this.message, this.removed, this.priorSelection);
  final String message;
  final List<MapEntry<int, _File>> removed;
  final Set<String> priorSelection;
}

// ═══════════════════════════════════════════════════════════════════════════
// PROPOSAL 1 — Grid
// ═══════════════════════════════════════════════════════════════════════════

class FilesGrid extends StatefulWidget {
  const FilesGrid({super.key, required this.files});

  final List<_File> files;

  @override
  State<FilesGrid> createState() => _FilesGridState();
}

class _FilesGridState extends State<FilesGrid> {
  late List<_File> _files = [...widget.files];
  Set<String> _selected = {};
  _UndoStash? _undo;

  void _toggle(String id, bool on) =>
      setState(() => on ? _selected.add(id) : _selected.remove(id));

  void _remove(Set<String> ids, String message) {
    final removed = <MapEntry<int, _File>>[];
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
      _undo = _UndoStash(message, removed, prior);
    });
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
  }

  Future<void> _delete(Set<String> ids) async {
    final c = _copyOf(context);
    if (await _confirmDelete(context, ids.length, c) && mounted) {
      _remove(ids, c.deletedMsg(ids.length));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final c = _copyOf(context);

    if (_files.isEmpty && _undo == null) {
      return _EmptyState(copy: c);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Self-adjusting column count: ~200dp tiles, 2 on phones, more on wide.
        final cols = (constraints.maxWidth / 200).floor().clamp(2, 6);
        final gap = spacing.md;
        final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selected.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.sm),
                child: _BulkBar(
                  count: _selected.length,
                  copy: c,
                  onClear: () => setState(() => _selected = {}),
                  onMove: () {},
                  onDownload: () {},
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
                      copy: c,
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
                child: _UndoBar(
                  message: _undo!.message,
                  copy: c,
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

  Future<void> _fileAction(_File f, _FileAction a) async {
    switch (a) {
      case _FileAction.open:
      case _FileAction.moveToMatome:
      case _FileAction.download:
        break;
      case _FileAction.delete:
        await _delete({f.id});
    }
  }
}

class _FileTile extends StatefulWidget {
  const _FileTile({
    required this.file,
    required this.copy,
    required this.selected,
    required this.onSelect,
    required this.onAction,
  });

  final _File file;
  final _Copy copy;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final ValueChanged<_FileAction> onAction;

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
    final c = widget.copy;
    final vis = _kindVisual(context, f);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onAction(_FileAction.open),
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
              // (Image kind would render a real thumbnail in the host.)
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: Container(
                      color: vis.color.withValues(alpha: 0.10),
                      child: Center(
                        child: Icon(vis.icon, size: 34, color: vis.color),
                      ),
                    ),
                  ),
                  // Selection checkbox — appears on hover or when selected.
                  if (_hovered || widget.selected)
                    Positioned(
                      top: spacing.xxs,
                      left: spacing.xxs,
                      child: _TileCheckbox(
                        value: widget.selected,
                        label: c.selectFile,
                        onChanged: widget.onSelect,
                      ),
                    ),
                  // Audio duration overlay.
                  if (f.duration != null)
                    Positioned(
                      right: spacing.xs,
                      bottom: spacing.xs,
                      child: _DurationTag(label: f.duration!),
                    ),
                  // Per-file overflow on hover.
                  if (_hovered)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _FileActionsMenu(
                        copy: c,
                        onAction: widget.onAction,
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
                        Text(
                          f.sizeLabel,
                          style: typography.label
                              .copyWith(color: colors.textMuted),
                        ),
                        Text(' · ',
                            style: typography.label
                                .copyWith(color: colors.textMuted)),
                        Text(
                          f.when,
                          style: typography.label
                              .copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing.xs),
                    // Matome + sync on one line, Space on the next — two
                    // distinct relationships, stacked so neither is truncated.
                    Row(
                      children: [
                        Flexible(child: _MatomeChip(file: f, copy: c)),
                        SizedBox(width: spacing.xs),
                        _SyncDot(rollup: f.rollup),
                      ],
                    ),
                    SizedBox(height: spacing.xxs),
                    Row(
                      children: [
                        Flexible(child: _SpaceChip(file: f, copy: c)),
                        if (f.contacts.isNotEmpty) ...[
                          SizedBox(width: spacing.xs),
                          _PeopleCluster(names: f.contacts, size: 20),
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
  const _TileCheckbox({
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

// ═══════════════════════════════════════════════════════════════════════════
// PROPOSAL 2 — Table
// ═══════════════════════════════════════════════════════════════════════════

const double _wCheck = 44;
const double _wMatome = 148;
const double _wSpace = 112;
const double _wPeople = 84;
const double _wWhen = 64;
const double _wSize = 72;
const double _wSync = 112;
const double _wActions = 40;
const double _kCompactBreakpoint = 720;

class FilesTable extends StatefulWidget {
  const FilesTable({super.key, required this.files});

  final List<_File> files;

  @override
  State<FilesTable> createState() => _FilesTableState();
}

class _FilesTableState extends State<FilesTable> {
  late List<_File> _files = [...widget.files];
  Set<String> _selected = {};
  _SortKey _sortKey = _SortKey.when;
  bool _ascending = false;
  _UndoStash? _undo;

  List<_File> get _sorted {
    final view = [..._files];
    int cmp(_File a, _File b) {
      final v = switch (_sortKey) {
        _SortKey.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _SortKey.when => a.whenSort.compareTo(b.whenSort),
        _SortKey.size => a.sizeSort.compareTo(b.sizeSort),
      };
      return _ascending ? v : -v;
    }

    view.sort(cmp);
    return view;
  }

  void _toggleSort(_SortKey key) => setState(() {
        if (_sortKey == key) {
          _ascending = !_ascending;
        } else {
          _sortKey = key;
          _ascending = key == _SortKey.name;
        }
      });

  void _toggleRow(String id, bool on) =>
      setState(() => on ? _selected.add(id) : _selected.remove(id));

  void _toggleAll(bool? on) => setState(() {
        _selected = (on ?? false) ? _files.map((f) => f.id).toSet() : <String>{};
      });

  void _remove(Set<String> ids, String message) {
    final removed = <MapEntry<int, _File>>[];
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
      _undo = _UndoStash(message, removed, prior);
    });
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
  }

  Future<void> _delete(Set<String> ids) async {
    final c = _copyOf(context);
    if (await _confirmDelete(context, ids.length, c) && mounted) {
      _remove(ids, c.deletedMsg(ids.length));
    }
  }

  Future<void> _fileAction(_File f, _FileAction a) async {
    switch (a) {
      case _FileAction.open:
      case _FileAction.moveToMatome:
      case _FileAction.download:
        break;
      case _FileAction.delete:
        await _delete({f.id});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final c = _copyOf(context);

    if (_files.isEmpty && _undo == null) {
      return _TableShell(child: _EmptyState(copy: c));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _kCompactBreakpoint;
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
                _BulkBar(
                  count: _selected.length,
                  copy: c,
                  onClear: () => setState(() => _selected = {}),
                  onMove: () {},
                  onDownload: () {},
                  onDelete: () => _delete({..._selected}),
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
                        file: rows[i],
                        selected: _selected.contains(rows[i].id),
                        copy: c,
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _fileAction(rows[i], a),
                      )
                    : _DataRow(
                        file: rows[i],
                        selected: _selected.contains(rows[i].id),
                        copy: c,
                        onSelect: (on) => _toggleRow(rows[i].id, on),
                        onAction: (a) => _fileAction(rows[i], a),
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
            child: Checkbox(
              value: allSelected ? true : (someSelected ? null : false),
              tristate: true,
              onChanged: onToggleAll,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: BorderSide(color: colors.textMuted, width: 1.5),
              activeColor: colors.textPrimary,
            ),
          ),
          Expanded(
            child: _SortHeader(
              label: copy.colName,
              active: sortKey == _SortKey.name,
              ascending: ascending,
              onTap: () => onSort(_SortKey.name),
            ),
          ),
          SizedBox(width: _wMatome, child: _ColLabel(copy.colMatome)),
          SizedBox(width: _wSpace, child: _ColLabel(copy.colSpace)),
          SizedBox(width: _wPeople, child: _ColLabel(copy.colPeople)),
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
            width: _wSize,
            child: _SortHeader(
              label: copy.colSize,
              active: sortKey == _SortKey.size,
              ascending: ascending,
              alignEnd: true,
              onTap: () => onSort(_SortKey.size),
            ),
          ),
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

class _DataRow extends StatefulWidget {
  const _DataRow({
    required this.file,
    required this.selected,
    required this.copy,
    required this.onSelect,
    required this.onAction,
  });

  final _File file;
  final bool selected;
  final _Copy copy;
  final ValueChanged<bool> onSelect;
  final ValueChanged<_FileAction> onAction;

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
    final c = widget.copy;
    final vis = _kindVisual(context, f);

    final bg = widget.selected
        ? colors.accentSoft.withValues(alpha: 0.5)
        : (_hovered ? colors.subtleFill : colors.surface);

    return _RowFocus(
      focused: _focused,
      onFocusChange: (v) => setState(() => _focused = v),
      onActivate: () => widget.onAction(_FileAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onAction(_FileAction.open),
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
                    label: c.selectFile,
                    onChanged: widget.onSelect,
                  ),
                ),
                // Name + type icon.
                Expanded(
                  child: Row(
                    children: [
                      Icon(vis.icon, size: 18, color: vis.color),
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
                    child: _MatomeChip(file: f, copy: c),
                  ),
                ),
                SizedBox(
                  width: _wSpace,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SpaceChip(file: f, copy: c),
                  ),
                ),
                SizedBox(
                  width: _wPeople,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: f.contacts.isEmpty
                        ? Text(
                            '—',
                            style: typography.label
                                .copyWith(color: colors.textMuted),
                          )
                        : _PeopleCluster(names: f.contacts, size: 24),
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
                    f.sizeLabel,
                    textAlign: TextAlign.right,
                    style:
                        typography.label.copyWith(color: colors.textSecondary),
                  ),
                ),
                SizedBox(
                  width: _wSync,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SyncChip(rollup: f.rollup, copy: c),
                  ),
                ),
                SizedBox(
                  width: _wActions,
                  child: _FileActionsMenu(copy: c, onAction: widget.onAction),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          onActivate();
          return null;
        }),
        _ToggleSelectIntent: CallbackAction<_ToggleSelectIntent>(onInvoke: (_) {
          onToggleSelect();
          return null;
        }),
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

class _ToggleSelectIntent extends Intent {
  const _ToggleSelectIntent();
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

// ─── Compact (mobile) table rows ─────────────────────────────────────────────

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
      (_SortKey.name, copy.colName),
      (_SortKey.size, copy.colSize),
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
          border: Border.all(color: active ? colors.textPrimary : colors.border),
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
    required this.file,
    required this.selected,
    required this.copy,
    required this.onSelect,
    required this.onAction,
  });

  final _File file;
  final bool selected;
  final _Copy copy;
  final ValueChanged<bool> onSelect;
  final ValueChanged<_FileAction> onAction;

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
    final c = widget.copy;
    final vis = _kindVisual(context, f);

    return _RowFocus(
      focused: _focused,
      onFocusChange: (v) => setState(() => _focused = v),
      onActivate: () => widget.onAction(_FileAction.open),
      onToggleSelect: () => widget.onSelect(!widget.selected),
      child: GestureDetector(
        onTap: () => widget.onAction(_FileAction.open),
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
                  label: c.selectFile,
                  onChanged: widget.onSelect,
                ),
              ),
              Icon(vis.icon, size: 20, color: vis.color),
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
                          style:
                              typography.label.copyWith(color: colors.textMuted),
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
                          f.sizeLabel,
                          style:
                              typography.label.copyWith(color: colors.textMuted),
                        ),
                        _MatomeChip(file: f, copy: c),
                        _SpaceChip(file: f, copy: c),
                        if (f.contacts.isNotEmpty)
                          _PeopleCluster(names: f.contacts, size: 20),
                        _SyncChip(rollup: f.rollup, copy: c),
                      ],
                    ),
                  ],
                ),
              ),
              _FileActionsMenu(copy: c, onAction: widget.onAction),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared cell / chrome widgets
// ═══════════════════════════════════════════════════════════════════════════

/// The matome / Unfiled chip — the file's relationship to a matome, the thing
/// the Files view exists to make visible.
class _MatomeChip extends StatelessWidget {
  const _MatomeChip({required this.file, required this.copy});

  final _File file;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final filed = !file.unfiled;
    final icon = filed ? Icons.workspaces_outlined : Icons.inbox_outlined;
    final label = filed ? file.matome! : copy.unfiled;
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
              style: typography.label.copyWith(
                color: color,
                fontStyle: filed ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Space (folder) chip — INDEPENDENT of the matome chip. Rendered outlined
/// (vs the matome chip's filled pill) so the two relationships read as distinct
/// categories at a glance. Null space → Inbox.
class _SpaceChip extends StatelessWidget {
  const _SpaceChip({required this.file, required this.copy});

  final _File file;
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final filed = !file.inInbox;
    final icon = filed ? Icons.folder_outlined : Icons.inbox_outlined;
    final label = filed ? file.space! : copy.inbox;
    final color = filed ? colors.textSecondary : colors.textMuted;

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xxs),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius.pill),
        border: Border.all(color: colors.border),
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
              style: typography.label.copyWith(
                color: color,
                fontStyle: filed ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// People tagged on a file, as an overlapping avatar cluster (initials), with a
/// "+N" overflow and a tooltip listing the names. The contact relationship is
/// INDEPENDENT of matome and space. Empty list renders nothing (callers that
/// need a placeholder add their own dash).
class _PeopleCluster extends StatelessWidget {
  const _PeopleCluster({required this.names, this.size = 22});

  final List<String> names;
  static const int maxShown = 3;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();

    final shown = names.take(maxShown).toList();
    final extra = names.length - shown.length;
    final overlap = size * 0.62;
    final slots = shown.length + (extra > 0 ? 1 : 0);
    final width = size + (slots - 1) * overlap;

    return Tooltip(
      message: names.join(', '),
      child: SizedBox(
        width: width,
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: i * overlap,
                child: _MiniAvatar(label: shown[i].characters.first, size: size),
              ),
            if (extra > 0)
              Positioned(
                left: shown.length * overlap,
                child: _MiniAvatar(
                  label: '+$extra',
                  size: size,
                  emphasized: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({
    required this.label,
    required this.size,
    this.emphasized = false,
  });

  final String label;
  final double size;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: emphasized ? colors.textPrimary : colors.subtleFillStrong,
        shape: BoxShape.circle,
        // Ring in the surface colour separates overlapping avatars.
        border: Border.all(color: colors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: typography.label.copyWith(
          color: emphasized ? colors.onTextPrimary : colors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
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

/// A bare sync dot for the dense grid footer (icon only, tooltip-labelled).
class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.rollup});
  final MatomeSyncRollup rollup;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (IconData icon, Color color) = switch (rollup) {
      MatomeSyncRollup.cloud => (Icons.cloud_done_outlined, colors.badgePersonal),
      MatomeSyncRollup.partial => (
          Icons.cloud_sync_outlined,
          colors.textSecondary
        ),
      MatomeSyncRollup.onDevice => (Icons.cloud_off_outlined, colors.textMuted),
    };
    return Icon(icon, size: 15, color: color);
  }
}

class _FileActionsMenu extends StatelessWidget {
  const _FileActionsMenu({required this.copy, required this.onAction});

  final _Copy copy;
  final ValueChanged<_FileAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget item(IconData icon, String label, _FileAction action,
        {Color? color}) {
      return MenuItemButton(
        leadingIcon: Icon(icon, size: 18, color: color ?? colors.textSecondary),
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
        padding:
            WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: spacing.xs)),
      ),
      builder: (context, controller, child) => IconButton(
        icon: Icon(Icons.more_horiz, size: 18, color: colors.textMuted),
        tooltip: copy.fileActions,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        visualDensity: VisualDensity.compact,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        item(Icons.open_in_new, copy.open, _FileAction.open),
        item(Icons.drive_file_move_outlined, copy.moveToMatome,
            _FileAction.moveToMatome),
        item(Icons.download_outlined, copy.download, _FileAction.download),
        Divider(height: spacing.sm, color: colors.border),
        item(Icons.delete_outline, copy.delete, _FileAction.delete,
            color: colors.failed),
      ],
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.copy,
    required this.onClear,
    required this.onMove,
    required this.onDownload,
    required this.onDelete,
  });

  final int count;
  final _Copy copy;
  final VoidCallback onClear;
  final VoidCallback onMove;
  final VoidCallback onDownload;
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
          IconButton(
            icon: Icon(Icons.close, size: 18, color: colors.accentDark),
            visualDensity: VisualDensity.compact,
            tooltip: copy.clear,
            onPressed: onClear,
          ),
          SizedBox(width: spacing.xxs),
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
                label: copy.moveToMatome,
                onPressed: onMove,
              ),
              _BulkAction(
                icon: Icons.download_outlined,
                label: copy.download,
                onPressed: onDownload,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.copy});
  final _Copy copy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.lg, vertical: spacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, size: 32, color: colors.border),
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

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.width = 960});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: child,
        ),
      ),
    );
  }
}
