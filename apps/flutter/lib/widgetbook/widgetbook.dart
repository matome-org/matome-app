// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import '../core/db/recording_card.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_widgets.dart';
import '../features/home/widgets/inbox_recording_card.dart';
import '../features/home/widgets/sync_badge.dart';
import '../features/recordings/recording_ids.dart';
import '../i18n/strings.g.dart';
import 'widgetbook.directories.g.dart';

const _localizationsDelegates = <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.setLocaleSync(AppLocale.en);
  runApp(const MatomeWidgetbook());
}

@widgetbook.App()
class MatomeWidgetbook extends StatelessWidget {
  const MatomeWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      appBuilder: _matomeAppBuilder,
      lightTheme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      addons: [
        MaterialThemeAddon(
          themes: [
            WidgetbookTheme(name: 'Light', data: buildLightTheme()),
            WidgetbookTheme(name: 'Dark', data: buildDarkTheme()),
          ],
        ),
        _MatomeLocalizationAddon(),
        DeviceFrameAddon(
          devices: [
            Devices.ios.iPhone13,
            Devices.android.pixel4,
            Devices.linux.laptop,
          ],
        ),
      ],
    );
  }
}

Widget _matomeAppBuilder(BuildContext context, Widget child) {
  return TranslationProvider(
    child: Builder(
      builder: (context) {
        return MaterialApp(
          title: 'Matome Widgetbook',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          locale: TranslationProvider.of(context).flutterLocale,
          supportedLocales: AppLocaleUtils.supportedLocales,
          localizationsDelegates: _localizationsDelegates,
          home: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: child,
          ),
        );
      },
    ),
  );
}

class _MatomeLocalizationAddon extends LocalizationAddon {
  _MatomeLocalizationAddon()
    : super(
        locales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: _localizationsDelegates,
        initialLocale: AppLocale.en.flutterLocale,
      );

  @override
  Widget buildUseCase(BuildContext context, Widget child, Locale setting) {
    _syncSlangLocale(setting);

    return TranslationProvider(
      child: Localizations(
        locale: setting,
        delegates: localizationsDelegates,
        child: child,
      ),
    );
  }
}

void _syncSlangLocale(Locale locale) {
  final appLocale = AppLocaleUtils.parseLocaleParts(
    languageCode: locale.languageCode,
    scriptCode: locale.scriptCode,
    countryCode: locale.countryCode,
  );

  if (LocaleSettings.currentLocale != appLocale) {
    LocaleSettings.setLocaleSync(appLocale);
  }
}

@widgetbook.UseCase(
  name: 'Fields + submit',
  type: AuthField,
  path: '[Shared widgets]/Auth',
)
Widget authFieldsUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthControlsSample());
}

@widgetbook.UseCase(
  name: 'Error + loading',
  type: AuthErrorBanner,
  path: '[Shared widgets]/Auth',
)
Widget authFeedbackUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthFeedbackSample());
}

@widgetbook.UseCase(
  name: 'Done',
  type: InboxRecordingCard,
  path: '[Shared widgets]/Inbox',
)
Widget inboxCardDoneUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _InboxCardSample(state: _CardSampleState.done),
  );
}

@widgetbook.UseCase(
  name: 'Pending upload',
  type: InboxRecordingCard,
  path: '[Shared widgets]/Inbox',
)
Widget inboxCardPendingUploadUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _InboxCardSample(state: _CardSampleState.pendingUpload),
  );
}

@widgetbook.UseCase(
  name: 'Processing',
  type: InboxRecordingCard,
  path: '[Shared widgets]/Inbox',
)
Widget inboxCardProcessingUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _InboxCardSample(state: _CardSampleState.processing),
  );
}

@widgetbook.UseCase(
  name: 'Failed',
  type: InboxRecordingCard,
  path: '[Shared widgets]/Inbox',
)
Widget inboxCardFailedUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _InboxCardSample(state: _CardSampleState.failed),
  );
}

@widgetbook.UseCase(
  name: 'Sync states',
  type: SyncBadge,
  path: '[Shared widgets]/Inbox',
)
Widget syncBadgesUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _SyncBadgesSample());
}

class _UseCaseSurface extends StatelessWidget {
  const _UseCaseSurface({required this.child, this.width = 420});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: child,
        ),
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
      id: 'rec_local_widgetbook_pending',
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
