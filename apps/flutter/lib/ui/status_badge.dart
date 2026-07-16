import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/recordings/recording_ids.dart';
import '../i18n/strings.g.dart';

enum SyncState { onDevice, cloud }

enum _StatusBadgeVariant { label, sync }

class StatusBadge extends StatelessWidget {
  const StatusBadge.label({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.textColor,
    this.showDot = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.borderRadius = 999,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w600,
    this.semanticLabel,
  }) : coreId = null,
       processingStatus = null,
       _variant = _StatusBadgeVariant.label;

  const StatusBadge.sync({
    super.key,
    required this.coreId,
    this.processingStatus,
  }) : label = null,
       color = null,
       backgroundColor = null,
       textColor = null,
       showDot = false,
       padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
       borderRadius = 999,
       fontSize = 11,
       fontWeight = FontWeight.w600,
       semanticLabel = null,
       _variant = _StatusBadgeVariant.sync;

  final _StatusBadgeVariant _variant;
  final String? label;
  final Color? color;
  final Color? backgroundColor;
  final Color? textColor;
  final bool showDot;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double fontSize;
  final FontWeight fontWeight;
  final String? semanticLabel;
  final int? coreId;
  final String? processingStatus;

  SyncState get syncState {
    final status = processingStatus;
    if (status != null && isUploadQueuePendingStatus(status)) {
      return SyncState.onDevice;
    }
    return coreId != null ? SyncState.cloud : SyncState.onDevice;
  }

  @override
  Widget build(BuildContext context) {
    return switch (_variant) {
      _StatusBadgeVariant.label => _buildLabel(context),
      _StatusBadgeVariant.sync => _buildSync(context),
    };
  }

  Widget _buildLabel(BuildContext context) {
    final colors = context.colors;
    final badgeColor = color ?? colors.textSecondary;
    final child = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? _defaultLabelBackground(context, colors),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label ?? '',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );

    final semantics = semanticLabel;
    if (semantics == null) return child;

    return Semantics(label: semantics, child: child);
  }

  Color _defaultLabelBackground(BuildContext context, MatomeColors colors) {
    return Theme.of(context).brightness == Brightness.dark
        ? colors.textPrimary.withValues(alpha: 0.10)
        : colors.subtleFillStrong;
  }

  Widget _buildSync(BuildContext context) {
    final colors = context.colors;
    final (
      IconData icon,
      String syncLabel,
      Color syncColor,
    ) = switch (syncState) {
      SyncState.cloud => (
        Icons.cloud_done_outlined,
        t.cardStatus.cloud,
        colors.badgePersonal,
      ),
      // One on-device glyph app-wide: cloud_off everywhere (no smartphone icon).
      SyncState.onDevice => (
        Icons.cloud_off_outlined,
        t.cardStatus.onDevice,
        colors.textSecondary,
      ),
    };

    return Semantics(
      label: '${t.cardStatus.syncState}: $syncLabel',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('sync-badge-${syncState.name}'),
          padding: padding,
          decoration: BoxDecoration(
            color: syncColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: syncColor),
              const SizedBox(width: 5),
              Text(
                syncLabel,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: syncColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
