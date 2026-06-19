import 'package:flutter/material.dart';

import '../core/db/recording_card.dart';
import '../core/theme/app_theme.dart';
import '../i18n/strings.g.dart';
import 'app_button.dart';
import 'avatar.dart';
import 'loading_indicator.dart';
import 'status_badge.dart';

const _pendingUploadStatus = 'pending_upload';

enum AppCardRecordingState { pendingUpload, processing, done, failed }

enum _AppCardVariant { recording, calendar }

class AppCard extends StatelessWidget {
  const AppCard.recording({
    super.key,
    required this.card,
    required this.relativeTime,
    this.onTap,
    this.onLongPress,
    this.onRetry,
  }) : id = null,
       title = null,
       badge = null,
       statusLabel = null,
       durationLabel = null,
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
       relativeTime = null,
       onLongPress = null,
       onRetry = null,
       _variant = _AppCardVariant.calendar;

  final _AppCardVariant _variant;
  final RecordingItem? card;
  final String? relativeTime;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
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
    if (status == _pendingUploadStatus) {
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
    };
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
                t.cardStatus.failed,
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
            style: TextStyle(
              fontSize: 11,
              color: context.colors.textMuted,
            ),
          ),
      ],
    );
  }
}
