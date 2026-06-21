import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/db/daos/spaces_dao.dart' show kDefaultPersonalSpaceId;
import '../../core/db/matome_card.dart';
import '../../core/observability/app_log.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import 'matome_actions_menu.dart';
import 'matome_detail_controller.dart';

/// Wires the matome list row's dense [MatomeActionsMenu] (#1412) to real flows
/// WITHOUT entering the matome — the mobile-first goal of the rework. Each
/// action drives the same per-matome controller the detail header uses
/// (`matomeDetailControllerProvider(matome.id)`), so list and detail behave
/// identically.
///
/// Reachable straight from the row: Archive (optimistic removal + Undo),
/// Copy summary, Move to space, Regenerate. Rename / Edit date & time route to
/// [onOpen] (open the matome) instead — those W5 flows live behind private
/// detail-screen dialogs and re-plumbing them here would be heavy for little
/// gain; opening the matome lands the user exactly where those edits live.
class MatomeRowActions {
  const MatomeRowActions({
    required this.matome,
    required this.spaces,
    required this.onOpen,
  });

  final MatomeItem matome;

  /// Filing targets for "Move to space" (the caller already loads these for the
  /// list, so no per-row Space query is issued here).
  final List<WorkspaceRow> spaces;

  /// Opens the matome hub — the fallback for Rename / Edit date & time.
  final VoidCallback onOpen;

  Future<void> handle(
    BuildContext context,
    WidgetRef ref,
    MatomeAction action,
  ) async {
    switch (action) {
      case MatomeAction.rename:
      case MatomeAction.editDateTime:
        // Route to the matome hub — the rename / edit-date dialogs (W5) live
        // there; re-plumbing them onto the row is not worth the weight.
        onOpen();
      case MatomeAction.share:
        break; // deferred (disabled in the menu)
      case MatomeAction.regenerateSummary:
        await _controller(ref).regenerateSummary();
      case MatomeAction.moveToSpace:
        await _moveToSpace(context, ref);
      case MatomeAction.copySummary:
        await _copySummary(context);
      case MatomeAction.archive:
        await _archive(context, ref);
    }
  }

  MatomeDetailController _controller(WidgetRef ref) =>
      ref.read(matomeDetailControllerProvider(matome.id).notifier);

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

  Future<void> _moveToSpace(BuildContext context, WidgetRef ref) async {
    // Capture BEFORE the sheet: the row's element / ref can be disposed once the
    // list re-reads, so read the controller off the root container afterwards.
    final container = ProviderScope.containerOf(context, listen: false);
    final target = await showAppBottomSheet<WorkspaceRow>(
      context: context,
      builder: (_) => _MoveToSpaceSheet(spaces: spaces),
    );
    if (target == null) return;
    await container
        .read(matomeDetailControllerProvider(matome.id).notifier)
        .fileIntoSpace(target.id);
  }

  /// Archive (#1410, reused from the detail header): confirm → OPTIMISTIC
  /// removal (the local-first `archive()` drops it from every list) → Undo
  /// SnackBar that `restore()`s. On sync failure, roll the removal back.
  Future<void> _archive(BuildContext context, WidgetRef ref) async {
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
}

/// Filing-target picker for the row's "Move to space" action — mirrors the
/// detail screen's filing sheet (same `matome-space-<id>` keys).
class _MoveToSpaceSheet extends StatelessWidget {
  const _MoveToSpaceSheet({required this.spaces});

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
