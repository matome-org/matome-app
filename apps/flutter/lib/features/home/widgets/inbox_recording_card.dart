import 'package:flutter/material.dart';

import '../../../core/db/recording_card.dart';
import '../../../core/theme/app_theme.dart';

/// A single Inbox row rendered from the Drift [RecordingCard] (S1, #780).
///
/// Ported in spirit from the lab `RecordingCard`, but bound to the persisted
/// card type (string fields) instead of the HTTP [Recording] model: leading
/// status/media avatar, title + duration, summary OR a processing/failed line,
/// and a footer with the badge.
class InboxRecordingCard extends StatelessWidget {
  const InboxRecordingCard({
    super.key,
    required this.card,
    required this.relativeTime,
    this.onTap,
    this.onLongPress,
  });

  final RecordingCard card;

  /// Pre-formatted relative timestamp shown top-right (e.g. "3h", "2d").
  final String relativeTime;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  bool get _isProcessing =>
      card.isProcessing ||
      card.processingStatus == 'processing' ||
      card.processingStatus == 'pending';

  bool get _isFailed => card.processingStatus == 'failed';

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
                  isProcessing: _isProcessing,
                  isFailed: _isFailed,
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
                        isProcessing: _isProcessing,
                        isFailed: _isFailed,
                      ),
                      const SizedBox(height: 6),
                      _Footer(
                        badge: card.badge,
                        color: color,
                        duration: card.duration,
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
    required this.isProcessing,
    required this.isFailed,
    required this.mediaIcon,
  });

  final Color color;
  final bool isProcessing;
  final bool isFailed;
  final IconData mediaIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        shape: BoxShape.circle,
      ),
      child: isProcessing
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : isFailed
              ? const Icon(Icons.warning_amber_rounded,
                  size: 16, color: AppColors.failed)
              : Icon(mediaIcon, size: 18, color: color),
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
    required this.isProcessing,
    required this.isFailed,
  });

  final RecordingCard card;
  final Color color;
  final bool isProcessing;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            'Processing…',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: color,
            ),
          ),
        ],
      );
    }

    if (isFailed) {
      return const Text(
        'Processing failed',
        style: TextStyle(fontSize: 12, color: AppColors.failed),
      );
    }

    final summary = card.summary;
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();
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

class _Footer extends StatelessWidget {
  const _Footer({
    required this.badge,
    required this.color,
    required this.duration,
  });

  final String badge;
  final Color color;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final label = badge.isEmpty ? null : badge;
    return Row(
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
        if (label != null && duration.isNotEmpty) const SizedBox(width: 8),
        if (duration.isNotEmpty)
          Text(
            duration,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
