import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';

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
    final s = t.satori;

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
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
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
              const SizedBox(height: 2),
              Text(
                s.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),

              // Medallion + headline (centered).
              const _Medallion(),
              const SizedBox(height: 24),
              Text(
                s.underConstruction,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.accentDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              _Headline(theme: theme),
              const SizedBox(height: 12),
              Text(
                s.body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Roadmap card.
              _RoadmapCard(label: s.roadmapLabel, items: roadmap),
              const SizedBox(height: 20),

              // Notify CTA (decorative parity — no real action).
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.auto_awesome, color: AppColors.accent),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                label: Text(s.notify),
              ),
            ],
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
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 52,
              color: Colors.white,
            ),
          ),
          Positioned(
            right: 4,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                t.satori.soon,
                style: const TextStyle(
                  color: AppColors.accent,
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
            style: base?.copyWith(color: AppColors.accentDark),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            _RoadmapRow(
              item: items[i],
              showDivider: i < items.length - 1,
            ),
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
    final isNext = item.state == _RoadmapState.next;
    return Container(
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoadmapDot(state: item.state),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNext
                        ? AppColors.textSecondary
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
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
    switch (state) {
      case _RoadmapState.done:
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 12, color: AppColors.textPrimary),
        );
      case _RoadmapState.active:
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2),
          ),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
        );
      case _RoadmapState.next:
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textMuted, width: 1.5),
          ),
        );
    }
  }
}
