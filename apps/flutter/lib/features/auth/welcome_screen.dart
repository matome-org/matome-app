import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../dev/god_mode_host.dart';

/// Max width of the content column on wide (web/desktop) viewports.
const double _contentMaxWidth = 440;

/// Unauthenticated landing screen (route `/`). Port of RN `Views/welcome`:
/// wordmark (マトメ / MATOME), headline, feature cards, and the
/// "Create account" / "Have an account? Sign in" CTAs. Responsive: a centered,
/// width-constrained column on wide viewports; edge-to-edge on narrow ones.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final features = [
      (
        Icons.mic_none_outlined,
        t.welcome.featureCaptureTitle,
        t.welcome.featureCaptureSubtitle,
      ),
      (
        Icons.auto_awesome_outlined,
        t.welcome.featureSummariesTitle,
        t.welcome.featureSummariesSubtitle,
      ),
      (
        Icons.folder_outlined,
        t.welcome.featureSpacesTitle,
        t.welcome.featureSpacesSubtitle,
      ),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.xl + spacing.xs,
                spacing.lg,
                spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wordmark.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'マトメ',
                        style: typography.display.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(width: spacing.xs),
                      Padding(
                        padding: EdgeInsets.only(bottom: spacing.xxs),
                        child: Text(
                          'MATOME',
                          style: typography.bodySmall.copyWith(
                            letterSpacing: 3,
                            fontWeight: FontWeight.w700,
                            color: colors.accentDark,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // God-mode custom-host affordance (renders nothing unless
                      // FeatureFlags.godMode is on).
                      const GodModeHostButton(),
                    ],
                  ),
                  SizedBox(height: spacing.xl + spacing.xs),
                  // Headline.
                  Text.rich(
                    TextSpan(
                      style: typography.display.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                      children: [
                        TextSpan(text: '${t.welcome.headlineLine1}\n'),
                        TextSpan(text: '${t.welcome.headlineLine2}\n'),
                        TextSpan(
                          text: t.welcome.headlineAccent,
                          style: typography.display.copyWith(
                            color: colors.accentDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing.md),
                  Text(
                    t.welcome.subheadline,
                    style: typography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  // Feature cards.
                  for (final f in features) ...[
                    _FeatureRow(icon: f.$1, title: f.$2, subtitle: f.$3),
                    SizedBox(height: spacing.md),
                  ],
                  SizedBox(height: spacing.md),
                  // CTAs.
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      onPressed: () => context.go('/signup'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.textPrimary,
                        foregroundColor: colors.onTextPrimary,
                        minimumSize: Size.fromHeight(spacing.xxl + spacing.xxs),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius.lg),
                        ),
                      ),
                      child: Text(
                        t.auth.createAccount,
                        style: typography.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.sm),
                  Center(
                    child: AppTextButton(
                      onPressed: () => context.go('/login'),
                      child: Text.rich(
                        TextSpan(
                          style: typography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                          children: [
                            TextSpan(text: t.welcome.haveAccount),
                            TextSpan(
                              text: t.welcome.signIn,
                              style: typography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: spacing.xl + spacing.sm,
          height: spacing.xl + spacing.sm,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: Icon(
            icon,
            size: typography.title.fontSize,
            color: colors.accentDark,
          ),
        ),
        SizedBox(width: spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              SizedBox(height: spacing.xxs),
              Text(
                subtitle,
                style: typography.label.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
