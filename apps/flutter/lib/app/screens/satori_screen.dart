import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';

/// Reading-width clamp so the roadmap content doesn't sprawl on wide windows.
const double _contentMaxWidth = 640;

/// Roadmap status for a single Satori feature, driving the leading dot styling.
enum _RoadmapState { done, active, next }

class _RoadmapItem {
  const _RoadmapItem({
    required this.state,
    required this.title,
    required this.detail,
  });

  final _RoadmapState state;
  final String title;
  final String detail;
}

/// Satori tab (route `/satori`). Parity port of the RN `Views/Satori/Satori.tsx`
/// "under construction" screen: an amber medallion with a sparkles glyph + SOON
/// badge, a headline/body, and a roadmap card listing the upcoming AI features
/// with their ship status (shipped / in progress / next / later). No real AI
/// interaction — the mobile app does not implement it either.
class SatoriScreen extends StatelessWidget {
  const SatoriScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final s = t.satori;
    final notifyBackground = theme.brightness == Brightness.dark
        ? colors.surface
        : colors.textPrimary;
    final notifyForeground = theme.brightness == Brightness.dark
        ? colors.textPrimary
        : colors.surface;

    final roadmap = <_RoadmapItem>[
      _RoadmapItem(
        state: _RoadmapState.done,
        title: s.roadmapSearchTitle,
        detail: s.roadmapSearchDetail,
      ),
      _RoadmapItem(
        state: _RoadmapState.active,
        title: s.roadmapQuestionsTitle,
        detail: s.roadmapQuestionsDetail,
      ),
      _RoadmapItem(
        state: _RoadmapState.next,
        title: s.roadmapEmailsTitle,
        detail: s.roadmapEmailsDetail,
      ),
      _RoadmapItem(
        state: _RoadmapState.next,
        title: s.roadmapInsightsTitle,
        detail: s.roadmapInsightsDetail,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            spacing.lg,
            spacing.md,
            spacing.lg,
            spacing.xxl + spacing.xxl + spacing.xxs,
          ),
          // Reading-width clamp so the roadmap card and CTA don't sprawl across
          // a wide desktop window (they previously stretched edge-to-edge).
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header.
                  Text(
                    s.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: spacing.xxs),
                  Text(
                    s.subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xl + spacing.xxs),

                  // Medallion + headline (centered).
                  const _Medallion(),
                  SizedBox(height: spacing.lg),
                  Text(
                    s.underConstruction,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.accentDark,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  _Headline(theme: theme),
                  SizedBox(height: spacing.sm),
                  Text(
                    s.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: spacing.lg + spacing.xxs),

                  // Roadmap card.
                  _RoadmapCard(label: s.roadmapLabel, items: roadmap),
                  SizedBox(height: spacing.md + spacing.xxs),

                  // Notify CTA (decorative parity — no real action).
                  PrimaryButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.auto_awesome, color: colors.accent),
                    style: FilledButton.styleFrom(
                      backgroundColor: notifyBackground,
                      foregroundColor: notifyForeground,
                      padding: EdgeInsets.symmetric(vertical: spacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(radius.lg),
                      ),
                    ),
                    label: Text(s.notify),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final elevation = context.elevation;
    final badgeBackground = theme.brightness == Brightness.dark
        ? colors.surface
        : colors.textPrimary;

    return SizedBox(
      width: spacing.xxl + spacing.xxl + spacing.xl + spacing.sm,
      height: spacing.xxl + spacing.xxl + spacing.xl + spacing.sm,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            color: colors.accent,
            elevation: elevation.level3,
            shadowColor: colors.accent.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: SizedBox(
              width: spacing.xxl + spacing.xxl + spacing.lg,
              height: spacing.xxl + spacing.xxl + spacing.lg,
              child: Icon(
                Icons.auto_awesome,
                size: spacing.xxl + spacing.xxs,
                color: colors.onAccent,
              ),
            ),
          ),
          Positioned(
            right: spacing.xxs,
            bottom: spacing.xs,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: badgeBackground,
                borderRadius: BorderRadius.circular(radius.pill),
              ),
              child: Text(
                t.satori.soon,
                style: typography.label.copyWith(
                  color: colors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final base = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.2,
    );
    final s = t.satori;
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: s.headlinePrefix),
          TextSpan(
            text: s.headlineAccent,
            style: base?.copyWith(color: colors.accentDark),
          ),
          TextSpan(text: s.headlineSuffix),
        ],
      ),
    );
  }
}

class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({required this.label, required this.items});

  final String label;
  final List<_RoadmapItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: spacing.xs),
          for (var i = 0; i < items.length; i++)
            _RoadmapRow(item: items[i], showDivider: i < items.length - 1),
        ],
      ),
    );
  }
}

class _RoadmapRow extends StatelessWidget {
  const _RoadmapRow({required this.item, required this.showDivider});

  final _RoadmapItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final isNext = item.state == _RoadmapState.next;
    return Container(
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            )
          : null,
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoadmapDot(state: item.state),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNext
                        ? colors.textSecondary
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  item.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapDot extends StatelessWidget {
  const _RoadmapDot({required this.state});
  final _RoadmapState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    switch (state) {
      case _RoadmapState.done:
        return Container(
          width: spacing.md + spacing.xxs,
          height: spacing.md + spacing.xxs,
          margin: EdgeInsets.only(top: spacing.xxs),
          decoration: BoxDecoration(
            color: colors.accent,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: spacing.sm, color: colors.onAccent),
        );
      case _RoadmapState.active:
        return Container(
          width: spacing.md + spacing.xxs,
          height: spacing.md + spacing.xxs,
          margin: EdgeInsets.only(top: spacing.xxs),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.accent, width: 2),
          ),
          child: Container(
            width: spacing.xs,
            height: spacing.xs,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _RoadmapState.next:
        return Container(
          width: spacing.md + spacing.xxs,
          height: spacing.md + spacing.xxs,
          margin: EdgeInsets.only(top: spacing.xxs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.textMuted, width: 1.5),
          ),
        );
    }
  }
}
