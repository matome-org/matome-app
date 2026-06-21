// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/auth/auth_widgets.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/app_bottom_sheet.dart';
import 'package:matome_flutter/ui/app_button.dart';
import 'package:matome_flutter/ui/app_card.dart';
import 'package:matome_flutter/ui/app_dialog.dart';
import 'package:matome_flutter/ui/app_text_field.dart';
import 'package:matome_flutter/ui/avatar.dart';
import 'package:matome_flutter/ui/empty_state.dart';
import 'package:matome_flutter/ui/loading_indicator.dart';
import 'package:matome_flutter/ui/status_badge.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

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
  const MatomeWidgetbook({super.key, this.initialRoute = '/'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      initialRoute: initialRoute,
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
        LocalizationAddon(
          locales: const [Locale('en'), Locale('ja')],
          localizationsDelegates: _localizationsDelegates,
          initialLocale: const Locale('en'),
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

@widgetbook.UseCase(
  name: 'Fields + submit',
  type: AppTextField,
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
  name: 'Primary states',
  type: PrimaryButton,
  path: '[Catalog]/Buttons',
)
Widget primaryButtonsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _PrimaryButtonsSample());
}

@widgetbook.UseCase(
  name: 'Text actions',
  type: AppTextButton,
  path: '[Catalog]/Buttons',
)
Widget appTextButtonsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _TextButtonsSample());
}

@widgetbook.UseCase(
  name: 'Labeled states',
  type: AppTextField,
  path: '[Catalog]/Inputs',
)
Widget appTextFieldsUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _TextFieldsSample());
}

@widgetbook.UseCase(
  name: 'Icon + initials',
  type: Avatar,
  path: '[Catalog]/Avatars',
)
Widget avatarsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _AvatarsSample());
}

@widgetbook.UseCase(name: 'Done', type: AppCard, path: '[Catalog]/Cards')
Widget appCardDoneUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.done),
  );
}

@widgetbook.UseCase(
  name: 'Pending upload',
  type: AppCard,
  path: '[Catalog]/Cards',
)
Widget appCardPendingUploadUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.pendingUpload),
  );
}

@widgetbook.UseCase(name: 'Processing', type: AppCard, path: '[Catalog]/Cards')
Widget appCardProcessingUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.processing),
  );
}

@widgetbook.UseCase(name: 'Failed', type: AppCard, path: '[Catalog]/Cards')
Widget appCardFailedUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.failed),
  );
}

@widgetbook.UseCase(
  name: 'Calendar row',
  type: AppCard,
  path: '[Catalog]/Cards',
)
Widget appCardCalendarUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _CalendarAppCardSample());
}

@widgetbook.UseCase(
  name: 'Sync states',
  type: StatusBadge,
  path: '[Catalog]/Status',
)
Widget statusBadgesUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _StatusBadgesSample());
}

@widgetbook.UseCase(
  name: 'Action list',
  type: AppBottomSheet,
  path: '[Catalog]/Overlays',
)
Widget appBottomSheetUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _BottomSheetSample());
}

@widgetbook.UseCase(
  name: 'Confirmation',
  type: AppDialog,
  path: '[Catalog]/Overlays',
)
Widget appDialogUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _DialogSample());
}

@widgetbook.UseCase(
  name: 'Spinner sizes',
  type: LoadingIndicator,
  path: '[Catalog]/Feedback',
)
Widget loadingIndicatorUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 300, child: _LoadingIndicatorSample());
}

@widgetbook.UseCase(
  name: 'Centered message',
  type: EmptyState,
  path: '[Catalog]/Feedback',
)
Widget emptyStateUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _EmptyStateSample());
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
        AppTextField(
          controller: _email,
          label: t.auth.email,
          hint: t.auth.emailPlaceholder,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        AppTextField(
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

class _PrimaryButtonsSample extends StatelessWidget {
  const _PrimaryButtonsSample();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PrimaryButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: colors.textPrimary,
            foregroundColor: colors.onTextPrimary,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Create account',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton.icon(
          onPressed: () {},
          icon: Icon(Icons.auto_awesome, color: colors.accent),
          style: FilledButton.styleFrom(
            backgroundColor: colors.surface,
            foregroundColor: colors.textPrimary,
            minimumSize: const Size.fromHeight(48),
          ),
          label: const Text('Notify me'),
        ),
        const SizedBox(height: 12),
        PrimaryButton(onPressed: null, child: const Text('Disabled')),
      ],
    );
  }
}

class _TextButtonsSample extends StatelessWidget {
  const _TextButtonsSample();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppTextButton(onPressed: () {}, child: const Text('Sign in')),
        AppTextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
        AppTextButton(
          onPressed: () {},
          style: TextButton.styleFrom(foregroundColor: colors.failed),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}

class _TextFieldsSample extends StatefulWidget {
  const _TextFieldsSample();

  @override
  State<_TextFieldsSample> createState() => _TextFieldsSampleState();
}

class _TextFieldsSampleState extends State<_TextFieldsSample> {
  late final TextEditingController _email = TextEditingController(
    text: 'demo@matome.app',
  );
  late final TextEditingController _disabled = TextEditingController(
    text: 'Read-only state',
  );

  @override
  void dispose() {
    _email.dispose();
    _disabled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: _email,
          label: 'Email',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _disabled,
          label: 'Disabled',
          hint: 'Unavailable',
          enabled: false,
        ),
      ],
    );
  }
}

class _AvatarsSample extends StatelessWidget {
  const _AvatarsSample();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Avatar(
          initials: 'M',
          size: 44,
          backgroundColor: colors.textPrimary,
          foregroundColor: colors.onTextPrimary,
        ),
        Avatar(
          icon: Icons.mic,
          size: 44,
          backgroundColor: colors.accentSoft,
          foregroundColor: colors.accentDark,
        ),
        Avatar(
          size: 44,
          backgroundColor: colors.failed.withValues(alpha: 0.13),
          child: Icon(Icons.warning_amber_rounded, color: colors.failed),
        ),
        Avatar(
          size: 44,
          backgroundColor: colors.accent.withValues(alpha: 0.13),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.accent,
            ),
          ),
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

class _AppCardSample extends StatelessWidget {
  const _AppCardSample({required this.state});

  final _CardSampleState state;

  @override
  Widget build(BuildContext context) {
    return AppCard.recording(
      card: _recordingCard(state),
      relativeTime: '3h',
      onRetry: state == _CardSampleState.failed ? () {} : null,
    );
  }
}

class _StatusBadgesSample extends StatelessWidget {
  const _StatusBadgesSample();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        StatusBadge.label(label: 'Work', color: Color(0xFFE1B346)),
        StatusBadge.sync(
          coreId: null,
          processingStatus: kProcessingStatusPendingUpload,
        ),
        StatusBadge.sync(coreId: 42, processingStatus: 'done'),
      ],
    );
  }
}

class _BottomSheetSample extends StatelessWidget {
  const _BottomSheetSample();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: AppBottomSheet(
        title: Text(
          'Move to space',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        children: [
          ListTile(
            leading: Icon(Icons.folder_outlined, color: colors.textSecondary),
            title: const Text('Design Lab'),
          ),
          ListTile(
            leading: Icon(Icons.folder_outlined, color: colors.textSecondary),
            title: const Text('Personal'),
          ),
        ],
      ),
    );
  }
}

class _DialogSample extends StatelessWidget {
  const _DialogSample();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return AppDialog(
      backgroundColor: colors.surface,
      title: const Text('Discard recording?'),
      content: const Text('This take has not been saved yet.'),
      actions: [
        AppTextButton(onPressed: () {}, child: const Text('Keep editing')),
        PrimaryButton(
          onPressed: () {},
          style: FilledButton.styleFrom(backgroundColor: colors.failed),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}

class _LoadingIndicatorSample extends StatelessWidget {
  const _LoadingIndicatorSample();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LoadingIndicator(size: 16, strokeWidth: 2, color: colors.accent),
        LoadingIndicator(size: 24, strokeWidth: 2, color: colors.primary),
        LoadingIndicator(size: 36, color: colors.textSecondary),
      ],
    );
  }
}

class _EmptyStateSample extends StatelessWidget {
  const _EmptyStateSample();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No recordings yet',
        message: 'Recordings you capture or upload will show up here.',
      ),
    );
  }
}

class _CalendarAppCardSample extends StatelessWidget {
  const _CalendarAppCardSample();

  @override
  Widget build(BuildContext context) {
    return AppCard.calendar(
      id: 'rec_calendar_widgetbook',
      title: 'Roadmap review',
      badge: 'Work',
      statusLabel: 'Design Lab',
      durationLabel: '8:42',
      onTap: () {},
    );
  }
}

RecordingItem _recordingCard(_CardSampleState state) {
  return switch (state) {
    _CardSampleState.done => const RecordingItem(
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
    _CardSampleState.pendingUpload => RecordingItem(
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
    _CardSampleState.processing => const RecordingItem(
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
    _CardSampleState.failed => const RecordingItem(
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
