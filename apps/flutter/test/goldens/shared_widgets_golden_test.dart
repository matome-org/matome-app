import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/auth/auth_widgets.dart';
import 'package:matome_flutter/features/home/widgets/inbox_recording_card.dart';
import 'package:matome_flutter/features/home/widgets/sync_badge.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

void main() {
  group('shared widget goldens', () {
    for (final variant in _variants) {
      goldenTest(
        'renders ${variant.label}',
        fileName: 'shared_widgets_${variant.fileSuffix}',
        constraints: const BoxConstraints.tightFor(width: 1040, height: 900),
        pumpBeforeTest: pumpOnce,
        builder: () {
          LocaleSettings.setLocaleSync(variant.locale);
          return _GoldenApp(
            variant: variant,
            child: GoldenTestGroup(
              columns: 2,
              scenarioConstraints: const BoxConstraints.tightFor(width: 420),
              children: [
                GoldenTestScenario(
                  name: 'auth controls',
                  child: _AuthControlsSample(),
                ),
                GoldenTestScenario(
                  name: 'auth loading + error',
                  child: _AuthFeedbackSample(),
                ),
                GoldenTestScenario(
                  name: 'inbox card - done',
                  child: _InboxCardSample(state: _CardSampleState.done),
                ),
                GoldenTestScenario(
                  name: 'inbox card - pending upload',
                  child: _InboxCardSample(
                    state: _CardSampleState.pendingUpload,
                  ),
                ),
                GoldenTestScenario(
                  name: 'inbox card - processing',
                  child: _InboxCardSample(state: _CardSampleState.processing),
                ),
                GoldenTestScenario(
                  name: 'inbox card - failed',
                  child: _InboxCardSample(state: _CardSampleState.failed),
                ),
                GoldenTestScenario(
                  name: 'sync badges',
                  child: _SyncBadgesSample(),
                ),
              ],
            ),
          );
        },
      );
    }
  });
}

final _variants = [
  _GoldenVariant(
    fileSuffix: 'light_en',
    label: 'light theme / English',
    locale: AppLocale.en,
    theme: buildLightTheme(),
  ),
  _GoldenVariant(
    fileSuffix: 'dark_en',
    label: 'dark theme / English',
    locale: AppLocale.en,
    theme: buildDarkTheme(),
  ),
  _GoldenVariant(
    fileSuffix: 'light_ja',
    label: 'light theme / Japanese',
    locale: AppLocale.ja,
    theme: buildLightTheme(),
  ),
  _GoldenVariant(
    fileSuffix: 'dark_ja',
    label: 'dark theme / Japanese',
    locale: AppLocale.ja,
    theme: buildDarkTheme(),
  ),
];

class _GoldenVariant {
  const _GoldenVariant({
    required this.fileSuffix,
    required this.label,
    required this.locale,
    required this.theme,
  });

  final String fileSuffix;
  final String label;
  final AppLocale locale;
  final ThemeData theme;
}

class _GoldenApp extends StatelessWidget {
  const _GoldenApp({required this.variant, required this.child});

  final _GoldenVariant variant;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: Builder(
        builder: (context) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: variant.theme,
            locale: TranslationProvider.of(context).flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              backgroundColor: variant.theme.scaffoldBackgroundColor,
              body: Padding(padding: const EdgeInsets.all(24), child: child),
            ),
          );
        },
      ),
    );
  }
}

class _AuthControlsSample extends StatefulWidget {
  const _AuthControlsSample();

  @override
  State<_AuthControlsSample> createState() => _AuthControlsSampleState();
}

class _AuthControlsSampleState extends State<_AuthControlsSample> {
  late final TextEditingController _email = TextEditingController(
    text: 'demo@matome.app',
  );
  late final TextEditingController _password = TextEditingController(
    text: 'alchemy123',
  );

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthField(
          controller: _email,
          label: t.auth.email,
          hint: t.auth.emailPlaceholder,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        AuthField(
          controller: _password,
          label: t.auth.password,
          hint: t.auth.passwordPlaceholder,
          obscure: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
        ),
        const SizedBox(height: 24),
        AuthSubmitButton(
          label: t.welcome.signIn,
          loading: false,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _AuthFeedbackSample extends StatelessWidget {
  const _AuthFeedbackSample();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthErrorBanner(message: t.auth.errorInvalidCredentials),
        const SizedBox(height: 16),
        AuthSubmitButton(
          label: t.auth.createAccount,
          loading: true,
          onPressed: () {},
        ),
      ],
    );
  }
}

enum _CardSampleState { done, pendingUpload, processing, failed }

class _InboxCardSample extends StatelessWidget {
  const _InboxCardSample({required this.state});

  final _CardSampleState state;

  @override
  Widget build(BuildContext context) {
    return InboxRecordingCard(
      card: _recordingCard(state),
      relativeTime: '3h',
      onRetry: state == _CardSampleState.failed ? () {} : null,
    );
  }
}

class _SyncBadgesSample extends StatelessWidget {
  const _SyncBadgesSample();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SyncBadge(
          coreId: null,
          processingStatus: kProcessingStatusPendingUpload,
        ),
        SyncBadge(coreId: 42, processingStatus: 'done'),
      ],
    );
  }
}

RecordingCard _recordingCard(_CardSampleState state) {
  return switch (state) {
    _CardSampleState.done => const RecordingCard(
      id: 'rec_42',
      title: 'Design sync',
      summary: 'Decisions, owners, and next steps from the product review.',
      timestamp: '1:00 PM',
      duration: '12m 34s',
      badge: 'Work',
      isProcessing: false,
      mediaType: 'audio',
      processingStatus: 'done',
      coreId: 42,
    ),
    _CardSampleState.pendingUpload => RecordingCard(
      id: 'rec_local_golden_pending',
      title: 'Offline capture',
      summary: null,
      timestamp: '10:24 AM',
      duration: '48s',
      badge: 'Inbox',
      isProcessing: true,
      mediaType: 'audio',
      processingStatus: kProcessingStatusPendingUpload,
      coreId: null,
    ),
    _CardSampleState.processing => const RecordingCard(
      id: 'rec_77',
      title: 'Interview notes',
      summary: null,
      timestamp: '9:10 AM',
      duration: '5m 02s',
      badge: 'Ideas',
      isProcessing: true,
      mediaType: 'audio',
      processingStatus: 'processing',
      coreId: 77,
    ),
    _CardSampleState.failed => const RecordingCard(
      id: 'rec_failed',
      title: 'Retry upload',
      summary: null,
      timestamp: 'Yesterday',
      duration: '1m 09s',
      badge: 'Personal',
      isProcessing: false,
      mediaType: 'audio',
      processingStatus: 'failed',
      coreId: null,
    ),
  };
}
