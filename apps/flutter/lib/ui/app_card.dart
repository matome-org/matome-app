import 'package:flutter/material.dart';

import '../core/db/matome_card.dart';
import '../core/db/recording_card.dart';
import '../core/theme/app_theme.dart';
import '../features/matome/matome_actions_menu.dart';
import '../features/recordings/recording_ids.dart';
import '../i18n/strings.g.dart';
import 'app_button.dart';
import 'avatar.dart';
import 'loading_indicator.dart';
import 'status_badge.dart';

enum AppCardRecordingState { pendingUpload, processing, done, failed }

enum _AppCardVariant { recording, calendar, matome }

class AppCard extends StatelessWidget {
  const AppCard.recording({
    super.key,
    required this.card,
    required this.relativeTime,
    this.onTap,
    this.onLongPress,
    this.onRetry,
    this.trailing,
  }) : id = null,
       matome = null,
       title = null,
       badge = null,
       statusLabel = null,
       durationLabel = null,
       onAction = null,
       selected = false,
       _variant = _AppCardVariant.recording;

  const AppCard.calendar({
    super.key,
    required this.id,
    required this.title,
    required this.badge,
    required this.statusLabel,
    required this.durationLabel,
    required this.onTap,
  }) : card = null,
       matome = null,
       relativeTime = null,
       onLongPress = null,
       onRetry = null,
       onAction = null,
       trailing = null,
       selected = false,
       _variant = _AppCardVariant.calendar;

  /// A **Matome** row (#1378, reworked #1412): the top-level managed unit. A
  /// compact envelope — title (full width), a one-line summary peek, a dense
  /// meta strip (time · item mix · people · place · sync chip) and a dense
  /// actions menu at the right edge. No left avatar, no right chevron.
  ///
  /// [onAction] wires the row's always-present dense [MatomeActionsMenu]; when
  /// null the menu degrades to a no-op (read-only / mockup hosts).
  const AppCard.matome({
    super.key,
    required this.matome,
    required this.relativeTime,
    this.onTap,
    this.onLongPress,
    this.onAction,
    this.selected = false,
  }) : card = null,
       id = null,
       title = null,
       badge = null,
       statusLabel = null,
       durationLabel = null,
       onRetry = null,
       trailing = null,
       _variant = _AppCardVariant.matome;

  final _AppCardVariant _variant;
  final RecordingItem? card;
  final MatomeItem? matome;
  final String? relativeTime;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// When true, renders the master-detail OPEN state: a slightly darker
  /// background, marking the row currently shown in the reading pane.
  final bool selected;

  final VoidCallback? onRetry;

  /// Optional trailing widget rendered INSIDE the recording card's border,
  /// vertically centered at the right edge (e.g. a '…' overflow menu). Null on
  /// every other usage, so the shared card is unchanged where no action is
  /// passed.
  final Widget? trailing;

  /// Row-level handler for the matome variant's dense actions menu (#1412).
  final ValueChanged<MatomeAction>? onAction;
  final String? id;
  final String? title;
  final String? badge;
  final String? statusLabel;
  final String? durationLabel;

  AppCardRecordingState get recordingState {
    final recording = card;
    if (recording == null) return AppCardRecordingState.done;

    final status = recording.processingStatus;
    if (status == 'failed') return AppCardRecordingState.failed;
    if (isUploadQueuePendingStatus(status)) {
      return AppCardRecordingState.pendingUpload;
    }
    if (status == 'processing' ||
        status == 'pending' ||
        recording.isProcessing) {
      return AppCardRecordingState.processing;
    }
    return AppCardRecordingState.done;
  }

  IconData get _mediaIcon {
    final type = card?.mediaType ?? '';
    if (type.startsWith('image')) return Icons.image_outlined;
    if (type.contains('document') ||
        type.contains('meeting') ||
        type.contains('text')) {
      return Icons.description_outlined;
    }
    return Icons.play_arrow_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_variant) {
      _AppCardVariant.recording => _buildRecording(context),
      _AppCardVariant.calendar => _buildCalendar(context),
      _AppCardVariant.matome => _buildMatome(context),
    };
  }

  Widget _buildMatome(BuildContext context) {
    final m = matome!;
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final summary = m.aggregatedSummary?.trim();
    final hasSummary = summary != null && summary.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Matome: ${m.title}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        child: InkWell(
          key: ValueKey('matome-card-${m.id}'),
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              // OPEN-in-pane indicator: just a slightly different fill.
              color: selected ? colors.subtleFillStrong : null,
              borderRadius: BorderRadius.circular(radius.lg),
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
                        m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: spacing.xxs),
                      // Summary peek (the "letter" content) — or a muted,
                      // italic "No summary yet" fallback when none is stored.
                      Text(
                        hasSummary ? summary : t.matome.noSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: hasSummary
                              ? colors.textSecondary
                              : colors.textMuted,
                          fontStyle: hasSummary
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      // Dense meta strip: time first, then item mix, people,
                      // place chip, and the always-on sync chip.
                      Wrap(
                        spacing: spacing.sm,
                        runSpacing: spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MatomeMetaToken(
                            icon: Icons.schedule,
                            text: relativeTime ?? '',
                          ),
                          if (m.audioCount > 0)
                            _MatomeMetaToken(
                              icon: Icons.mic_none_rounded,
                              text: '${m.audioCount}',
                            ),
                          if (m.imageCount > 0)
                            _MatomeMetaToken(
                              icon: Icons.image_outlined,
                              text: '${m.imageCount}',
                            ),
                          if (m.documentCount > 0)
                            _MatomeMetaToken(
                              icon: Icons.description_outlined,
                              text: '${m.documentCount}',
                            ),
                          if (m.peopleCount > 0)
                            _MatomeMetaToken(
                              icon: Icons.people_outline,
                              text: '${m.peopleCount}',
                            ),
                          _MatomePlaceChip(
                            spaceName: m.isInbox ? null : m.spaceName,
                          ),
                          MatomeSyncChip(
                            key: const ValueKey('matome-card-sync'),
                            rollup: m.syncRollup,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.xs),
                // Actions at the right edge, centered to the whole row so
                // mobile users can act without opening the matome. Always
                // present; a null handler degrades to a no-op (read-only host).
                MatomeActionsMenu(dense: true, onAction: onAction ?? (_) {}),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecording(BuildContext context) {
    final recording = card!;
    final colors = context.colors;
    final color = colors.badgeColor(recording.badge);

    return Semantics(
      button: true,
      label: 'Recording: ${recording.title}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.radius.lg),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(context.radius.lg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.radius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecordingAvatar(
                  color: color,
                  state: recordingState,
                  mediaIcon: _mediaIcon,
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RecordingTitleRow(
                        title: recording.title,
                        timestamp: relativeTime ?? '',
                      ),
                      SizedBox(height: context.spacing.xxs),
                      _RecordingBody(
                        card: recording,
                        color: color,
                        state: recordingState,
                        onRetry: onRetry,
                      ),
                      const SizedBox(height: 6),
                      _RecordingFooter(card: recording, color: color),
                    ],
                  ),
                ),
                // Optional action (e.g. '…' overflow) — INSIDE the border,
                // at the trailing edge, so the card outline never stops short
                // of it (the image tile renders its overflow in-row the same
                // way).
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final colors = context.colors;
    final isWork = badge == 'Work';
    final dotColor = isWork ? colors.accent : colors.textMuted;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(context.radius.md),
      child: InkWell(
        key: ValueKey('calendar-recording-$id'),
        borderRadius: BorderRadius.circular(context.radius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.radius.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: context.spacing.xxs),
                    Row(
                      children: [
                        StatusBadge.label(
                          label: statusLabel ?? '',
                          color: dotColor,
                          showDot: false,
                          backgroundColor: isWork
                              ? colors.accent.withValues(alpha: 0.13)
                              : colors.border,
                          textColor: isWork
                              ? colors.accentDark
                              : colors.textSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          borderRadius: 6,
                        ),
                        SizedBox(width: context.spacing.xs),
                        Text(
                          durationLabel ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingAvatar extends StatelessWidget {
  const _RecordingAvatar({
    required this.color,
    required this.state,
    required this.mediaIcon,
  });

  final Color color;
  final AppCardRecordingState state;
  final IconData mediaIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Color bg;
    final Widget child;
    switch (state) {
      case AppCardRecordingState.processing:
        bg = color.withValues(alpha: 0.13);
        child = LoadingIndicator(size: 14, strokeWidth: 2, color: color);
      case AppCardRecordingState.failed:
        bg = colors.failed.withValues(alpha: 0.13);
        child = Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: colors.failed,
        );
      case AppCardRecordingState.pendingUpload:
        bg = colors.textMuted.withValues(alpha: 0.13);
        child = Icon(
          Icons.cloud_off_outlined,
          size: 16,
          color: colors.textMuted,
        );
      case AppCardRecordingState.done:
        bg = color.withValues(alpha: 0.13);
        child = Icon(mediaIcon, size: 18, color: color);
    }
    return Avatar(backgroundColor: bg, size: 36, child: child);
  }
}

class _RecordingTitleRow extends StatelessWidget {
  const _RecordingTitleRow({required this.title, required this.timestamp});

  final String title;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (timestamp.isNotEmpty) ...[
          SizedBox(width: context.spacing.xs),
          Text(
            timestamp,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _RecordingBody extends StatelessWidget {
  const _RecordingBody({
    required this.card,
    required this.color,
    required this.state,
    this.onRetry,
  });

  final RecordingItem card;
  final Color color;
  final AppCardRecordingState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    switch (state) {
      case AppCardRecordingState.pendingUpload:
        return Row(
          key: const ValueKey('card-pending-upload'),
          children: [
            Icon(Icons.cloud_off_outlined, size: 13, color: colors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                t.cardStatus.pendingUpload,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ),
          ],
        );

      case AppCardRecordingState.processing:
        return Row(
          key: const ValueKey('card-processing'),
          children: [
            LoadingIndicator(size: 12, strokeWidth: 2, color: color),
            const SizedBox(width: 6),
            Text(
              t.cardStatus.processing,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: color,
              ),
            ),
          ],
        );

      case AppCardRecordingState.failed:
        return Row(
          key: const ValueKey('card-failed'),
          children: [
            Icon(Icons.error_outline, size: 13, color: colors.failed),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                card.processingErrorMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.failed),
              ),
            ),
            if (onRetry != null)
              AppTextButton.icon(
                key: const ValueKey('card-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(t.cardStatus.retry),
                style: TextButton.styleFrom(
                  foregroundColor: colors.failed,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );

      case AppCardRecordingState.done:
        final summary = card.summary;
        if (summary == null || summary.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: colors.textSecondary,
          ),
        );
    }
  }
}

/// The single shared sync-status chip (#1407). Driven purely by
/// [MatomeItem.syncRollup] so the matome list row and the detail pill always
/// agree for the same matome (the original /critique P0 where one read
/// "On device" while the other read "Cloud"). It shows pure sync state —
/// Synced / Syncing / On device — with NO triage suffix; filing is a separate
/// section.
///
/// Rollup→label (DECIDED — 3 states, no 4th): a permanently-failed item stays
/// inside [MatomeSyncRollup.partial] and is therefore labelled "Syncing". That
/// is an accepted trade-off: "Syncing" can mean "stuck retrying" for a failed
/// child rather than spawning a separate failure state on the chip.
class MatomeSyncChip extends StatelessWidget {
  const MatomeSyncChip({super.key, required this.rollup});

  final MatomeSyncRollup rollup;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;

    final (IconData icon, String label, Color color) = switch (rollup) {
      MatomeSyncRollup.cloud => (
        Icons.cloud_done_outlined,
        t.cardStatus.cloud,
        colors.badgePersonal,
      ),
      MatomeSyncRollup.partial => (
        Icons.cloud_sync_outlined,
        t.cardStatus.syncing,
        colors.textSecondary,
      ),
      // One on-device glyph app-wide: cloud_off (matches StatusBadge.sync).
      MatomeSyncRollup.onDevice => (
        Icons.cloud_off_outlined,
        t.cardStatus.onDevice,
        colors.textMuted,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.subtleFill,
        borderRadius: BorderRadius.circular(radius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: spacing.md, color: color),
          SizedBox(width: spacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One token in the matome row's dense meta strip (#1412): a small muted icon
/// + a secondary-coloured count/label. Used for time, mic, image and people.
class _MatomeMetaToken extends StatelessWidget {
  const _MatomeMetaToken({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.textMuted),
        SizedBox(width: context.spacing.xxs),
        Text(text, style: TextStyle(fontSize: 11, color: colors.textSecondary)),
      ],
    );
  }
}

/// Filing chip for the matome row (#1412): a folder pill carrying the filed
/// Space name, or a neutral "Inbox" pill when the matome is untriaged.
class _MatomePlaceChip extends StatelessWidget {
  const _MatomePlaceChip({required this.spaceName});

  /// The filed Space name, or null when the matome is in the Inbox.
  final String? spaceName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;

    final filed = spaceName != null;
    final icon = filed ? Icons.folder_outlined : Icons.inbox_outlined;
    final label = filed ? spaceName! : t.matome.placeInbox;
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
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingFooter extends StatelessWidget {
  const _RecordingFooter({required this.card, required this.color});

  final RecordingItem card;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = card.badge.isEmpty ? null : card.badge;

    return Wrap(
      spacing: context.spacing.xs,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label != null) StatusBadge.label(label: label, color: color),
        StatusBadge.sync(
          coreId: card.coreId,
          processingStatus: card.processingStatus,
        ),
        if (card.duration.isNotEmpty)
          Text(
            card.duration,
            style: TextStyle(fontSize: 11, color: context.colors.textMuted),
          ),
      ],
    );
  }
}
