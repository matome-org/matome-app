// Proposal use-cases for the redesigned Matome detail screen (the "letter"
// direction): a calm, read-first card that summarizes attachments / people /
// status, with a "Show more" affordance that opens a detail side panel for
// management. These are static mockups for design approval — no providers, no
// DB. Once approved, the real screen mirrors these compositions.
//
// Sync vocabulary is normalized here per the critique decision: one word per
// state across every surface — Synced / Syncing / On device.
//
// Copy switches with the Widgetbook Localization addon (en / ja) via
// Localizations.localeOf — the mockup carries its own EN/JA bundle rather than
// wiring slang, so it renders standalone.

import 'package:flutter/material.dart';
import 'package:matome_flutter/core/db/matome_card.dart' show MatomeSyncRollup;
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/app_card.dart' show MatomeSyncChip;
import 'package:matome_flutter/ui/matome_detail_panel.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// ─── Localized sample copy ───────────────────────────────────────────────────

enum LetterSync { synced, syncing, onDevice }

class _Copy {
  const _Copy({
    required this.title,
    required this.date,
    required this.summary,
    required this.filesLabel,
    required this.peopleLabel,
    required this.spaceLabel,
    required this.statusLabel,
    required this.attachPreview,
    required this.fileCta,
    required this.showMore,
    required this.detail,
    required this.itemsLabel,
    required this.contactsLabel,
    required this.notesLabel,
    required this.refile,
    required this.edit,
    required this.share,
    required this.addItem,
    required this.addContact,
    required this.itemTitles,
    required this.roleOrganizer,
    required this.roleAttendee,
    required this.notesBody,
    required this.rename,
    required this.editDateTime,
    required this.regenerateSummary,
    required this.moveToSpace,
    required this.soon,
    required this.copySummary,
    required this.deleteMatome,
    required this.sectionToday,
    required this.sectionYesterday,
    required this.inboxLabel,
    required this.noSummary,
  });

  final String title;
  final String date;
  final String summary;
  final String filesLabel;
  final String peopleLabel;
  final String spaceLabel;
  final String statusLabel;
  final String attachPreview;
  final String fileCta;
  final String showMore;
  final String detail;
  final String itemsLabel;
  final String contactsLabel;
  final String notesLabel;
  final String refile;
  final String edit;
  final String share;
  final String addItem;
  final String addContact;
  final List<String> itemTitles;
  final String roleOrganizer;
  final String roleAttendee;
  final String notesBody;
  final String rename;
  final String editDateTime;
  final String regenerateSummary;
  final String moveToSpace;
  final String soon;
  final String copySummary;
  final String deleteMatome;
  final String sectionToday;
  final String sectionYesterday;
  final String inboxLabel;
  final String noSummary;

  static const en = _Copy(
    title: 'Client X — weekly sync',
    date: 'Jun 20, 2026 · 2:30 PM',
    summary:
        "Today's sync approved the Q3 budget. Ken will draft the proposal "
        'before the next meeting. The parking question was pushed to next time.',
    filesLabel: 'Files',
    peopleLabel: 'People',
    spaceLabel: 'Space',
    statusLabel: 'Status',
    attachPreview: 'Meeting audio · Side notes · +1',
    fileCta: 'File into space',
    showMore: 'Show more',
    detail: 'Details',
    itemsLabel: 'Items',
    contactsLabel: 'People',
    notesLabel: 'Notes',
    refile: 'Refile',
    edit: 'Edit',
    share: 'Share',
    addItem: 'Add item',
    addContact: 'Add person',
    itemTitles: ['Meeting audio', 'Side notes', 'Whiteboard'],
    roleOrganizer: 'Organizer',
    roleAttendee: 'Attendee',
    notesBody:
        'Underground parking open until 6 PM. Pick up a visitor pass at '
        'reception.',
    rename: 'Rename',
    editDateTime: 'Edit date & time',
    regenerateSummary: 'Regenerate summary',
    moveToSpace: 'Move to space',
    soon: 'soon',
    copySummary: 'Copy summary',
    deleteMatome: 'Delete matome',
    sectionToday: 'Today',
    sectionYesterday: 'Yesterday',
    inboxLabel: 'Inbox',
    noSummary: 'No summary yet',
  );

  static const ja = _Copy(
    title: 'クライアントX 定例会議',
    date: '2026年6月20日 14:30',
    summary: '本日の定例会議では Q3 予算が承認されました。Ken さんが次回までに'
        '提案書を作成します。駐車場の件は次回に持ち越しとなりました。',
    filesLabel: '添付',
    peopleLabel: '関係者',
    spaceLabel: '保存先',
    statusLabel: '状態',
    attachPreview: '会議音声 · 補足メモ · +1',
    fileCta: '空間に整理',
    showMore: 'もっと見る',
    detail: '詳細',
    itemsLabel: '項目',
    contactsLabel: '連絡先',
    notesLabel: 'メモ',
    refile: '整理',
    edit: '編集',
    share: '共有',
    addItem: '項目を追加',
    addContact: '連絡先を追加',
    itemTitles: ['会議音声', '補足メモ', 'ホワイトボード'],
    roleOrganizer: '主催者',
    roleAttendee: '出席者',
    notesBody: '地下駐車場は18時まで利用可能。受付で入館証を受け取ること。',
    rename: '名前を変更',
    editDateTime: '日時を編集',
    regenerateSummary: '要約を再生成',
    moveToSpace: '空間へ移動',
    soon: '近日',
    copySummary: '要約をコピー',
    deleteMatome: 'まとめを削除',
    sectionToday: '今日',
    sectionYesterday: '昨日',
    inboxLabel: '受信箱',
    noSummary: '要約はまだありません',
  );
}

_Copy _copyOf(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ja'
      ? _Copy.ja
      : _Copy.en;
}

const _kPeople = <String>['Ana', 'Ken'];

class _Item {
  const _Item(this.icon, this.time, this.duration, this.sync);
  final IconData icon;
  final String time;
  final String? duration;
  final LetterSync sync;
}

const _kItems = <_Item>[
  _Item(Icons.mic_none_rounded, '14:30', '12:04', LetterSync.synced),
  _Item(Icons.mic_none_rounded, '14:55', '03:20', LetterSync.syncing),
  _Item(Icons.image_outlined, '15:10', null, LetterSync.synced),
];

// ─── Use cases ───────────────────────────────────────────────────────────────

@widgetbook.UseCase(
  name: 'Letter — filed & synced',
  type: MatomeLetterCard,
  path: '[Proposals]/Matome detail',
)
Widget letterFiledSyncedUseCase(BuildContext context) {
  return const _Surface(
    child: MatomeLetterCard(
      space: 'Marketing',
      rollup: LetterSync.synced,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Letter — inbox & syncing',
  type: MatomeLetterCard,
  path: '[Proposals]/Matome detail',
)
Widget letterInboxSyncingUseCase(BuildContext context) {
  return const _Surface(
    child: MatomeLetterCard(
      space: null, // inbox → File CTA
      rollup: LetterSync.syncing,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Letter — on device',
  type: MatomeLetterCard,
  path: '[Proposals]/Matome detail',
)
Widget letterOnDeviceUseCase(BuildContext context) {
  return const _Surface(
    child: MatomeLetterCard(
      space: null,
      rollup: LetterSync.onDevice,
    ),
  );
}

@widgetbook.UseCase(
  name: 'Detail panel',
  type: MatomeDetailPanel,
  path: '[Proposals]/Matome detail',
)
Widget detailPanelUseCase(BuildContext context) {
  return const _Surface(width: 380, child: MatomeDetailPanel());
}

@widgetbook.UseCase(
  name: 'Letter + panel (wide)',
  type: MatomeLetterCard,
  path: '[Proposals]/Matome detail',
)
Widget letterWithPanelWideUseCase(BuildContext context) {
  final colors = context.colors;
  return _Surface(
    width: 920,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: MatomeLetterCard(
            space: 'Marketing',
            rollup: LetterSync.synced,
            showMore: false,
          ),
        ),
        SizedBox(width: context.spacing.lg),
        SizedBox(
          width: 360,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(context.radius.lg),
              border: Border.all(color: colors.border),
            ),
            child: const MatomeDetailPanel(),
          ),
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Actions menu (…)',
  type: MatomeActionsMenu,
  path: '[Proposals]/Matome detail',
)
Widget actionsMenuUseCase(BuildContext context) {
  final colors = context.colors;
  final typography = context.typography;
  return _Surface(
    width: 320,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Tap the … button',
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            MatomeActionsMenu(onAction: (_) {}),
          ],
        ),
      ),
    ),
  );
}

// ─── The letter card ─────────────────────────────────────────────────────────

class MatomeLetterCard extends StatelessWidget {
  const MatomeLetterCard({
    super.key,
    required this.space,
    required this.rollup,
    this.showMore = true,
  });

  /// Filed space name, or null when the Matome is still in the Inbox.
  final String? space;
  final LetterSync rollup;
  final bool showMore;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final c = _copyOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title + overflow.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.title,
                  style: typography.title.copyWith(color: colors.textPrimary),
                ),
              ),
              MatomeActionsMenu(onAction: (_) {}),
            ],
          ),
          SizedBox(height: spacing.xs),
          Row(
            children: [
              Icon(Icons.schedule, size: spacing.md, color: colors.textMuted),
              SizedBox(width: spacing.xs),
              Text(
                c.date,
                style: typography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),

          SizedBox(height: spacing.lg),

          // Letter body = the aggregated summary, the hero of the card.
          Text(
            c.summary,
            style: typography.body.copyWith(color: colors.textPrimary),
          ),

          SizedBox(height: spacing.lg),
          Divider(height: 1, color: colors.border),
          SizedBox(height: spacing.md),

          // Summarized lists — one line each: icon · label·count · preview.
          _MetaRow(
            icon: Icons.attach_file,
            label: '${c.filesLabel} · ${_kItems.length}',
            preview: c.attachPreview,
          ),
          SizedBox(height: spacing.sm),
          _MetaRow(
            icon: Icons.people_outline,
            label: '${c.peopleLabel} · ${_kPeople.length}',
            preview: _kPeople.join(' · '),
          ),
          SizedBox(height: spacing.sm),
          _FilingRow(space: space),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  c.statusLabel,
                  style: typography.label.copyWith(color: colors.textMuted),
                ),
              ),
              _SyncChip(rollup: rollup),
            ],
          ),

          if (showMore) ...[
            SizedBox(height: spacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {},
                icon: Text(c.showMore),
                label: const Icon(Icons.chevron_right, size: 18),
                style: TextButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  textStyle: typography.label,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.preview,
  });

  final IconData icon;
  final String label;
  final String preview;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Row(
            children: [
              Icon(icon, size: spacing.md, color: colors.textMuted),
              SizedBox(width: spacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: typography.label.copyWith(color: colors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            preview,
            style: typography.bodySmall.copyWith(color: colors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _FilingRow extends StatelessWidget {
  const _FilingRow({required this.space});

  final String? space;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final c = _copyOf(context);

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: spacing.md,
                color: colors.textMuted,
              ),
              SizedBox(width: spacing.xs),
              Flexible(
                child: Text(
                  c.spaceLabel,
                  style: typography.label.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (space != null)
          Expanded(
            child: Text(
              space!,
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          // Inbox → filing CTA in place of the value.
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.textPrimary,
              borderRadius: BorderRadius.circular(radius.pill),
            ),
            child: Text(
              c.fileCta,
              style: typography.label.copyWith(color: colors.onTextPrimary),
            ),
          ),
      ],
    );
  }
}

// ─── Matome actions overflow menu ("…") ──────────────────────────────────────

/// Matome-level secondary / rare / destructive actions, hung off the header
/// "…" button. Primary actions (file, add item, add contact, edit notes) live
/// inline in the letter / detail panel, not here.
enum MatomeAction {
  rename,
  editDateTime,
  regenerateSummary,
  moveToSpace,
  share,
  copySummary,
  delete,
}

class MatomeActionsMenu extends StatelessWidget {
  const MatomeActionsMenu({
    super.key,
    required this.onAction,
    this.dense = false,
  });

  final ValueChanged<MatomeAction> onAction;

  /// Tighter trigger for list rows (smaller icon, no padding, 32px target).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final c = _copyOf(context);

    Widget itemLabel(String text, {Color? color}) => Text(
          text,
          style: typography.bodySmall.copyWith(
            color: color ?? colors.textPrimary,
          ),
        );

    Icon icon(IconData data, {Color? color}) =>
        Icon(data, size: 18, color: color ?? colors.textSecondary);

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
      builder: (context, controller, child) {
        return IconButton(
          icon: Icon(
            Icons.more_horiz,
            size: dense ? 18 : 24,
            color: colors.textMuted,
          ),
          tooltip: 'More',
          padding: dense ? EdgeInsets.zero : null,
          constraints:
              dense ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
          visualDensity: dense ? VisualDensity.compact : null,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: icon(Icons.edit_outlined),
          onPressed: () => onAction(MatomeAction.rename),
          child: itemLabel(c.rename),
        ),
        MenuItemButton(
          leadingIcon: icon(Icons.event_outlined),
          onPressed: () => onAction(MatomeAction.editDateTime),
          child: itemLabel(c.editDateTime),
        ),
        Divider(height: spacing.sm, color: colors.border),
        MenuItemButton(
          leadingIcon: icon(Icons.refresh),
          onPressed: () => onAction(MatomeAction.regenerateSummary),
          child: itemLabel(c.regenerateSummary),
        ),
        MenuItemButton(
          leadingIcon: icon(Icons.drive_file_move_outlined),
          onPressed: () => onAction(MatomeAction.moveToSpace),
          child: itemLabel(c.moveToSpace),
        ),
        Divider(height: spacing.sm, color: colors.border),
        // Share is deferred — disabled with a "soon" trailing tag.
        MenuItemButton(
          leadingIcon: icon(Icons.share_outlined, color: colors.textMuted),
          trailingIcon: Text(
            c.soon,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          onPressed: null,
          child: itemLabel(c.share, color: colors.textMuted),
        ),
        MenuItemButton(
          leadingIcon: icon(Icons.copy_outlined),
          onPressed: () => onAction(MatomeAction.copySummary),
          child: itemLabel(c.copySummary),
        ),
        Divider(height: spacing.sm, color: colors.border),
        MenuItemButton(
          leadingIcon: icon(Icons.delete_outline, color: colors.failed),
          onPressed: () => onAction(MatomeAction.delete),
          child: itemLabel(c.deleteMatome, color: colors.failed),
        ),
      ],
    );
  }
}

// ─── Sync chip (single normalized vocabulary) ────────────────────────────────

class _SyncChip extends StatelessWidget {
  const _SyncChip({required this.rollup});

  final LetterSync rollup;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final (IconData icon, String label, Color color) = switch (rollup) {
      LetterSync.synced => (
        Icons.cloud_done_outlined,
        'Synced',
        colors.badgePersonal,
      ),
      LetterSync.syncing => (
        Icons.cloud_sync_outlined,
        'Syncing',
        colors.textSecondary,
      ),
      LetterSync.onDevice => (
        Icons.cloud_off_outlined,
        'On device',
        colors.textMuted,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          SizedBox(width: spacing.xs),
          Text(label, style: typography.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─── The detail side panel ───────────────────────────────────────────────────
//
// CONVERGED (#1458): this catalog panel now composes the REAL, PUBLIC panel
// scaffolding shipped in `package:matome_flutter/ui/matome_detail_panel.dart`
// (MatomePanelSection / MatomePanelRow / MatomePanelAddRow) and the REAL
// `MatomeSyncChip` — the SAME widgets the live `_MatomeDetails` composes. There
// is no longer a hand-built mock of the panel structure to drift from the app;
// only the SAMPLE DATA lives here. Edit the section widgets in `lib/ui` and both
// the app and this catalog entry move together.

class MatomeDetailPanel extends StatelessWidget {
  const MatomeDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final c = _copyOf(context);

    MatomeSyncChip chipFor(LetterSync sync) => MatomeSyncChip(
          rollup: switch (sync) {
            LetterSync.synced => MatomeSyncRollup.cloud,
            LetterSync.syncing => MatomeSyncRollup.partial,
            LetterSync.onDevice => MatomeSyncRollup.onDevice,
          },
        );

    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                c.detail,
                style: typography.title.copyWith(color: colors.textPrimary),
              ),
              const Spacer(),
              Icon(Icons.close, size: spacing.md, color: colors.textMuted),
            ],
          ),
          SizedBox(height: spacing.md),

          // Items · N — compact rows (leading icon · title · time/duration ·
          // trailing sync chip) + the accent Add row, via the real widgets.
          MatomePanelSection(
            label: '${c.itemsLabel} · ${_kItems.length}',
            child: Column(
              children: [
                for (var i = 0; i < _kItems.length; i++)
                  MatomePanelRow(
                    icon: _kItems[i].icon,
                    title: c.itemTitles[i],
                    meta: _kItems[i].duration == null
                        ? _kItems[i].time
                        : '${_kItems[i].time} · ${_kItems[i].duration}',
                    trailing: chipFor(_kItems[i].sync),
                  ),
                SizedBox(height: spacing.xs),
                MatomePanelAddRow(label: c.addItem),
              ],
            ),
          ),

          // People · N — contact rows + Add person.
          MatomePanelSection(
            label: '${c.contactsLabel} · ${_kPeople.length}',
            child: Column(
              children: [
                MatomePanelRow(
                  icon: Icons.person_outline,
                  leading: CircleAvatar(
                    radius: spacing.md,
                    backgroundColor: colors.subtleFill,
                    child: Text(
                      'A',
                      style: typography.label
                          .copyWith(color: colors.textSecondary),
                    ),
                  ),
                  title: 'Ana',
                  meta: c.roleOrganizer,
                  trailing:
                      Icon(Icons.close, size: spacing.md, color: colors.textMuted),
                ),
                MatomePanelRow(
                  icon: Icons.person_outline,
                  leading: CircleAvatar(
                    radius: spacing.md,
                    backgroundColor: colors.subtleFill,
                    child: Text(
                      'K',
                      style: typography.label
                          .copyWith(color: colors.textSecondary),
                    ),
                  ),
                  title: 'Ken',
                  meta: c.roleAttendee,
                  trailing:
                      Icon(Icons.close, size: spacing.md, color: colors.textMuted),
                ),
                SizedBox(height: spacing.xs),
                MatomePanelAddRow(
                  icon: Icons.person_add_alt_outlined,
                  label: c.addContact,
                ),
              ],
            ),
          ),

          // Space — filed space + Refile accent action.
          MatomePanelSection(
            label: c.spaceLabel,
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: spacing.md,
                  color: colors.textSecondary,
                ),
                SizedBox(width: spacing.xs),
                Text(
                  'Marketing',
                  style: typography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  c.refile,
                  style: typography.label.copyWith(color: colors.accent),
                ),
              ],
            ),
          ),

          // Notes — body + inline accent "Edit", no trailing divider.
          MatomePanelSection(
            label: c.notesLabel,
            showDivider: false,
            trailing: Text(
              c.edit,
              style: typography.label.copyWith(color: colors.accent),
            ),
            child: Text(
              c.notesBody,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ),

          // Share — deferred row.
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ios_share, size: spacing.md, color: colors.textPrimary),
                SizedBox(width: spacing.xs),
                Text(
                  c.share,
                  style: typography.label.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Matome list (the reworked "table") ──────────────────────────────────────
//
// Same concepts as the letter: each row is a tiny envelope — title + a one-line
// summary preview + a dense meta strip (item mix · people · space/inbox · sync).
// The sync chip shows on EVERY row (filed or inbox), so the list answers
// "is it backed up?" at a glance, with the one normalized vocabulary.

class _Row {
  const _Row({
    required this.title,
    required this.summary,
    required this.time,
    required this.audio,
    required this.image,
    required this.people,
    required this.space,
    required this.rollup,
  });

  final String title;
  final String summary; // empty → "No summary yet"
  final String time;
  final int audio;
  final int image;
  final int people;
  final String? space; // null → Inbox
  final LetterSync rollup;
}

class _Section {
  const _Section(this.label, this.rows);
  final String label;
  final List<_Row> rows;
}

List<_Section> _sampleSections(BuildContext context) {
  final c = _copyOf(context);
  final ja = Localizations.localeOf(context).languageCode == 'ja';

  return [
    _Section(c.sectionToday, [
      _Row(
        title: ja ? 'クライアントX 定例会議' : 'Client X — weekly sync',
        summary: ja
            ? 'Q3 予算が承認。Ken が提案書を作成。'
            : 'Q3 budget approved. Ken to draft the proposal.',
        time: ja ? '2時間前' : '2h',
        audio: 2,
        image: 1,
        people: 2,
        space: 'Marketing',
        rollup: LetterSync.synced,
      ),
      _Row(
        title: ja ? 'デザインレビュー' : 'Design review',
        summary: ja
            ? '新しいオンボーディング画面を確認中。'
            : 'Walking through the new onboarding screens.',
        time: ja ? '4時間前' : '4h',
        audio: 1,
        image: 0,
        people: 1,
        space: null, // inbox
        rollup: LetterSync.syncing,
      ),
      _Row(
        title: ja ? '音声メモ' : 'Quick voice memo',
        summary: '', // no summary yet
        time: ja ? '5時間前' : '5h',
        audio: 1,
        image: 0,
        people: 0,
        space: null,
        rollup: LetterSync.onDevice,
      ),
    ]),
    _Section(c.sectionYesterday, [
      _Row(
        title: ja ? '商談 — Acme' : 'Sales call — Acme',
        summary: ja
            ? '契約は来四半期へ。条件を再確認。'
            : 'Deal slips to next quarter. Revisit the terms.',
        time: ja ? '昨日' : '1d',
        audio: 1,
        image: 0,
        people: 3,
        space: 'Sales',
        rollup: LetterSync.synced,
      ),
      _Row(
        title: ja ? 'ワークショップ メモ' : 'Workshop notes',
        summary: ja
            ? 'ロードマップの優先順位付け演習。'
            : 'Roadmap prioritisation exercise with the team.',
        time: ja ? '昨日' : '1d',
        audio: 3,
        image: 2,
        people: 4,
        space: 'Product',
        rollup: LetterSync.syncing,
      ),
    ]),
  ];
}

@widgetbook.UseCase(
  name: 'List — grouped',
  type: MatomeListView,
  path: '[Proposals]/Matome list',
)
Widget matomeListUseCase(BuildContext context) {
  return _Surface(width: 480, child: MatomeListView(sections: _sampleSections(context)));
}

@widgetbook.UseCase(
  name: 'Row — states',
  type: MatomeListRow,
  path: '[Proposals]/Matome list',
)
Widget matomeRowStatesUseCase(BuildContext context) {
  final rows = _sampleSections(context).expand((s) => s.rows).toList();
  return _Surface(
    width: 480,
    child: Column(
      children: [
        for (final row in rows) ...[
          MatomeListRow(row: row),
          SizedBox(height: context.spacing.sm),
        ],
      ],
    ),
  );
}

class MatomeListView extends StatelessWidget {
  const MatomeListView({super.key, required this.sections});

  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final section in sections) ...[
          _SectionHeader(label: section.label, count: section.rows.length),
          SizedBox(height: spacing.sm),
          for (final row in section.rows) ...[
            MatomeListRow(row: row),
            SizedBox(height: spacing.sm),
          ],
          SizedBox(height: spacing.md),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      children: [
        Text(
          label,
          style: typography.label.copyWith(
            color: colors.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(width: context.spacing.xs),
        Text(
          '$count',
          style: typography.label.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class MatomeListRow extends StatelessWidget {
  const MatomeListRow({super.key, required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final c = _copyOf(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius.md),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(radius.md),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title (full width — time moved into the meta strip).
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    SizedBox(height: spacing.xxs),
                    // Summary preview (the "letter" content peek).
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
                    // Dense meta strip.
                    Wrap(
                      spacing: spacing.sm,
                      runSpacing: spacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaToken(
                          icon: Icons.schedule,
                          text: row.time,
                        ),
                        if (row.audio > 0)
                          _MetaToken(
                            icon: Icons.mic_none_rounded,
                            text: '${row.audio}',
                          ),
                        if (row.image > 0)
                          _MetaToken(
                            icon: Icons.image_outlined,
                            text: '${row.image}',
                          ),
                        if (row.people > 0)
                          _MetaToken(
                            icon: Icons.people_outline,
                            text: '${row.people}',
                          ),
                        _PlaceChip(space: row.space),
                        _SyncChip(rollup: row.rollup),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.xs),
              // Actions live at the right edge, centered to the whole row —
              // clear of the timestamp, reachable one-handed on mobile.
              MatomeActionsMenu(dense: true, onAction: (_) {}),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaToken extends StatelessWidget {
  const _MetaToken({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.textMuted),
        SizedBox(width: context.spacing.xxs),
        Text(
          text,
          style: typography.label.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}

/// Filing chip: a folder pill for a filed space, or a neutral "Inbox" pill.
class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.space});

  final String? space;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final c = _copyOf(context);

    final filed = space != null;
    final icon = filed ? Icons.folder_outlined : Icons.inbox_outlined;
    final label = filed ? space! : c.inboxLabel;
    final color = filed ? colors.textSecondary : colors.textMuted;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.xs,
        vertical: spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: spacing.xxs),
          Text(label, style: typography.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ─── Surface wrapper ─────────────────────────────────────────────────────────

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.width = 460});

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
