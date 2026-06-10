import 'package:flutter/material.dart';

import '../../../core/db/recording_card.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/recordings/recording_ids.dart';
import '../../../i18n/strings.g.dart';
import 'sync_badge.dart';

/// The local-first lifecycle state a card renders (plan #43, W5).
///
/// Derived from the persisted `processingStatus` (+ the legacy `isProcessing`
/// flag). The four states map 1:1 to the row states the queue produces:
///   * [pendingUpload] — saved on device, not yet on Core. SAFE-but-not-uploaded.
///   * [processing]    — reconciled with Core, transcribing.
///   * [done]          — normal terminal state.
///   * [failed]        — a real failure (reason lives in the `notes` column);
///                       offers a manual retry alongside the auto-retry queue.
enum RecordingCardState { pendingUpload, processing, done, failed }

/// A single Inbox row rendered from the Drift [RecordingCard] (S1, #780).
///
/// Ported in spirit from the lab `RecordingCard`, but bound to the persisted
/// card type (string fields) instead of the HTTP [Recording] model: leading
/// status/media avatar, title + duration, a lifecycle line (pending-upload /
/// transcribing / failed) OR the summary, and a footer with the badge.
class InboxRecordingCard extends StatelessWidget {
  const InboxRecordingCard({
    super.key,
    required this.card,
    required this.relativeTime,
    this.onTap,
    this.onLongPress,
    this.onRetry,
  });

  final RecordingCard card;

  /// Pre-formatted relative timestamp shown top-right (e.g. "3h", "2d").
  final String relativeTime;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Invoked from the `failed` card's manual-retry affordance. Re-enqueues the
  /// recording via the upload queue (alongside the auto-retry). Null hides the
  /// button (e.g. in contexts that don't own a retry path).
  final VoidCallback? onRetry;

  /// Resolves the card's local-first lifecycle state from the persisted row.
  ///
  /// `pending_upload` is recognised either by the explicit status string
  /// ([kProcessingStatusPendingUpload]) or — defensively — by a still-local
  /// `rec_local_<uuid>` id that hasn't reconciled a Core id yet, so a row that
  /// is genuinely saved-but-not-uploaded never mis-renders as a generic spinner.
  RecordingCardState get state {
    final status = card.processingStatus;
    if (status == 'failed') return RecordingCardState.failed;
    if (status == kProcessingStatusPendingUpload) {
      return RecordingCardState.pendingUpload;
    }
    if (status == 'processing' || status == 'pending' || card.isProcessing) {
      return RecordingCardState.processing;
    }
    return RecordingCardState.done;
  }

  IconData get _mediaIcon {
    final type = card.mediaType;
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
    final color = badgeColor(card.badge);

    return Semantics(
      button: true,
      label: 'Recording: ${card.title}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                  color: color,
                  state: state,
                  mediaIcon: _mediaIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TitleRow(title: card.title, timestamp: relativeTime),
                      const SizedBox(height: 4),
                      _Body(
                        card: card,
                        color: color,
                        state: state,
                        onRetry: onRetry,
                      ),
                      const SizedBox(height: 6),
                      _Footer(
                        badge: card.badge,
                        color: color,
                        duration: card.duration,
                        coreId: card.coreId,
                        processingStatus: card.processingStatus,
                      ),
                    ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.color,
    required this.state,
    required this.mediaIcon,
  });

  final Color color;
  final RecordingCardState state;
  final IconData mediaIcon;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Widget child;
    switch (state) {
      case RecordingCardState.processing:
        bg = color.withValues(alpha: 0.13);
        child = SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        );
      case RecordingCardState.failed:
        bg = AppColors.failed.withValues(alpha: 0.13);
        child = const Icon(Icons.warning_amber_rounded,
            size: 16, color: AppColors.failed);
      case RecordingCardState.pendingUpload:
        // Safe-but-not-uploaded: a neutral "offline / on device" glyph rather
        // than a spinner (nothing is in flight) or a warning (nothing is wrong).
        bg = AppColors.textMuted.withValues(alpha: 0.13);
        child = const Icon(Icons.cloud_off_outlined,
            size: 16, color: AppColors.textMuted);
      case RecordingCardState.done:
        bg = color.withValues(alpha: 0.13);
        child = Icon(mediaIcon, size: 18, color: color);
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: child,
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title, required this.timestamp});

  final String title;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (timestamp.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            timestamp,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.card,
    required this.color,
    required this.state,
    this.onRetry,
  });

  final RecordingCard card;
  final Color color;
  final RecordingCardState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case RecordingCardState.pendingUpload:
        // SAFE-but-not-uploaded. No spinner — nothing is in flight; this reads
        // as "your recording is on the device, we'll upload it when we can".
        return Row(
          key: const ValueKey('card-pending-upload'),
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 13, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                t.cardStatus.pendingUpload,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        );

      case RecordingCardState.processing:
        return Row(
          key: const ValueKey('card-processing'),
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
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

      case RecordingCardState.failed:
        return Row(
          key: const ValueKey('card-failed'),
          children: [
            const Icon(Icons.error_outline, size: 13, color: AppColors.failed),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t.cardStatus.failed,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.failed),
              ),
            ),
            if (onRetry != null)
              TextButton.icon(
                key: const ValueKey('card-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text(t.cardStatus.retry),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.failed,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );

      case RecordingCardState.done:
        final summary = card.summary;
        if (summary == null || summary.isEmpty) {
          return const SizedBox.shrink();
        }
        return Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AppColors.textSecondary,
          ),
        );
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.badge,
    required this.color,
    required this.duration,
    required this.coreId,
    required this.processingStatus,
  });

  final String badge;
  final Color color;
  final String duration;
  final int? coreId;
  final String processingStatus;

  @override
  Widget build(BuildContext context) {
    final label = badge.isEmpty ? null : badge;
    // The folder badge, the sync-state badge, and the duration sit on one line
    // as peer chips. Wrap so a long space name + both pills degrade gracefully
    // on a narrow card instead of overflowing.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x0D0E0F10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        SyncBadge(coreId: coreId, processingStatus: processingStatus),
        if (duration.isNotEmpty)
          Text(
            duration,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
