import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../recordings/recording.dart';
import '../home_filters.dart';

/// A single recording row, ported in essence from the RN `RecordingCard`:
/// leading status/media avatar, title + relative time, summary OR
/// processing/failed line (with retry), and a footer with badge + duration.
class RecordingCard extends StatelessWidget {
  const RecordingCard({
    super.key,
    required this.recording,
    this.onTap,
    this.onRetry,
    this.now,
  });

  final Recording recording;
  final VoidCallback? onTap;
  final ValueChanged<Recording>? onRetry;
  final DateTime? now;

  bool get _isProcessing =>
      recording.status == RecordingStatus.pending ||
      recording.status == RecordingStatus.processing;

  bool get _isFailed => recording.status == RecordingStatus.failed;

  IconData get _mediaIcon {
    final type = recording.mediaType ?? '';
    if (type.startsWith('image')) return Icons.image_outlined;
    if (type.contains('meeting') || type.contains('text')) {
      return Icons.description_outlined;
    }
    return Icons.play_arrow_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = badgeColor(recording.badge);
    final timestamp = formatTimestamp(recording.insertedAt, now: now);
    final duration = formatDuration(recording.duration);

    return Semantics(
      button: true,
      label: 'Recording: ${recording.title}',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            // Touch target: padding alone gives a >=44px tall row on mobile.
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
                      _TitleRow(title: recording.title, timestamp: timestamp),
                      const SizedBox(height: 4),
                      _Body(
                        recording: recording,
                        color: color,
                        isProcessing: _isProcessing,
                        isFailed: _isFailed,
                        onRetry: onRetry,
                      ),
                      const SizedBox(height: 6),
                      _Footer(
                        badge: recording.badge,
                        color: color,
                        duration: duration,
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
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
    required this.recording,
    required this.color,
    required this.isProcessing,
    required this.isFailed,
    required this.onRetry,
  });

  final Recording recording;
  final Color color;
  final bool isProcessing;
  final bool isFailed;
  final ValueChanged<Recording>? onRetry;

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
            'Transcribing…',
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
      return Row(
        children: [
          const Expanded(
            child: Text(
              'Transcription failed',
              style: TextStyle(fontSize: 12, color: AppColors.failed),
            ),
          ),
          TextButton(
            onPressed: onRetry == null ? null : () => onRetry!(recording),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              foregroundColor: color,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    final summary = recording.summary;
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

class _Footer extends StatelessWidget {
  const _Footer({
    required this.badge,
    required this.color,
    required this.duration,
  });

  final String? badge;
  final Color color;
  final String duration;

  @override
  Widget build(BuildContext context) {
    final label = (badge == null || badge!.isEmpty) ? null : badge!;
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
