import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/observability/app_log.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/contacts_dao.dart' show MatomeContactEntry;
import '../../core/db/daos/spaces_dao.dart';
import '../../core/db/matome_card.dart';
import '../../core/db/recording_card.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_card.dart';
import '../../ui/app_text_field.dart';
import '../../ui/loading_indicator.dart';
import '../home/home_filters.dart' show formatTimestamp;
import 'matome_actions_menu.dart';
import 'matome_detail_controller.dart';

/// Matome detail hub (S?, #1371) + triage actions (#1372): the "page" for a
/// Matome — the aggregate that gathers Items (recordings). Header (title, when,
/// sync hint, a contacts slot reserved for W3), the file-into-a-space CTA, the
/// child-Item list (with an add-photo action), the aggregated summary, and
/// editable notes.
///
/// Triage (ADR-0004) = enrich + FILE INTO A SPACE (default = personal). An Inbox
/// Matome surfaces a "File into a space" CTA; once filed it shows its Space and
/// allows re-filing. Tag-contacts / Share are DEFERRED to W3 — surfaced as a
/// disabled "coming soon" row, no model invented here.
///
/// Mirrors [DetailsScreen]: an `embedded` flag drops the Scaffold/AppBar so the
/// screen can later drop into the desktop two-pane (#1378).
///
/// Reachable as `/matome/:id`.
class MatomeDetailScreen extends ConsumerWidget {
  const MatomeDetailScreen({super.key, required this.id, this.embedded = false});

  final String id;

  /// When true the screen is rendered inside a desktop two-pane layout: the
  /// Scaffold/AppBar (and its back affordance) are dropped — there is no route
  /// to pop — and the body keeps its reading-width clamp.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matomeDetailControllerProvider(id));
    final colors = context.colors;

    final title = state.matome?.title ?? '';
    final body = _MatomeDetailBody(id: id);

    if (embedded) {
      return Material(color: colors.background, child: body);
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        title: Text(
          title.isEmpty ? t.matome.title : title,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: body,
    );
  }
}

/// Reading-width clamp for long-form detail content on wide panes (mirrors the
/// Details screen).
const double _matomeReadingMaxWidth = 720;

/// W8 (#1414 / ADR-0005) responsive breakpoint. At or above this available
/// width the management surface is presented as a PERSISTENT side panel beside
/// the letter (the "drawer"); below it the letter keeps its mobile "Show more"
/// reveal (the "sheet"). This is a layout swap on the SAME `/matome/:id` route
/// — no nested navigator, no deep-link change — per ADR-0005's fixed nav model.
///
/// 900 is chosen as a desktop/large-tablet-landscape threshold: above it there
/// is room for a ~720px reading letter AND a ~360px panel side by side; below
/// it (phones, tablet portrait) the proven single-column sheet stays. It sits
/// safely above the 800px default widget-test viewport, so the existing detail
/// suites keep exercising the sheet presentation unchanged.
const double _matomeWidePanelBreakpoint = 900;

/// Fixed width of the persistent side panel on wide layouts.
const double _matomePanelWidth = 360;

/// The matome detail body, reshaped into the approved LETTER format (W7, #1413 /
/// Widgetbook `MatomeLetterCard`). The card reads top-to-bottom like a letter:
///
///   title · date · the aggregated SUMMARY as the read-first hero · a divider ·
///   summarized one-line lists (files count+preview, people count+preview,
///   filing space-or-CTA, the always-visible sync chip) · a "Show more"
///   affordance.
///
/// "Show more" reveals the detailed management sections (child Items, contacts,
/// notes, deferred Share) INLINE, expanded in place — the narrow/sheet
/// presentation. On a wide viewport (>= [_matomeWidePanelBreakpoint], W8 /
/// #1414) this body instead splits into the letter + a persistent side panel
/// via [_WideDetailLayout]; the same `/matome/:id` route, a breakpoint-driven
/// layout swap (ADR-0005), no nested navigator.
class _MatomeDetailBody extends ConsumerWidget {
  const _MatomeDetailBody({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(matomeDetailControllerProvider(id));
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    if (state.isLoading) {
      return Center(child: LoadingIndicator(color: colors.accent));
    }
    if (state.notFound || state.matome == null) {
      return Center(
        child: Text(
          t.matome.notFound,
          style: typography.bodySmall.copyWith(color: colors.textSecondary),
        ),
      );
    }

    final matome = state.matome!;

    // W8 SEAM resolved (ADR-0005): a breakpoint-driven layout swap on the same
    // route. Wide → the letter narrows and the management surface sits in a
    // persistent panel beside it; narrow → the letter keeps its "Show more"
    // sheet reveal.
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _matomeWidePanelBreakpoint;
        if (isWide) {
          return _WideDetailLayout(
            id: id,
            matome: matome,
            spaces: state.spaces,
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _matomeReadingMaxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                spacing.md,
                spacing.md,
                spacing.md,
                spacing.xxl + spacing.xxl,
              ),
              children: [
                _MatomeLetterCard(id: id, matome: matome, spaces: state.spaces),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The wide (>= [_matomeWidePanelBreakpoint]) presentation: the letter on the
/// left as the reading column (no "Show more"), and the same [_MatomeDetails]
/// composition the sheet reveals, hosted in a PERSISTENT side panel on the
/// right. Both columns scroll independently. This is the W8 "drawer" — the
/// management surface is always visible beside the letter, never behind a tap.
class _WideDetailLayout extends ConsumerWidget {
  const _WideDetailLayout({
    required this.id,
    required this.matome,
    required this.spaces,
  });

  final String id;
  final MatomeItem matome;
  final List<WorkspaceRow> spaces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final controller =
        ref.read(matomeDetailControllerProvider(id).notifier);
    final pad = EdgeInsets.fromLTRB(
      spacing.md,
      spacing.md,
      spacing.md,
      spacing.xxl + spacing.xxl,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The letter, clamped to its reading width and centred in the left pane.
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: _matomeReadingMaxWidth),
              child: ListView(
                padding: pad,
                children: [
                  _MatomeLetterCard(
                    id: id,
                    matome: matome,
                    spaces: spaces,
                    // No "Show more" on wide: the detail lives in the panel.
                    showDetailToggle: false,
                  ),
                ],
              ),
            ),
          ),
        ),
        // The persistent side panel.
        SizedBox(
          width: _matomePanelWidth,
          child: _DetailSidePanel(id: id, matome: matome, controller: controller),
        ),
      ],
    );
  }
}

/// The persistent side panel host (wide layout): a bordered surface column that
/// scrolls the shared [_MatomeDetails] management surface. Mirrors the approved
/// Widgetbook `MatomeDetailPanel` framing — a titled, bordered panel beside the
/// letter — while reusing the live detail sections so per-item sync/actions,
/// contacts, filing, notes and Share all keep working unchanged.
class _DetailSidePanel extends StatelessWidget {
  const _DetailSidePanel({
    required this.id,
    required this.matome,
    required this.controller,
  });

  final String id;
  final MatomeItem matome;
  final MatomeDetailController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: const ValueKey('matome-detail-panel'),
      margin: EdgeInsets.only(
        top: spacing.md,
        right: spacing.md,
        bottom: spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          spacing.lg,
          spacing.lg,
          spacing.lg,
          spacing.xxl,
        ),
        children: [
          Text(
            t.matome.detailPanelTitle,
            style: typography.title.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.md),
          _MatomeDetails(id: id, matome: matome, controller: controller),
        ],
      ),
    );
  }
}

/// The letter card itself: the hero summary plus the summarized meta strip, with
/// a "Show more" toggle that expands the detailed sections in place.
class _MatomeLetterCard extends ConsumerStatefulWidget {
  const _MatomeLetterCard({
    required this.id,
    required this.matome,
    required this.spaces,
    this.showDetailToggle = true,
  });

  final String id;
  final MatomeItem matome;
  final List<WorkspaceRow> spaces;

  /// Whether the letter hosts its own "Show more" reveal of [_MatomeDetails].
  /// True on narrow (the sheet presentation); false on wide, where the detail
  /// lives in the persistent side panel instead (W8 / ADR-0005).
  final bool showDetailToggle;

  @override
  ConsumerState<_MatomeLetterCard> createState() => _MatomeLetterCardState();
}

class _MatomeLetterCardState extends ConsumerState<_MatomeLetterCard> {
  /// Whether the detailed management sections are revealed. Mobile-first: closed
  /// by default so the card reads as a calm letter; "Show more" expands the
  /// detail in place. Only consulted in the narrow/sheet presentation — on wide
  /// (`showDetailToggle == false`) the toggle is not built and the detail lives
  /// in the persistent side panel instead (W8 / #1414, ADR-0005).
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final matome = widget.matome;
    final controller =
        ref.read(matomeDetailControllerProvider(widget.id).notifier);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MatomeHeader(matome: matome, spaces: widget.spaces),
          SizedBox(height: spacing.lg),
          // Hero: the aggregated summary, read first.
          _AggregatedSummary(matome: matome, controller: controller),
          SizedBox(height: spacing.lg),
          Divider(height: 1, color: colors.border),
          SizedBox(height: spacing.md),
          // Summarized one-line lists (always visible).
          _FilesMetaRow(recordings: matome.recordings),
          SizedBox(height: spacing.sm),
          _PeopleMetaRow(matomeId: widget.id),
          SizedBox(height: spacing.sm),
          _FilingSection(matome: matome, spaces: widget.spaces),
          SizedBox(height: spacing.sm),
          _StatusMetaRow(rollup: matome.syncRollup),
          // "Show more" affordance — the narrow/sheet presentation. On wide
          // (W8 / ADR-0005) the detail lives in the persistent side panel
          // instead, so the toggle and its inline reveal are suppressed.
          if (widget.showDetailToggle) ...[
            SizedBox(height: spacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: AppTextButton.icon(
                key: const ValueKey('matome-show-more'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.chevron_right,
                  size: spacing.md,
                ),
                label: Text(_expanded ? t.matome.showLess : t.matome.showMore),
              ),
            ),
            // Detailed management sections, revealed inline.
            if (_expanded) ...[
              SizedBox(height: spacing.sm),
              _MatomeDetails(
                id: widget.id,
                matome: matome,
                controller: controller,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The detailed management sections gathered behind "Show more": the child
/// Items list, the contacts slot, editable notes, and the deferred Share row.
/// Extracted so the W8 side panel can reuse the same composition (its
/// `MatomeDetailPanel` mirrors this section order).
class _MatomeDetails extends StatelessWidget {
  const _MatomeDetails({
    required this.id,
    required this.matome,
    required this.controller,
  });

  final String id;
  final MatomeItem matome;
  final MatomeDetailController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Column(
      key: const ValueKey('matome-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RecordingsSection(recordings: matome.recordings, matomeId: id),
        SizedBox(height: spacing.lg),
        _ContactChipsSlot(matomeId: id),
        SizedBox(height: spacing.lg),
        _NotesSection(
          description: matome.description,
          controller: controller,
        ),
        SizedBox(height: spacing.lg),
        const _DeferredActions(),
      ],
    );
  }
}

/// 📎 Files — one-line summarized list: icon · "Files · N" · a short preview of
/// the item titles. Always visible in the letter; the full list lives behind
/// "Show more".
class _FilesMetaRow extends StatelessWidget {
  const _FilesMetaRow({required this.recordings});

  final List<RecordingItem> recordings;

  @override
  Widget build(BuildContext context) {
    final count = recordings.length;
    final preview = count == 0
        ? t.matome.noFiles
        : recordings.take(2).map((r) => r.title).join(' · ') +
            (count > 2 ? ' · ${t.matome.filesPreviewMore(n: count - 2)}' : '');
    return _MetaRow(
      key: const ValueKey('matome-meta-files'),
      icon: Icons.attach_file,
      label: '${t.matome.filesLabel} · $count',
      preview: preview,
    );
  }
}

/// 👤 People — one-line summarized list: icon · "People · N" · a preview of the
/// attached contact names. Reads the live contacts off the controller so the
/// count stays in step with attach/detach.
class _PeopleMetaRow extends ConsumerWidget {
  const _PeopleMetaRow({required this.matomeId});

  final String matomeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts =
        ref.watch(matomeDetailControllerProvider(matomeId)).contacts;
    final count = contacts.length;
    final preview = count == 0
        ? t.matome.noPeople
        : contacts.take(3).map((e) => e.contact.displayName).join(' · ');
    return _MetaRow(
      key: const ValueKey('matome-meta-people'),
      icon: Icons.people_outline,
      label: '${t.matome.peopleLabel} · $count',
      preview: preview,
    );
  }
}

/// 📌 Status — one-line row pairing the "Status" label with the always-visible
/// [MatomeSyncChip]. The chip keeps the `matome-on-device` key (its W1 meaning:
/// rollup-driven, shown for filed AND inbox matomes).
class _StatusMetaRow extends StatelessWidget {
  const _StatusMetaRow({required this.rollup});

  final MatomeSyncRollup rollup;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Row(
      children: [
        SizedBox(
          width: _kMetaLabelWidth,
          child: Text(
            t.matome.statusLabel,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
        ),
        MatomeSyncChip(
          key: const ValueKey('matome-on-device'),
          rollup: rollup,
        ),
      ],
    );
  }
}

/// Fixed width of the leading label column in the letter's meta rows, so the
/// previews line up like a letterhead (mirrors the Widgetbook proposal).
const double _kMetaLabelWidth = 96;

/// One summarized meta row: a fixed-width leading label (icon · label) and a
/// single-line preview that ellipsizes.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    super.key,
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
          width: _kMetaLabelWidth,
          child: Row(
            children: [
              Icon(icon, size: spacing.md, color: colors.textMuted),
              SizedBox(width: spacing.xs),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: typography.label
                      .copyWith(color: colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.bodySmall.copyWith(color: colors.textPrimary),
          ),
        ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _MatomeHeader extends ConsumerWidget {
  const _MatomeHeader({required this.matome, required this.spaces});

  final MatomeItem matome;
  final List<WorkspaceRow> spaces;

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    MatomeAction action,
  ) async {
    switch (action) {
      case MatomeAction.rename:
        await _rename(context, ref);
      case MatomeAction.editDateTime:
        await _editDateTime(context, ref);
      case MatomeAction.share:
        // Share is deferred (disabled in the menu). No-op hook so the menu is
        // complete now.
        break;
      case MatomeAction.regenerateSummary:
        await ref
            .read(matomeDetailControllerProvider(matome.id).notifier)
            .regenerateSummary();
      case MatomeAction.moveToSpace:
        await _openFilingSheet(context, ref);
      case MatomeAction.copySummary:
        await _copySummary(context);
      case MatomeAction.archive:
        await _archive(context, ref);
    }
  }

  Future<void> _openFilingSheet(BuildContext context, WidgetRef ref) async {
    final target = await showAppBottomSheet<WorkspaceRow>(
      context: context,
      builder: (_) => _FileIntoSpaceSheet(spaces: spaces),
    );
    if (target == null) return;
    // Read the controller AFTER the sheet (it can be autoDisposed while the
    // sheet is open) so filing persists and the hub refreshes.
    await ref
        .read(matomeDetailControllerProvider(matome.id).notifier)
        .fileIntoSpace(target.id);
  }

  Future<void> _copySummary(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary = matome.aggregatedSummary?.trim();
    if (summary == null || summary.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(t.matome.actions.noSummaryToCopy)),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: summary));
    messenger.showSnackBar(
      SnackBar(content: Text(t.matome.actions.summaryCopied)),
    );
  }

  /// Rename flow (#1411 / W5): open a pre-filled text dialog (trim + non-empty
  /// guard MIRRORING the server changeset), then persist via the local-first
  /// `rename()`. The root container + messenger are captured BEFORE the dialog:
  /// this header (and its `ref`) can be autoDisposed while the dialog is open,
  /// and we still need to drive the controller / show the result afterwards.
  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final controller =
        container.read(matomeDetailControllerProvider(matome.id).notifier);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: matome.title),
    );
    if (newTitle == null) return; // cancelled or empty (guarded in the dialog)

    try {
      await controller.rename(newTitle);
    } catch (e, st) {
      AppLog.error(LogCat.action, 'rename failed ${matome.id}', e, st);
      messenger.showSnackBar(
        SnackBar(content: Text(t.matome.actions.editFailed)),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(t.matome.actions.renamed)),
    );
  }

  /// Edit date & time flow (#1411 / W5): a date picker then a time picker
  /// (pre-filled with the current `happened_at`), then persist via the
  /// local-first `editDateTime()`. The container + messenger are captured BEFORE
  /// the pickers (autoDispose can fire while a picker is open).
  Future<void> _editDateTime(BuildContext context, WidgetRef ref) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final controller =
        container.read(matomeDetailControllerProvider(matome.id).notifier);

    final current = DateTime.fromMillisecondsSinceEpoch(matome.happenedAt);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      // Mirror the server changeset window: [2000-01-01 .. now + 366d].
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null) return;

    final happenedAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    try {
      await controller.editDateTime(happenedAt);
    } catch (e, st) {
      AppLog.error(LogCat.action, 'editDateTime failed ${matome.id}', e, st);
      messenger.showSnackBar(
        SnackBar(content: Text(t.matome.actions.editFailed)),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(t.matome.actions.editDateTimeUpdated)),
    );
  }

  /// Archive flow (#1410): confirm → OPTIMISTIC removal (the local-first
  /// `archive()` write drops it from every list immediately) → Undo SnackBar
  /// that calls `restore()`. If the archive sync FAILS, roll the optimistic
  /// removal back by restoring the row and surface the error.
  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    // Capture the root container + messenger BEFORE any await: this header (and
    // its `ref`) can be autoDisposed once the matome leaves the lists, and we
    // still need to drive restore / show the Undo SnackBar afterwards.
    final container = ProviderScope.containerOf(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final controller =
        container.read(matomeDetailControllerProvider(matome.id).notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: Text(t.matome.actions.archiveTitle),
        content: Text(t.matome.actions.archiveBody),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.matome.cancel),
          ),
          AppTextButton(
            key: const ValueKey('matome-archive-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.matome.actions.archiveConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await controller.archive();
    } catch (e, st) {
      AppLog.error(LogCat.action, 'archive failed ${matome.id}', e, st);
      // Roll the optimistic removal back: the local-first write already stamped
      // archived_at before the sync threw, so restore the row.
      try {
        await controller.restore();
      } catch (_) {
        // Best-effort rollback; the error SnackBar still surfaces.
      }
      messenger.showSnackBar(
        SnackBar(content: Text(t.matome.actions.archiveFailed)),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(t.matome.actions.archived),
        action: SnackBarAction(
          label: t.matome.actions.undo,
          onPressed: () => controller.restore(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final when = formatTimestamp(
      DateTime.fromMillisecondsSinceEpoch(matome.happenedAt),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                matome.title,
                style: typography.title.copyWith(color: colors.textPrimary),
              ),
            ),
            MatomeActionsMenu(
              onAction: (action) => _onAction(context, ref, action),
            ),
          ],
        ),
        SizedBox(height: spacing.xs),
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: spacing.md,
              color: colors.textMuted,
            ),
            SizedBox(width: spacing.xs),
            Text(
              when,
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        // The contact-chips slot (#1375) and the always-visible sync chip
        // (#1407) moved OUT of the header in the letter format (W7): contacts
        // live in the summarized "People" meta row + the "Show more" detail; the
        // sync chip lives in the "Status" meta row (still `matome-on-device`).
      ],
    );
  }
}

/// The rename dialog (#1411 / W5): a pre-filled text field with a non-empty
/// guard MIRRORING the server changeset (title trimmed, non-empty, ≤255). Save
/// is disabled while the trimmed input is empty; it pops the trimmed title.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  /// Mirrors the server changeset's `validate_length(:title, max: 255)`.
  static const int _maxTitleLength = 255;

  late final TextEditingController _field =
      TextEditingController(text: widget.initial);

  bool get _isValid => _field.text.trim().isNotEmpty;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _field.text.trim();
    if (trimmed.isEmpty) return; // non-empty guard (mirrors the changeset)
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(t.matome.actions.renameTitle),
      content: AppTextField(
        key: const ValueKey('matome-rename-field'),
        controller: _field,
        autofocus: true,
        label: t.matome.actions.renameLabel,
        hint: t.matome.actions.renameHint,
        // Mirror the server changeset's max length so the input can never
        // exceed it (the trim + non-empty guard is enforced on submit).
        maxLength: _maxTitleLength,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.matome.cancel),
        ),
        AppTextButton(
          key: const ValueKey('matome-rename-save'),
          onPressed: _isValid ? _submit : null,
          child: Text(t.matome.actions.renameSave),
        ),
      ],
    );
  }
}

/// The contact-chips header slot (#1375): renders the Matome's attached
/// contacts as role-bearing chips (each with a detach affordance) and an
/// "Add contact" action that opens a directory picker. Only the local
/// `matome_contacts` edge is touched here — viewing the linked-user PROFILE and
/// SHARING the Matome stay deferred (ADR-0004 / matome-collaboration).
class _ContactChipsSlot extends ConsumerWidget {
  const _ContactChipsSlot({required this.matomeId});

  final String matomeId;

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final controller =
        ref.read(matomeDetailControllerProvider(matomeId).notifier);
    final directory = await controller.directoryContacts();
    if (!context.mounted) return;
    final attachedIds = ref
        .read(matomeDetailControllerProvider(matomeId))
        .contacts
        .map((e) => e.contact.id)
        .toSet();
    final picked = await showAppBottomSheet<ContactRow>(
      context: context,
      builder: (_) => _AddContactSheet(
        contacts: directory,
        attachedIds: attachedIds,
      ),
    );
    if (picked == null) return;
    await controller.attachContact(picked.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final contacts =
        ref.watch(matomeDetailControllerProvider(matomeId)).contacts;
    final controller =
        ref.read(matomeDetailControllerProvider(matomeId).notifier);

    return Column(
      key: const ValueKey('matome-contacts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final entry in contacts)
              _ContactChip(
                entry: entry,
                onDelete: () => controller.detachContact(entry.contact.id),
              ),
            _AddContactButton(onPressed: () => _openPicker(context, ref)),
          ],
        ),
      ],
    );
  }
}

/// One attached contact rendered as a role-bearing chip with a detach
/// affordance.
class _ContactChip extends StatelessWidget {
  const _ContactChip({required this.entry, required this.onDelete});

  final MatomeContactEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      key: ValueKey('matome-contact-${entry.contact.id}'),
      padding: EdgeInsets.fromLTRB(
        spacing.sm,
        spacing.xxs,
        spacing.xs,
        spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: spacing.md,
            color: colors.textSecondary,
          ),
          SizedBox(width: spacing.xs),
          Text(
            entry.contact.displayName,
            style: typography.label.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(width: spacing.xs),
          Text(
            _roleLabel(entry.role),
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          SizedBox(width: spacing.xxs),
          InkWell(
            key: ValueKey('matome-contact-remove-${entry.contact.id}'),
            onTap: onDelete,
            borderRadius: BorderRadius.circular(radius.pill),
            child: Semantics(
              button: true,
              label: t.matome.removeContact,
              child: Icon(
                Icons.close,
                size: spacing.md,
                color: colors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill that opens the directory picker.
class _AddContactButton extends StatelessWidget {
  const _AddContactButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius.pill),
      child: InkWell(
        key: const ValueKey('matome-add-contact'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius.pill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius.pill),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_alt_outlined,
                size: spacing.md,
                color: colors.accent,
              ),
              SizedBox(width: spacing.xs),
              Text(
                t.matome.addContact,
                style: typography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The directory picker sheet: the owner's contacts; already-attached contacts
/// are flagged (re-tap is a harmless idempotent no-op). Selecting one pops it
/// back to attach with the default 'attendee' role.
class _AddContactSheet extends StatelessWidget {
  const _AddContactSheet({required this.contacts, required this.attachedIds});

  final List<ContactRow> contacts;
  final Set<String> attachedIds;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return AppBottomSheet(
      title: Text(
        t.matome.addContactSheetTitle,
        style: typography.body.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      children: [
        if (contacts.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            child: Text(
              t.matome.noDirectoryContacts,
              style: typography.bodySmall.copyWith(color: colors.textMuted),
            ),
          )
        else
          for (final contact in contacts)
            ListTile(
              key: ValueKey('matome-pick-contact-${contact.id}'),
              leading: Icon(Icons.person_outline, color: colors.textSecondary),
              title: Text(contact.displayName),
              trailing: attachedIds.contains(contact.id)
                  ? Icon(Icons.check, color: colors.accent)
                  : null,
              onTap: () => Navigator.of(context).pop(contact),
            ),
      ],
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'organizer':
      return t.matome.roleOrganizer;
    case 'speaker':
      return t.matome.roleSpeaker;
    case 'attendee':
    default:
      return t.matome.roleAttendee;
  }
}

// ─── Filing (the core triage action) ─────────────────────────────────────────

/// 📁 Filing — the triage state as a one-line letter row (W7): a fixed-width
/// "Space" label, then either the filed Space name + a "Refile" action, or — for
/// an Inbox Matome — a "File into a space" CTA pill in place of the value. Both
/// open the [_FileIntoSpaceSheet]; selecting a Space calls
/// [MatomeDetailController.fileIntoSpace], which sets `matome.spaceId`. Keys
/// preserved: `matome-file-cta` / `matome-filed` / `matome-refile`.
class _FilingSection extends ConsumerWidget {
  const _FilingSection({
    required this.matome,
    required this.spaces,
  });

  final MatomeItem matome;
  final List<WorkspaceRow> spaces;

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final target = await showAppBottomSheet<WorkspaceRow>(
      context: context,
      builder: (_) => _FileIntoSpaceSheet(spaces: spaces),
    );
    if (target == null) return;
    // Read the controller AFTER the sheet (it can be autoDisposed while the
    // sheet is open) so filing persists and the hub refreshes.
    await ref
        .read(matomeDetailControllerProvider(matome.id).notifier)
        .fileIntoSpace(target.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final label = SizedBox(
      width: _kMetaLabelWidth,
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: spacing.md, color: colors.textMuted),
          SizedBox(width: spacing.xs),
          Flexible(
            child: Text(
              t.matome.spaceLabel,
              overflow: TextOverflow.ellipsis,
              style: typography.label.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );

    if (matome.isInbox) {
      return Row(
        children: [
          label,
          Material(
            color: colors.primary,
            borderRadius: BorderRadius.circular(radius.pill),
            child: InkWell(
              key: const ValueKey('matome-file-cta'),
              onTap: () => _openSheet(context, ref),
              borderRadius: BorderRadius.circular(radius.pill),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xxs,
                ),
                child: Text(
                  t.matome.fileIntoSpace,
                  style: typography.label.copyWith(color: colors.onAccent),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final spaceName = spaces
        .where((w) => w.id == matome.spaceId)
        .map((w) => w.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    return Row(
      key: const ValueKey('matome-filed'),
      children: [
        label,
        Expanded(
          child: Text(
            spaceName ?? matome.spaceId ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.bodySmall.copyWith(color: colors.textPrimary),
          ),
        ),
        AppTextButton(
          key: const ValueKey('matome-refile'),
          onPressed: () => _openSheet(context, ref),
          child: Text(t.matome.refile),
        ),
      ],
    );
  }
}

/// The file-into-a-space sheet. The default personal Space (ADR-0004) is the
/// most-prominent option — it is ordered first by the controller and flagged
/// here as the default destination.
class _FileIntoSpaceSheet extends StatelessWidget {
  const _FileIntoSpaceSheet({required this.spaces});

  final List<WorkspaceRow> spaces;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return AppBottomSheet(
      title: Text(
        t.matome.fileIntoSpaceSheetTitle,
        style: typography.body.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      children: [
        for (final ws in spaces)
          ListTile(
            key: ValueKey('matome-space-${ws.id}'),
            leading: Icon(
              ws.id == kDefaultPersonalSpaceId
                  ? Icons.person_outline
                  : Icons.folder_outlined,
              color: colors.textSecondary,
            ),
            title: Text(ws.name),
            trailing: ws.id == kDefaultPersonalSpaceId
                ? Text(
                    t.matome.personalSpaceHint,
                    style: typography.label.copyWith(color: colors.textMuted),
                  )
                : null,
            onTap: () => Navigator.of(context).pop(ws),
          ),
      ],
    );
  }
}

// ─── Recordings (child Items) + add photo ────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      text,
      style: typography.label.copyWith(
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }
}

class _RecordingsSection extends ConsumerWidget {
  const _RecordingsSection({
    required this.recordings,
    required this.matomeId,
  });

  final List<RecordingItem> recordings;
  final String matomeId;

  Future<void> _addPhoto(BuildContext context) async {
    // Capture the app-lifetime container BEFORE opening the picker. This
    // widget's element (and the `ref` bound to it) can be disposed while the
    // native dialog is open — `ref.read` then throws "Cannot use ref after the
    // widget was disposed" and the photo is silently lost. The root container
    // outlives the widget; the autoDispose provider is revived on read and
    // `addPhoto` persists to Drift regardless, so the live screen (watching the
    // same family key) refreshes even across a mid-picker dispose.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      AppLog.event(LogCat.action, 'addPhoto: picker opening');
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path == null) {
        AppLog.event(LogCat.action, 'addPhoto: cancelled (no path)');
        return; // user cancelled the picker
      }
      await container
          .read(matomeDetailControllerProvider(matomeId).notifier)
          .addPhoto(file: File(path), name: result!.files.single.name);
      AppLog.event(LogCat.action, 'addPhoto: imported ${path.split('/').last}');
    } catch (e, st) {
      AppLog.error(LogCat.action, 'addPhoto failed', e, st);
      // Surface the failure instead of swallowing it in an onPressed callback —
      // the picker/durable-copy/insert can throw on desktop and a silent no-op
      // is indistinguishable from "nothing happened".
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add photo failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionLabel(text: t.matome.recordings)),
            AppTextButton.icon(
              key: const ValueKey('matome-add-photo'),
              onPressed: () => _addPhoto(context),
              icon: Icon(Icons.add_photo_alternate_outlined, size: spacing.md),
              label: Text(t.matome.addPhoto),
            ),
          ],
        ),
        SizedBox(height: spacing.xs),
        if (recordings.isEmpty)
          _EmptyHint(text: t.matome.noRecordings)
        else
          ...recordings.map(
            (item) => Padding(
              key: ValueKey('matome-item-${item.id}'),
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: _RecordingTile(item: item, matomeId: matomeId),
            ),
          ),
      ],
    );
  }
}

/// One child Item. Image Items get a media-forward tile; everything else (audio,
/// documents) reuses the shared [AppCard.recording]. Tapping opens the existing
/// recording Details route (reused, scope-tight).
class _RecordingTile extends ConsumerWidget {
  const _RecordingTile({required this.item, required this.matomeId});

  final RecordingItem item;
  final String matomeId;

  bool get _isImage => item.mediaType.startsWith('image');

  void _openRecording(BuildContext context) {
    // The single-recording DetailsScreen, reached from INSIDE the matome hub for
    // one Item (#1378). This is its own non-redirecting route — the old
    // recording-centric deep-links (`/inbox/:id`, `/calendar/:id`,
    // `/spaces/recording/:id`) now redirect back UP to the parent matome, so the
    // hub must use the dedicated `/recording/detail/:id` route to drill DOWN.
    context.push('/recording/detail/${item.id}');
  }

  void _previewImage(BuildContext context) {
    final path = item.filePath;
    if (path == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => _ImagePreviewDialog(path: path, title: item.title),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    // Capture the app-lifetime container BEFORE the dialog: this tile's element
    // (and its `ref`) can be disposed while the confirm dialog is open — reading
    // `ref` afterwards throws "Cannot use ref after the widget was disposed" and
    // the removal silently dies (the exact addPhoto failure, one layer over).
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      // Pop via the dialog's OWN context, not the captured tile context: a
      // background rebuild (e.g. the upload waiter publishing a status while the
      // dialog is open) can deactivate the tile element, and `Navigator.of` on a
      // defunct context throws inside the button callback — the pop never runs,
      // the dialog is stuck open, and the app looks frozen.
      builder: (dialogContext) => AppDialog(
        title: Text(t.matome.removeItemTitle),
        content: Text(t.matome.removeItemBody(title: item.title)),
        actions: [
          AppTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.matome.cancel),
          ),
          AppTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.matome.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      AppLog.event(LogCat.action, 'removeItem: cancelled ${item.id}');
      return;
    }
    try {
      AppLog.event(LogCat.action, 'removeItem: confirmed ${item.id}');
      await container
          .read(matomeDetailControllerProvider(matomeId).notifier)
          .removeItem(item.id, filePath: item.filePath);
      AppLog.event(LogCat.action, 'removeItem: done ${item.id}');
    } catch (e, st) {
      AppLog.error(LogCat.action, 'removeItem failed ${item.id}', e, st);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isImage) {
      return _ImageItemTile(
        item: item,
        onTap: () => _previewImage(context),
        onRemove: () => _confirmRemove(context),
      );
    }
    return AppCard.recording(
      card: item,
      relativeTime: formatTimestamp(
        DateTime.tryParse(item.timestamp),
      ),
      onTap: () => _openRecording(context),
    );
  }
}

/// Full-image lightbox for a photo Item.
class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.path, required this.title});

  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: EdgeInsets.all(context.spacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.lg),
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Padding(
              padding: EdgeInsets.all(context.spacing.xl),
              child: Text(
                t.matome.imageUnavailable,
                style: context.typography.bodySmall
                    .copyWith(color: colors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageItemTile extends StatelessWidget {
  const _ImageItemTile({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final RecordingItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final accent = colors.badgeColor(item.badge);
    final path = item.filePath;

    final Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(radius.md),
      child: SizedBox(
        width: spacing.xxl,
        height: spacing.xxl,
        child: path == null
            ? ColoredBox(
                color: accent.withValues(alpha: 0.13),
                child: Icon(Icons.image_outlined, color: accent),
              )
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: accent.withValues(alpha: 0.13),
                  child: Icon(Icons.broken_image_outlined, color: accent),
                ),
              ),
      ),
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(radius.lg),
      child: InkWell(
        key: ValueKey('matome-image-${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.lg),
        child: Container(
          padding: EdgeInsets.all(spacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              thumb,
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('matome-image-remove-${item.id}'),
                tooltip: t.matome.remove,
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline, color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Aggregated summary ──────────────────────────────────────────────────────

/// The stored aggregated summary (ADR-0003) plus its regenerate affordance. A
/// "Regenerate summary" action surfaces when the summary is flagged stale (the
/// item set / a child summary changed) OR when there is no summary yet but the
/// Matome already has Items to roll up — either way the deterministic local
/// generator can (re)compose it. Tapping calls the controller and the hub
/// reloads with the fresh summary.
class _AggregatedSummary extends StatelessWidget {
  const _AggregatedSummary({required this.matome, required this.controller});

  final MatomeItem matome;
  final MatomeDetailController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final summary = matome.aggregatedSummary;
    final hasSummary = summary != null && summary.trim().isNotEmpty;
    final hasItems = matome.recordings.isNotEmpty;
    // Offer regeneration when explicitly stale, or when nothing is stored yet
    // but there are Items to roll up (the first compose).
    final canRegenerate =
        matome.summaryStale || (!hasSummary && hasItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('matome-summary'),
          width: double.infinity,
          padding: EdgeInsets.all(spacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(color: colors.border),
          ),
          child: hasSummary
              ? MarkdownBody(data: summary)
              : Text(
                  t.matome.noSummary,
                  style:
                      typography.bodySmall.copyWith(color: colors.textMuted),
                ),
        ),
        if (canRegenerate) ...[
          SizedBox(height: spacing.xs),
          Row(
            children: [
              if (matome.summaryStale)
                Expanded(
                  child: Text(
                    t.matome.summaryStale,
                    style: typography.label.copyWith(color: colors.textMuted),
                  ),
                )
              else
                const Spacer(),
              AppTextButton.icon(
                key: const ValueKey('matome-regenerate-summary'),
                onPressed: controller.regenerateSummary,
                icon: Icon(Icons.refresh, size: spacing.md),
                label: Text(t.matome.regenerateSummary),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Notes (editable) ────────────────────────────────────────────────────────

/// Notes block with an edit affordance. Tapping "Edit notes" swaps in an
/// [AppTextField]; "Save" persists via [MatomeDetailController.saveNotes] (which
/// marks the summary stale when the notes actually changed).
class _NotesSection extends StatefulWidget {
  const _NotesSection({required this.description, required this.controller});

  final String? description;
  final MatomeDetailController controller;

  @override
  State<_NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<_NotesSection> {
  bool _editing = false;
  late final TextEditingController _field =
      TextEditingController(text: widget.description ?? '');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _startEdit() {
    _field.text = widget.description ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    await widget.controller.saveNotes(_field.text);
    if (!mounted) return;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final hasNotes =
        widget.description != null && widget.description!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionLabel(text: t.matome.notes)),
            if (!_editing)
              AppTextButton.icon(
                key: const ValueKey('matome-edit-notes'),
                onPressed: _startEdit,
                icon: Icon(Icons.edit_outlined, size: spacing.md),
                label: Text(t.matome.editNotes),
              ),
          ],
        ),
        SizedBox(height: spacing.xs),
        if (_editing) ...[
          AppTextField(
            key: const ValueKey('matome-notes-field'),
            controller: _field,
            hint: t.matome.notesHint,
            maxLines: 5,
            minLines: 3,
            textAlignVertical: TextAlignVertical.top,
          ),
          SizedBox(height: spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppTextButton(
                onPressed: () => setState(() => _editing = false),
                child: Text(t.matome.cancel),
              ),
              SizedBox(width: spacing.xs),
              PrimaryButton(
                key: const ValueKey('matome-notes-save'),
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onAccent,
                ),
                child: Text(t.matome.save),
              ),
            ],
          ),
        ] else
          Container(
            key: const ValueKey('matome-notes'),
            width: double.infinity,
            padding: EdgeInsets.all(spacing.xxs),
            child: hasNotes
                ? MarkdownBody(data: widget.description!)
                : Text(
                    t.matome.noNotes,
                    style:
                        typography.bodySmall.copyWith(color: colors.textMuted),
                  ),
          ),
      ],
    );
  }
}

// ─── Deferred actions (W3) ───────────────────────────────────────────────────

/// Share is the only remaining DEFERRED affordance (ADR-0004 / the
/// matome-collaboration plan): surfaced as a disabled "coming soon" row so it
/// stays discoverable without inventing a sharing model. (Tag-contacts shipped
/// in #1375 — it is now the real header contact slot.)
class _DeferredActions extends StatelessWidget {
  const _DeferredActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeferredActionRow(
          key: const ValueKey('matome-share'),
          icon: Icons.ios_share_outlined,
          label: t.matome.share,
        ),
      ],
    );
  }
}

class _DeferredActionRow extends StatelessWidget {
  const _DeferredActionRow({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Opacity(
      opacity: 0.5,
      child: Row(
        children: [
          Icon(icon, size: spacing.md, color: colors.textMuted),
          SizedBox(width: spacing.xs),
          Text(
            label,
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          SizedBox(width: spacing.xs),
          Text(
            '· ${t.matome.comingSoon}',
            style: typography.label.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Text(
      text,
      style: typography.bodySmall.copyWith(color: colors.textMuted),
    );
  }
}
