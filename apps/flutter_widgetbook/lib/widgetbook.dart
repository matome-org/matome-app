// ignore_for_file: deprecated_member_use, implementation_imports, invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matome_flutter/app/pages/auth_pages.dart';
import 'package:matome_flutter/app/pages/primary_pages.dart';
import 'package:matome_flutter/app/pages/secondary_pages.dart';
import 'package:matome_flutter/app/screens/recording_screen.dart'
    show RecorderBinding;
import 'package:matome_flutter/core/db/app_database.dart'
    show ContactRow, RecordingRow, WorkspaceRow;
import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/auth/auth_widgets.dart';
import 'package:matome_flutter/core/http/api_exception.dart' show ApiException;
import 'package:matome_flutter/features/auth/auth_controller.dart'
    show AuthController, authControllerProvider;
import 'package:matome_flutter/features/auth/auth_models.dart' show AuthSession;
import 'package:matome_flutter/core/audio/audio_playback.dart';
import 'package:matome_flutter/core/db/file_row.dart';
import 'package:matome_flutter/core/providers.dart'
    show settingsStoreProvider, tokenStoreProvider;
import 'package:matome_flutter/core/settings/settings_store.dart'
    show InMemorySettingsStore;
import 'package:matome_flutter/features/contacts/contact_detail_screen.dart'
    show contactDetailProvider;
import 'package:matome_flutter/features/contacts/contacts_controller.dart'
    show
        ContactsController,
        contactsControllerProvider,
        kPlaceholderContactOwnerId;
import 'package:matome_flutter/features/contacts/widgets/contact_detail.dart';
import 'package:matome_flutter/features/contacts/widgets/contact_tile.dart';
import 'package:matome_flutter/features/details/audio_player_bar.dart';
import 'package:matome_flutter/features/details/details_controller.dart'
    show
        AudioSource,
        AudioSourceKind,
        DetailsController,
        DetailsState,
        detailsControllerProvider;
import 'package:matome_flutter/features/details/file_actions_menu.dart'
    as details_actions;
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/features/files/files_providers.dart'
    show filesForCurrentOwnerProvider;
import 'package:matome_flutter/features/files/files_screen.dart'
    show FilesScreen;
import 'package:matome_flutter/features/files/widgets/files_grid.dart';
import 'package:matome_flutter/features/files/widgets/files_table.dart';
import 'package:matome_flutter/features/files/widgets/files_view_shared.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_item.dart';
import 'package:matome_flutter/features/home/loose_inbox_controller.dart';
import 'package:matome_flutter/features/home/matome_inbox_controller.dart';
import 'package:matome_flutter/features/matome/matome_actions_menu.dart';
import 'package:matome_flutter/features/matome/matome_detail_controller.dart'
    show
        MatomeDetailController,
        MatomeDetailState,
        matomeDetailControllerProvider;
import 'package:matome_flutter/features/matome/widgets/matome_table.dart';
import 'package:matome_flutter/features/recording/audio_recording_service.dart';
import 'package:matome_flutter/features/recording/recording_controller.dart';
import 'package:matome_flutter/features/recording/recording_finish.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/recordings/upload_retry_service.dart';
import 'package:matome_flutter/features/shell/widgets/matome_nav.dart';
import 'package:matome_flutter/features/spaces/filing_spaces_provider.dart';
import 'package:matome_flutter/features/spaces/space_card.dart' show SpaceCard;
import 'package:matome_flutter/features/spaces/space_detail_controller.dart'
    show SpaceDetailController, SpaceDetailState, spaceDetailControllerProvider;
import 'package:matome_flutter/features/spaces/spaces_controller.dart'
    show SpacesController, spacesControllerProvider;
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/app_bottom_sheet.dart';
import 'package:matome_flutter/ui/app_button.dart';
import 'package:matome_flutter/ui/app_card.dart';
import 'package:matome_flutter/ui/app_dialog.dart';
import 'package:matome_flutter/ui/app_text_field.dart';
import 'package:matome_flutter/ui/avatar.dart';
import 'package:matome_flutter/ui/empty_state.dart';
import 'package:matome_flutter/ui/file_type_chip.dart';
import 'package:matome_flutter/ui/files_scope_filter.dart';
import 'package:matome_flutter/ui/inbox_item_card.dart';
import 'package:matome_flutter/ui/loading_indicator.dart';
import 'package:matome_flutter/ui/matome_chip.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';
import 'package:matome_flutter/ui/matome_detail_panel.dart';
import 'package:matome_flutter/ui/people_cluster.dart';
import 'package:matome_flutter/ui/relationship_picker.dart';
import 'package:matome_flutter/ui/role_chip.dart';
import 'package:matome_flutter/ui/space_chip.dart';
import 'package:matome_flutter/ui/space_sync_chip.dart';
import 'package:matome_flutter/ui/space_sync_tile.dart';
import 'package:matome_flutter/ui/status_badge.dart';
import 'package:widgetbook/src/core/widgetbook_app.dart';
import 'package:widgetbook/widgetbook.dart' hide ThemeMode;

import 'foundations_stories.dart';

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

class MatomeWidgetbook extends StatelessWidget {
  const MatomeWidgetbook({super.key, this.initialRoute = '/'});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return WidgetbookApp(config: matomeWidgetbookConfig(initialRoute));
  }
}

Config matomeWidgetbookConfig([String initialRoute = '/']) {
  return Config(
    initialRoute: initialRoute,
    components: matomeWidgetbookComponents,
    appBuilder: _matomeAppBuilder,
    lightTheme: buildLightTheme(),
    darkTheme: buildDarkTheme(),
    themeMode: ThemeMode.light,
    addons: [
      MaterialThemeAddon({
        'Light': buildLightTheme(),
        'Dark': buildDarkTheme(),
      }),
      LocaleAddon(const [Locale('en'), Locale('ja')], _localizationsDelegates),
    ],
    docsBuilder: () => const [ComponentNameDocBlock()],
  );
}

class _StaticStoryArgs extends StoryArgs<Widget> {
  const _StaticStoryArgs();

  @override
  List<Arg?> get list => const [];
}

class _StaticStory extends Story<Widget, _StaticStoryArgs> {
  _StaticStory({required String name, required WidgetBuilder builder})
    : super(
        name: name,
        args: const _StaticStoryArgs(),
        builder: (context, args) => builder(context),
      );
}

class _StorySpec {
  const _StorySpec(this.name, this.builder);

  final String name;
  final WidgetBuilder builder;
}

Component<Widget, _StaticStoryArgs> _component({
  required String name,
  required String path,
  required String docs,
  required List<_StorySpec> stories,
  double docsStoryHeight = 760,
}) {
  return Component<Widget, _StaticStoryArgs>(
    name: name,
    path: path,
    docsBuilder: (_) => [
      const ComponentNameDocBlock(),
      TextDocBlock(docs),
      _MatomeStoriesDocBlock(
        componentName: name,
        componentPath: path,
        stories: stories,
        height: docsStoryHeight,
      ),
    ],
    stories: [
      for (final story in stories)
        _StaticStory(name: story.name, builder: story.builder),
    ],
  );
}

class _MatomeStoriesDocBlock extends DocBlock {
  const _MatomeStoriesDocBlock({
    required this.componentName,
    required this.componentPath,
    required this.stories,
    required this.height,
  });

  final String componentName;
  final String componentPath;
  final List<_StorySpec> stories;
  final double height;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TranslationProvider(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final story in stories) ...[
            Text(story.name, style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            _MatomeDocsPreviewFrame(
              key: ValueKey('$componentPath/$componentName/Docs/${story.name}'),
              previewId: '$componentPath/$componentName/${story.name}',
              height: height,
              builder: story.builder,
            ),
            const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }
}

class _MatomeDocsPreviewFrame extends StatelessWidget {
  const _MatomeDocsPreviewFrame({
    super.key,
    required this.previewId,
    required this.height,
    required this.builder,
  });

  final String previewId;
  final double height;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final previewTheme = Theme.of(context).brightness == Brightness.dark
        ? buildDarkTheme()
        : buildLightTheme();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Theme(
          data: previewTheme,
          child: Material(
            color: previewTheme.scaffoldBackgroundColor,
            child: KeyedSubtree(
              key: ValueKey('$previewId/child'),
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
  }
}

final matomeWidgetbookComponents = <Component<Widget, _StaticStoryArgs>>[
  _component(
    name: 'AppTypography',
    path: 'Foundations',
    docs: 'Type scale, font weights, and text rhythm used by Matome UI.',
    stories: [const _StorySpec('Typography', typographyUseCase)],
  ),
  _component(
    name: 'Icons',
    path: 'Foundations',
    docs: 'Icon families and semantic usage checks for the shared catalog.',
    stories: [const _StorySpec('Icons', iconsUseCase)],
  ),
  _component(
    name: 'MatomeColors',
    path: 'Foundations',
    docs: 'Color roles for light and dark themes.',
    stories: [const _StorySpec('Colors', colorsUseCase)],
  ),

  _component(
    name: 'AppTextField',
    path: 'Components/Atoms/Auth',
    docs: 'Auth field primitives and submit controls used by sign-in flows.',
    stories: [const _StorySpec('Fields + submit', authFieldsUseCase)],
  ),
  _component(
    name: 'AuthErrorBanner',
    path: 'Components/Atoms/Auth',
    docs: 'Authentication feedback primitive for errors and loading states.',
    stories: [const _StorySpec('Error + loading', authFeedbackUseCase)],
  ),
  _component(
    name: 'AuthNoticeBanner',
    path: 'Components/Atoms/Auth',
    docs: 'Authentication positive/notice primitive (e.g. reset link sent).',
    stories: [const _StorySpec('Notice', authNoticeUseCase)],
  ),
  _component(
    name: 'AuthField',
    path: 'Components/Atoms/Auth',
    docs: 'Labeled auth field primitive including obscured text handling.',
    stories: [const _StorySpec('Field (labeled + obscured)', authFieldUseCase)],
  ),
  _component(
    name: 'AuthSubmitButton',
    path: 'Components/Atoms/Auth',
    docs: 'Submit button states for auth forms.',
    stories: [
      const _StorySpec(
        'Submit button (idle / loading / disabled)',
        authSubmitButtonUseCase,
      ),
    ],
  ),
  _component(
    name: 'Avatar',
    path: 'Components/Atoms/Avatars',
    docs: 'Reusable avatar primitive for initials and icon-backed identities.',
    stories: [const _StorySpec('Icon + initials', avatarsUseCase)],
  ),
  _component(
    name: 'AppTextButton',
    path: 'Components/Atoms/Buttons',
    docs: 'Low-emphasis text actions used across app surfaces.',
    stories: [const _StorySpec('Text actions', appTextButtonsUseCase)],
  ),
  _component(
    name: 'PrimaryButton',
    path: 'Components/Atoms/Buttons',
    docs: 'Primary action button states.',
    stories: [const _StorySpec('Primary states', primaryButtonsUseCase)],
  ),
  _component(
    name: 'EmptyState',
    path: 'Components/Atoms/Feedback',
    docs: 'Centered empty-state message primitive.',
    stories: [const _StorySpec('Centered message', emptyStateUseCase)],
  ),
  _component(
    name: 'LoadingIndicator',
    path: 'Components/Atoms/Feedback',
    docs: 'Spinner sizing and loading affordance primitive.',
    stories: [const _StorySpec('Spinner sizes', loadingIndicatorUseCase)],
  ),
  _component(
    name: 'FileTypeChip',
    path: 'Components/Atoms/File view',
    docs: 'Document media header chip for file identity and size metadata.',
    stories: [const _StorySpec('Document media header', fileTypeChipUseCase)],
  ),
  _component(
    name: 'AppTextField',
    path: 'Components/Atoms/Inputs',
    docs: 'General text input states outside the auth-specific form context.',
    stories: [const _StorySpec('Labeled states', appTextFieldsUseCase)],
  ),
  _component(
    name: 'MatomePanelAddRow',
    path: 'Components/Atoms/Panel atoms',
    docs: 'Detail panel add-row atom with accent affordance.',
    stories: [
      const _StorySpec('Add row (accent affordance)', matomePanelAddRowUseCase),
    ],
  ),
  _component(
    name: 'MatomePanelRow',
    path: 'Components/Atoms/Panel atoms',
    docs: 'Detail panel item row atom with icon, meta, and sync chip slots.',
    stories: [
      const _StorySpec(
        'Item row (icon + meta + sync chip)',
        matomePanelRowUseCase,
      ),
    ],
  ),
  _component(
    name: 'MatomePanelSection',
    path: 'Components/Atoms/Panel atoms',
    docs: 'Detail panel section label and divider atom.',
    stories: [
      const _StorySpec('Section (label + divider)', matomePanelSectionUseCase),
    ],
  ),
  _component(
    name: 'MatomeChip',
    path: 'Components/Atoms/Relations',
    docs: 'Matome relation chip including the unfiled fallback.',
    stories: [
      const _StorySpec('Matome chip (filled / Unfiled)', matomeChipUseCase),
    ],
  ),
  _component(
    name: 'PeopleCluster',
    path: 'Components/Atoms/Relations',
    docs: 'Overlapping people initials with overflow count.',
    stories: [
      const _StorySpec(
        'People cluster (overlap / +N overflow)',
        peopleClusterUseCase,
      ),
    ],
  ),
  _component(
    name: 'RoleChip',
    path: 'Components/Atoms/Relations',
    docs: 'Contact role chip color states.',
    stories: [
      const _StorySpec(
        'Role chip (organizer / speaker / attendee)',
        roleChipUseCase,
      ),
    ],
  ),
  _component(
    name: 'SpaceChip',
    path: 'Components/Atoms/Relations',
    docs: 'Space relation chip including the inbox fallback.',
    stories: [
      const _StorySpec('Space chip (outlined / Inbox)', spaceChipUseCase),
    ],
  ),
  _component(
    name: 'MatomeSyncChip',
    path: 'Components/Atoms/Status',
    docs: 'Compact sync status chip for Matome rows and panels.',
    stories: [const _StorySpec('Sync chip', matomeSyncChipUseCase)],
  ),
  _component(
    name: 'StatusBadge',
    path: 'Components/Atoms/Status',
    docs: 'Reusable sync status badge states.',
    stories: [const _StorySpec('Sync states', statusBadgesUseCase)],
  ),

  _component(
    name: 'AppCard',
    path: 'Components/Composite/Cards',
    docs:
        'Composite capture card states used by inbox, calendar, and review lists.',
    stories: const [
      _StorySpec('Calendar row', appCardCalendarUseCase),
      _StorySpec('Done', appCardDoneUseCase),
      _StorySpec('Failed', appCardFailedUseCase),
      _StorySpec('Pending upload', appCardPendingUploadUseCase),
      _StorySpec('Processing', appCardProcessingUseCase),
    ],
  ),
  _component(
    name: 'AudioPlayerBar',
    path: 'Components/Composite/Details',
    docs: 'Audio playback composite used in recording detail surfaces.',
    stories: [
      const _StorySpec(
        'Player - playing (12:04)',
        audioPlayerBarPlayingUseCase,
      ),
      const _StorySpec(
        'Player - unavailable',
        audioPlayerBarUnavailableUseCase,
      ),
    ],
  ),
  _component(
    name: 'FileActionsMenu',
    path: 'Components/Composite/Details',
    docs: 'Details-screen file overflow menu in default and dense variants.',
    stories: [
      const _StorySpec(
        'File overflow menu (delete-only)',
        detailsFileActionsMenuUseCase,
      ),
    ],
  ),
  _component(
    name: 'FileActionsMenu',
    path: 'Components/Composite/Files chrome',
    docs: 'Files-list per-row overflow actions.',
    stories: [
      const _StorySpec('Per-file overflow menu', filesFileActionsMenuUseCase),
    ],
  ),
  _component(
    name: 'FilesBulkBar',
    path: 'Components/Composite/Files chrome',
    docs: 'Bulk-selection action bar for files views.',
    stories: [
      const _StorySpec('Bulk bar (selection active)', filesBulkBarUseCase),
    ],
  ),
  _component(
    name: 'FilesEmptyState',
    path: 'Components/Composite/Files chrome',
    docs: 'Files empty-state composite.',
    stories: [
      const _StorySpec('Empty state (no files)', filesEmptyStateUseCase),
    ],
  ),
  _component(
    name: 'FilesMutedDash',
    path: 'Components/Composite/Files chrome',
    docs: 'Muted dash used when file metadata is absent.',
    stories: [
      const _StorySpec('Muted dash (absent value)', filesMutedDashUseCase),
    ],
  ),
  _component(
    name: 'FilesUndoBar',
    path: 'Components/Composite/Files chrome',
    docs: 'Undo affordance shown after file deletion.',
    stories: [const _StorySpec('Undo bar (after delete)', filesUndoBarUseCase)],
  ),
  _component(
    name: 'MatomeActionsMenu',
    path: 'Components/Composite/Matome',
    docs: 'Matome-level overflow menu actions.',
    stories: [
      const _StorySpec('Matome overflow menu', matomeActionsMenuUseCase),
    ],
  ),
  _component(
    name: 'MatomeAddFab',
    path: 'Components/Composite/Matome',
    docs: 'Floating add action used by mobile Matome navigation.',
    stories: [const _StorySpec('Add FAB', matomeAddFabUseCase)],
  ),
  _component(
    name: 'AppBottomSheet',
    path: 'Components/Composite/Overlays',
    docs: 'Action-list bottom sheet overlay composite.',
    stories: [const _StorySpec('Action list', appBottomSheetUseCase)],
  ),
  _component(
    name: 'AppDialog',
    path: 'Components/Composite/Overlays',
    docs: 'Confirmation dialog overlay composite.',
    stories: [const _StorySpec('Confirmation', appDialogUseCase)],
  ),

  // Frames — Mobile viewport chrome.
  _component(
    name: 'PhoneFrame',
    path: 'Frames/Mobile',
    docs: 'Mobile shell frame used by dock and journey previews.',
    stories: [const _StorySpec('Phone shell', phoneFrameUseCase)],
  ),
  _component(
    name: 'AuthPageFrame',
    path: 'Frames/Mobile',
    docs:
        'Catalog-only auth viewport frame used for welcome/login/signup Pages.',
    stories: [const _StorySpec('Auth viewport', authPageFrameUseCase)],
  ),

  // Frames — Desktop viewport chrome.
  _component(
    name: 'WindowFrame',
    path: 'Frames/Desktop',
    docs: 'Desktop shell frame used by sidebar and responsive previews.',
    stories: [const _StorySpec('Desktop shell', windowFrameUseCase)],
  ),
  _component(
    name: 'RouteFrame',
    path: 'Frames/Desktop',
    docs: 'Catalog-only route review frame used to bound canonical Pages.',
    stories: [const _StorySpec('Route surface', routeFrameUseCase)],
  ),

  // Pages — Mobile viewport (compact phone layout). Same app-owned Pages as the
  // Desktop group; only the rendered viewport width differs.
  _component(
    name: 'WelcomePage',
    path: 'Pages/Mobile',
    docs: 'Canonical unauthenticated landing Page in the mobile auth frame.',
    stories: const [_StorySpec('Default', welcomePageMobileUseCase)],
  ),
  _component(
    name: 'LoginPage',
    path: 'Pages/Mobile',
    docs: 'Canonical app-owned login route Page in the mobile auth frame.',
    stories: const [
      _StorySpec('Default', loginPageMobileUseCase),
      _StorySpec('Invalid credentials', loginPageInvalidMobileUseCase),
      _StorySpec('Loading', loginPageLoadingMobileUseCase),
    ],
  ),
  _component(
    name: 'SignupPage',
    path: 'Pages/Mobile',
    docs: 'Canonical app-owned signup route Page in the mobile auth frame.',
    stories: const [
      _StorySpec('Default', signupPageMobileUseCase),
      _StorySpec('Email taken', signupPageEmailTakenMobileUseCase),
      _StorySpec('Loading', signupPageLoadingMobileUseCase),
    ],
  ),
  _component(
    name: 'ForgotPasswordPage',
    path: 'Pages/Mobile',
    docs: 'Canonical password-reset request route Page (mobile).',
    stories: const [
      _StorySpec('Default', forgotPasswordPageMobileUseCase),
    ],
  ),
  _component(
    name: 'ResetPasswordPage',
    path: 'Pages/Mobile',
    docs: 'Canonical reset-code + new-password route Page (mobile).',
    stories: const [
      _StorySpec('Default', resetPasswordPageMobileUseCase),
    ],
  ),
  _component(
    name: 'InboxPage',
    path: 'Pages/Mobile',
    docs: 'Canonical home/inbox route Page in compact mobile layout.',
    stories: const [
      _StorySpec('Empty', inboxPageMobileUseCase),
      _StorySpec('Populated', inboxPagePopulatedMobileUseCase),
      _StorySpec('Loading', inboxPageLoadingMobileUseCase),
    ],
  ),
  _component(
    name: 'MatomeDetailPage',
    path: 'Pages/Mobile',
    docs: 'Canonical Matome detail route Page in compact mobile layout.',
    stories: const [
      _StorySpec('Not found', matomeDetailPageMobileUseCase),
      _StorySpec('Loaded', matomeDetailLoadedMobileUseCase),
    ],
  ),
  _component(
    name: 'FilesPage',
    path: 'Pages/Mobile',
    docs:
        'Canonical files route Page with seeded rows in compact mobile layout.',
    stories: const [
      _StorySpec('Loaded', filesPageMobileUseCase),
      _StorySpec('Empty', filesPageEmptyMobileUseCase),
      _StorySpec('Loading', filesPageLoadingMobileUseCase),
      _StorySpec('Error', filesPageErrorMobileUseCase),
    ],
  ),
  _component(
    name: 'RecordingPage',
    path: 'Pages/Mobile',
    docs:
        'Canonical recording route Page with Widgetbook-safe recorder binding (mobile).',
    stories: const [_StorySpec('Mic unsupported', recordingPageMobileUseCase)],
  ),
  _component(
    name: 'MeetingRecordingPage',
    path: 'Pages/Mobile',
    docs:
        'Canonical meeting recording route Page with Widgetbook-safe recorder binding (mobile).',
    stories: const [
      _StorySpec('Meeting unsupported', meetingRecordingPageMobileUseCase),
    ],
  ),
  _component(
    name: 'FileDetailPage',
    path: 'Pages/Mobile',
    docs:
        'Canonical recording detail route Page variants for audio, image, and document items (mobile).',
    stories: const [
      _StorySpec('Audio route', fileDetailPageAudioMobileUseCase),
      _StorySpec('Document route', fileDetailPageDocumentMobileUseCase),
      _StorySpec('Image route', fileDetailPageImageMobileUseCase),
    ],
  ),
  _component(
    name: 'CalendarPage',
    path: 'Pages/Mobile',
    docs: 'Canonical calendar route Page in compact mobile layout.',
    stories: const [_StorySpec('Empty', calendarPageMobileUseCase)],
  ),
  _component(
    name: 'ContactsPage',
    path: 'Pages/Mobile',
    docs: 'Canonical contacts route Page in compact mobile layout.',
    stories: const [_StorySpec('Empty', contactsPageMobileUseCase)],
  ),
  _component(
    name: 'ContactDetailPage',
    path: 'Pages/Mobile',
    docs: 'Canonical contact detail route Page in compact mobile layout.',
    stories: const [_StorySpec('Not found', contactDetailPageMobileUseCase)],
  ),
  _component(
    name: 'SpacesPage',
    path: 'Pages/Mobile',
    docs: 'Canonical spaces route Page in compact mobile layout.',
    stories: const [_StorySpec('Empty', spacesPageMobileUseCase)],
  ),
  _component(
    name: 'SpaceDetailPage',
    path: 'Pages/Mobile',
    docs: 'Canonical space detail route Page in compact mobile layout.',
    stories: const [_StorySpec('Not found', spaceDetailPageMobileUseCase)],
  ),
  _component(
    name: 'SettingsPage',
    path: 'Pages/Mobile',
    docs: 'Canonical settings route Page in compact mobile layout.',
    stories: const [_StorySpec('Default', settingsPageMobileUseCase)],
  ),

  // Pages — Desktop viewport (expanded master-detail layout). Same app-owned
  // Pages as the Mobile group; only the rendered viewport width differs.
  _component(
    name: 'WelcomePage',
    path: 'Pages/Desktop',
    docs: 'Canonical unauthenticated landing Page in the desktop auth frame.',
    stories: const [_StorySpec('Default', welcomePageDesktopUseCase)],
  ),
  _component(
    name: 'LoginPage',
    path: 'Pages/Desktop',
    docs: 'Canonical app-owned login route Page in the desktop auth frame.',
    stories: const [
      _StorySpec('Default', loginPageDesktopUseCase),
      _StorySpec('Invalid credentials', loginPageInvalidDesktopUseCase),
      _StorySpec('Loading', loginPageLoadingDesktopUseCase),
    ],
  ),
  _component(
    name: 'SignupPage',
    path: 'Pages/Desktop',
    docs: 'Canonical app-owned signup route Page in the desktop auth frame.',
    stories: const [
      _StorySpec('Default', signupPageDesktopUseCase),
      _StorySpec('Email taken', signupPageEmailTakenDesktopUseCase),
      _StorySpec('Loading', signupPageLoadingDesktopUseCase),
    ],
  ),
  _component(
    name: 'ForgotPasswordPage',
    path: 'Pages/Desktop',
    docs: 'Canonical password-reset request route Page (desktop).',
    stories: const [
      _StorySpec('Default', forgotPasswordPageDesktopUseCase),
    ],
  ),
  _component(
    name: 'ResetPasswordPage',
    path: 'Pages/Desktop',
    docs: 'Canonical reset-code + new-password route Page (desktop).',
    stories: const [
      _StorySpec('Default', resetPasswordPageDesktopUseCase),
    ],
  ),
  _component(
    name: 'InboxPage',
    path: 'Pages/Desktop',
    docs: 'Canonical home/inbox route Page in expanded desktop layout.',
    stories: const [
      _StorySpec('Empty', inboxPageDesktopUseCase),
      _StorySpec('Populated', inboxPagePopulatedDesktopUseCase),
      _StorySpec('Loading', inboxPageLoadingDesktopUseCase),
    ],
  ),
  _component(
    name: 'MatomeDetailPage',
    path: 'Pages/Desktop',
    docs: 'Canonical Matome detail route Page in expanded desktop layout.',
    stories: const [
      _StorySpec('Not found', matomeDetailPageDesktopUseCase),
      _StorySpec('Loaded', matomeDetailLoadedDesktopUseCase),
    ],
  ),
  _component(
    name: 'FilesPage',
    path: 'Pages/Desktop',
    docs:
        'Canonical files route Page with seeded rows in expanded desktop layout.',
    stories: const [
      _StorySpec('Loaded', filesPageDesktopUseCase),
      _StorySpec('Empty', filesPageEmptyDesktopUseCase),
      _StorySpec('Loading', filesPageLoadingDesktopUseCase),
      _StorySpec('Error', filesPageErrorDesktopUseCase),
    ],
  ),
  _component(
    name: 'RecordingPage',
    path: 'Pages/Desktop',
    docs:
        'Canonical recording route Page with Widgetbook-safe recorder binding (desktop).',
    stories: const [_StorySpec('Mic unsupported', recordingPageDesktopUseCase)],
  ),
  _component(
    name: 'MeetingRecordingPage',
    path: 'Pages/Desktop',
    docs:
        'Canonical meeting recording route Page with Widgetbook-safe recorder binding (desktop).',
    stories: const [
      _StorySpec('Meeting unsupported', meetingRecordingPageDesktopUseCase),
    ],
  ),
  _component(
    name: 'FileDetailPage',
    path: 'Pages/Desktop',
    docs:
        'Canonical recording detail route Page variants for audio, image, and document items (desktop).',
    stories: const [
      _StorySpec('Audio route', fileDetailPageAudioDesktopUseCase),
      _StorySpec('Document route', fileDetailPageDocumentDesktopUseCase),
      _StorySpec('Image route', fileDetailPageImageDesktopUseCase),
    ],
  ),
  _component(
    name: 'CalendarPage',
    path: 'Pages/Desktop',
    docs: 'Canonical calendar route Page in expanded desktop layout.',
    stories: const [_StorySpec('Empty', calendarPageDesktopUseCase)],
  ),
  _component(
    name: 'ContactsPage',
    path: 'Pages/Desktop',
    docs: 'Canonical contacts route Page in expanded desktop layout.',
    stories: const [_StorySpec('Empty', contactsPageDesktopUseCase)],
  ),
  _component(
    name: 'ContactDetailPage',
    path: 'Pages/Desktop',
    docs: 'Canonical contact detail route Page in expanded desktop layout.',
    stories: const [_StorySpec('Not found', contactDetailPageDesktopUseCase)],
  ),
  _component(
    name: 'SpacesPage',
    path: 'Pages/Desktop',
    docs: 'Canonical spaces route Page in expanded desktop layout.',
    stories: const [_StorySpec('Empty', spacesPageDesktopUseCase)],
  ),
  _component(
    name: 'SpaceDetailPage',
    path: 'Pages/Desktop',
    docs: 'Canonical space detail route Page in expanded desktop layout.',
    stories: const [_StorySpec('Not found', spaceDetailPageDesktopUseCase)],
  ),
  _component(
    name: 'SettingsPage',
    path: 'Pages/Desktop',
    docs: 'Canonical settings route Page in expanded desktop layout.',
    stories: const [_StorySpec('Default', settingsPageDesktopUseCase)],
  ),

  _component(
    name: 'Auth',
    path: 'Journeys/Mobile',
    docs:
        'Journey order: 01 WelcomePage -> 02 LoginPage -> 03 SignupPage. Mobile auth documents the unauthenticated entry flow in phone layout.',
    stories: const [
      _StorySpec('01 WelcomePage', authJourneyWelcomeStepUseCase),
      _StorySpec('02 LoginPage', authJourneyLoginStepUseCase),
      _StorySpec('03 SignupPage', authJourneySignupStepUseCase),
    ],
  ),
  _component(
    name: 'Capture',
    path: 'Journeys/Mobile',
    docs:
        'Journey order: 01 RecordingPage -> 02 InboxPage -> 03 MatomeDetailPage. Mobile capture follows a new recording into inbox triage and the resulting Matome hub.',
    stories: const [
      _StorySpec('01 RecordingPage', captureJourneyCaptureStepUseCase),
      _StorySpec('02 InboxPage', captureJourneyInboxStepUseCase),
      _StorySpec('03 MatomeDetailPage', captureJourneyMatomeStepUseCase),
    ],
  ),
  _component(
    name: 'Organize',
    path: 'Journeys/Mobile',
    docs:
        'Journey order: 01 InboxPage -> 02 MatomeDetailPage -> 03 SpaceDetailPage. Mobile organize documents filing a happening into its destination space.',
    stories: const [
      _StorySpec('01 InboxPage', organizeJourneyInboxStepUseCase),
      _StorySpec('02 MatomeDetailPage', organizeJourneyMatomeStepUseCase),
      _StorySpec('03 SpaceDetailPage', organizeJourneySpaceStepUseCase),
    ],
  ),
  _component(
    name: 'Review',
    path: 'Journeys/Mobile',
    docs:
        'Journey order: 01 FilesPage -> 02 FileDetailPage. Mobile review documents opening the files library and inspecting an audio detail.',
    stories: const [
      _StorySpec('01 FilesPage', reviewJourneyFilesStepUseCase),
      _StorySpec('02 FileDetailPage', reviewJourneyAudioStepUseCase),
    ],
  ),
  _component(
    name: 'Recovery',
    path: 'Journeys/Mobile',
    docs:
        'Journey order: 01 SettingsPage -> 02 InboxPage -> 03 FilesPage. Mobile recovery documents settings defaults, retry queue review, and returning to files.',
    stories: const [
      _StorySpec('01 SettingsPage', recoveryJourneySettingsStepUseCase),
      _StorySpec('02 InboxPage', recoveryJourneyInboxStepUseCase),
      _StorySpec('03 FilesPage', recoveryJourneyFilesStepUseCase),
    ],
  ),
  _component(
    name: 'Auth',
    path: 'Journeys/Desktop',
    docs:
        'Journey order: 01 WelcomePage -> 02 LoginPage -> 03 SignupPage. Desktop auth documents the unauthenticated entry flow in wide layout.',
    stories: const [
      _StorySpec('01 WelcomePage', authJourneyWelcomeDesktopStepUseCase),
      _StorySpec('02 LoginPage', authJourneyLoginDesktopStepUseCase),
      _StorySpec('03 SignupPage', authJourneySignupDesktopStepUseCase),
    ],
  ),
  _component(
    name: 'Capture',
    path: 'Journeys/Desktop',
    docs:
        'Journey order: 01 RecordingPage -> 02 InboxPage -> 03 MatomeDetailPage. Desktop capture follows a new recording into inbox triage and the resulting Matome hub.',
    stories: const [
      _StorySpec('01 RecordingPage', captureJourneyCaptureDesktopStepUseCase),
      _StorySpec('02 InboxPage', captureJourneyInboxDesktopStepUseCase),
      _StorySpec('03 MatomeDetailPage', captureJourneyMatomeDesktopStepUseCase),
    ],
  ),
  _component(
    name: 'Organize',
    path: 'Journeys/Desktop',
    docs:
        'Journey order: 01 InboxPage -> 02 MatomeDetailPage -> 03 SpaceDetailPage. Desktop organize documents filing a happening into its destination space.',
    stories: const [
      _StorySpec('01 InboxPage', organizeJourneyInboxDesktopStepUseCase),
      _StorySpec(
        '02 MatomeDetailPage',
        organizeJourneyMatomeDesktopStepUseCase,
      ),
      _StorySpec('03 SpaceDetailPage', organizeJourneySpaceDesktopStepUseCase),
    ],
  ),
  _component(
    name: 'Review',
    path: 'Journeys/Desktop',
    docs:
        'Journey order: 01 FilesPage -> 02 FileDetailPage. Desktop review documents opening the files library and inspecting an audio detail.',
    stories: const [
      _StorySpec('01 FilesPage', reviewJourneyFilesDesktopStepUseCase),
      _StorySpec('02 FileDetailPage', reviewJourneyAudioDesktopStepUseCase),
    ],
  ),
  _component(
    name: 'Recovery',
    path: 'Journeys/Desktop',
    docs:
        'Journey order: 01 SettingsPage -> 02 InboxPage -> 03 FilesPage. Desktop recovery documents settings defaults, retry queue review, and returning to files.',
    stories: const [
      _StorySpec('01 SettingsPage', recoveryJourneySettingsDesktopStepUseCase),
      _StorySpec('02 InboxPage', recoveryJourneyInboxDesktopStepUseCase),
      _StorySpec('03 FilesPage', recoveryJourneyFilesDesktopStepUseCase),
    ],
  ),

  // Screens — Mobile viewport (compact width). Same app-owned screen bodies as
  // the Desktop group; the surface width drives the responsive layout.
  _component(
    name: 'AuthScaffold',
    path: 'Screens/Mobile',
    docs: 'Auth screen scaffold with form column and back affordance (mobile).',
    stories: [
      _mobileScreen('Scaffold (form column + back)', authScaffoldUseCase),
    ],
  ),
  _component(
    name: 'ContactDetail',
    path: 'Screens/Mobile',
    docs: 'Contact detail screen body in mobile width across data states.',
    stories: [
      _mobileScreen('Detail - desktop', contactDetailDesktopUseCase),
      _mobileScreen('Detail - mobile', contactDetailMobileUseCase),
      _mobileScreen('Detail - sparse (minimal info)', contactDetailSparseUseCase),
    ],
  ),
  _component(
    name: 'ContactTile',
    path: 'Screens/Mobile',
    docs: 'Contact tile row used by contact lists (mobile).',
    stories: [_mobileScreen('Default', contactTileUseCase)],
  ),
  _component(
    name: 'FileView',
    path: 'Screens/Mobile',
    docs: 'File view body states for audio, image, and notes content (mobile).',
    stories: [
      _mobileScreen('Audio - empty', fileViewAudioEmptyUseCase),
      _mobileScreen('Audio - failed', fileViewAudioFailedUseCase),
      _mobileScreen('Audio - processing', fileViewAudioProcessingUseCase),
      _mobileScreen('Audio - ready (transcript)', fileViewAudioReadyUseCase),
      _mobileScreen('Image - empty', fileViewImageEmptyUseCase),
      _mobileScreen('Image - ready (description)', fileViewImageReadyUseCase),
      _mobileScreen('Notes - empty', fileViewNotesEmptyUseCase),
      _mobileScreen('Notes - filled', fileViewNotesFilledUseCase),
    ],
  ),
  _component(
    name: 'FilesGrid',
    path: 'Screens/Mobile',
    docs: 'Files grid screen body at compact mobile width.',
    stories: [
      _mobileScreen('Grid - desktop', filesGridDesktopUseCase),
      _mobileScreen('Grid - mobile', filesGridMobileUseCase),
    ],
  ),
  _component(
    name: 'FilesScreen',
    path: 'Screens/Mobile',
    docs: 'Files screen states backed by provider fixtures (mobile).',
    stories: [
      _mobileScreen('Empty', filesScreenEmptyUseCase),
      _mobileScreen('Error', filesScreenErrorUseCase),
      _mobileScreen('Loaded', filesScreenLoadedUseCase),
      _mobileScreen('Loading', filesScreenLoadingUseCase),
    ],
  ),
  _component(
    name: 'FilesTable',
    path: 'Screens/Mobile',
    docs: 'Files table screen body at compact mobile width.',
    stories: [
      _mobileScreen('Table - desktop', filesTableDesktopUseCase),
      _mobileScreen('Table - mobile (compact)', filesTableMobileUseCase),
    ],
  ),
  _component(
    name: 'FilesScopeFilter',
    path: 'Screens/Mobile',
    docs: 'Local-first files scope filter and its page-level scene (mobile).',
    stories: [
      _mobileScreen(
        'Files scope filter (All / Loose / In a space)',
        filesScopeFilterUseCase,
      ),
      _mobileScreen('Scene - Files (scope filter)', sceneFilesUseCase),
    ],
  ),
  _component(
    name: 'InboxItemCard',
    path: 'Screens/Mobile',
    docs: 'Local-first inbox entry card and inbox scene (mobile).',
    stories: [
      _mobileScreen('Inbox entry (loose item / draft matome)', inboxItemCardUseCase),
      _mobileScreen('Scene - Inbox (loose items + draft matomes)', sceneInboxUseCase),
    ],
  ),
  _component(
    name: 'SpaceSyncChip',
    path: 'Screens/Mobile',
    docs: 'Local/cloud sync chip and promote-to-cloud consent scene (mobile).',
    stories: [
      _mobileScreen('Scene - Promote to cloud consent', scenePromoteConsentUseCase),
      _mobileScreen('Sync chip (local / promoting / cloud)', spaceSyncChipUseCase),
    ],
  ),
  _component(
    name: 'SpaceSyncChoice',
    path: 'Screens/Mobile',
    docs: 'New-space sync choice and sheet scene (mobile).',
    stories: [
      _mobileScreen('Create sync choice (local default)', spaceSyncChoiceUseCase),
      _mobileScreen('Scene - New space sheet (local default)', sceneNewSpaceSheetUseCase),
    ],
  ),
  _component(
    name: 'SpaceSyncTile',
    path: 'Screens/Mobile',
    docs: 'Local/cloud space tile and spaces scene (mobile).',
    stories: [
      _mobileScreen('Scene - Spaces (local / cloud + promote)', sceneSpacesUseCase),
      _mobileScreen('Space tile (local + promote / cloud)', spaceSyncTileUseCase),
    ],
  ),
  _component(
    name: 'MasterDetailScaffold',
    path: 'Screens/Mobile',
    docs: 'Responsive master-detail scaffold modes (mobile).',
    stories: [
      _mobileScreen('Always (split pane)', masterDetailScaffoldUseCase),
      _mobileScreen(
        'On click (split appears once selected)',
        masterDetailScaffoldOnClickUseCase,
      ),
    ],
  ),
  _component(
    name: 'MatomeDetailPanel',
    path: 'Screens/Mobile',
    docs: 'Complete Matome detail side panel in filed and inbox states (mobile).',
    stories: [
      _mobileScreen('Detail panel - filed', detailPanelFiledUseCase),
      _mobileScreen('Detail panel - inbox', detailPanelInboxUseCase),
    ],
  ),
  _component(
    name: 'MatomeTable',
    path: 'Screens/Mobile',
    docs: 'Matome table states at compact mobile width.',
    stories: [
      _mobileScreen('Table - compact (mobile)', matomeTableCompactUseCase),
      _mobileScreen('Table - desktop (sortable)', matomeTableDesktopUseCase),
      _mobileScreen('Table - empty', matomeTableEmptyUseCase),
      _mobileScreen('Table - selection + bulk bar', matomeTableSelectionUseCase),
    ],
  ),
  _component(
    name: 'MatomeBottomDock',
    path: 'Screens/Mobile',
    docs: 'Mobile bottom dock in isolation and in phone context.',
    stories: [
      _mobileScreen('Mobile dock - bare', mobileDockBareUseCase),
      _mobileScreen('Mobile dock - in context', mobileDockInContextUseCase),
    ],
  ),
  _component(
    name: 'MatomeSidebar',
    path: 'Screens/Mobile',
    docs: 'Desktop sidebar expanded and collapsed states (mobile width).',
    stories: [
      _mobileScreen('Desktop sidebar - collapsed (rail)', desktopSidebarCollapsedUseCase),
      _mobileScreen('Desktop sidebar - expanded', desktopSidebarExpandedUseCase),
    ],
  ),
  _component(
    name: 'RelationshipPicker',
    path: 'Screens/Mobile',
    docs:
        'Relationship picker overlay variants for files, people, matomes, spaces, filters, and empty states (mobile).',
    stories: [
      _mobileScreen('Add anything (mixed / type filter)', relationshipPickerMixedUseCase),
      _mobileScreen('Add files (multi / search)', relationshipPickerFilesUseCase),
      _mobileScreen('Add people (multi / search)', relationshipPickerPeopleUseCase),
      _mobileScreen('Add to a matome (Files page / reuse)', relationshipPickerMatomeUseCase),
      _mobileScreen('Empty (no candidates yet)', relationshipPickerEmptyUseCase),
      _mobileScreen('File into a space (single)', relationshipPickerSpaceUseCase),
      _mobileScreen('Pre-filtered (opened from Add person)', relationshipPickerPrefilteredUseCase),
    ],
  ),

  // Screens — Desktop viewport (expanded width). Same app-owned screen bodies as
  // the Mobile group; the surface width drives the responsive layout.
  _component(
    name: 'AuthScaffold',
    path: 'Screens/Desktop',
    docs: 'Auth screen scaffold with form column and back affordance (desktop).',
    stories: [
      _desktopScreen('Scaffold (form column + back)', authScaffoldUseCase),
    ],
  ),
  _component(
    name: 'ContactDetail',
    path: 'Screens/Desktop',
    docs: 'Contact detail screen body in desktop width across data states.',
    stories: [
      _desktopScreen('Detail - desktop', contactDetailDesktopUseCase),
      _desktopScreen('Detail - mobile', contactDetailMobileUseCase),
      _desktopScreen('Detail - sparse (minimal info)', contactDetailSparseUseCase),
    ],
  ),
  _component(
    name: 'ContactTile',
    path: 'Screens/Desktop',
    docs: 'Contact tile row used by contact lists (desktop).',
    stories: [_desktopScreen('Default', contactTileUseCase)],
  ),
  _component(
    name: 'FileView',
    path: 'Screens/Desktop',
    docs: 'File view body states for audio, image, and notes content (desktop).',
    stories: [
      _desktopScreen('Audio - empty', fileViewAudioEmptyUseCase),
      _desktopScreen('Audio - failed', fileViewAudioFailedUseCase),
      _desktopScreen('Audio - processing', fileViewAudioProcessingUseCase),
      _desktopScreen('Audio - ready (transcript)', fileViewAudioReadyUseCase),
      _desktopScreen('Image - empty', fileViewImageEmptyUseCase),
      _desktopScreen('Image - ready (description)', fileViewImageReadyUseCase),
      _desktopScreen('Notes - empty', fileViewNotesEmptyUseCase),
      _desktopScreen('Notes - filled', fileViewNotesFilledUseCase),
    ],
  ),
  _component(
    name: 'FilesGrid',
    path: 'Screens/Desktop',
    docs: 'Files grid screen body at expanded desktop width.',
    stories: [
      _desktopScreen('Grid - desktop', filesGridDesktopUseCase),
      _desktopScreen('Grid - mobile', filesGridMobileUseCase),
    ],
  ),
  _component(
    name: 'FilesScreen',
    path: 'Screens/Desktop',
    docs: 'Files screen states backed by provider fixtures (desktop).',
    stories: [
      _desktopScreen('Empty', filesScreenEmptyUseCase),
      _desktopScreen('Error', filesScreenErrorUseCase),
      _desktopScreen('Loaded', filesScreenLoadedUseCase),
      _desktopScreen('Loading', filesScreenLoadingUseCase),
    ],
  ),
  _component(
    name: 'FilesTable',
    path: 'Screens/Desktop',
    docs: 'Files table screen body at expanded desktop width.',
    stories: [
      _desktopScreen('Table - desktop', filesTableDesktopUseCase),
      _desktopScreen('Table - mobile (compact)', filesTableMobileUseCase),
    ],
  ),
  _component(
    name: 'FilesScopeFilter',
    path: 'Screens/Desktop',
    docs: 'Local-first files scope filter and its page-level scene (desktop).',
    stories: [
      _desktopScreen(
        'Files scope filter (All / Loose / In a space)',
        filesScopeFilterUseCase,
      ),
      _desktopScreen('Scene - Files (scope filter)', sceneFilesUseCase),
    ],
  ),
  _component(
    name: 'InboxItemCard',
    path: 'Screens/Desktop',
    docs: 'Local-first inbox entry card and inbox scene (desktop).',
    stories: [
      _desktopScreen('Inbox entry (loose item / draft matome)', inboxItemCardUseCase),
      _desktopScreen('Scene - Inbox (loose items + draft matomes)', sceneInboxUseCase),
    ],
  ),
  _component(
    name: 'SpaceSyncChip',
    path: 'Screens/Desktop',
    docs: 'Local/cloud sync chip and promote-to-cloud consent scene (desktop).',
    stories: [
      _desktopScreen('Scene - Promote to cloud consent', scenePromoteConsentUseCase),
      _desktopScreen('Sync chip (local / promoting / cloud)', spaceSyncChipUseCase),
    ],
  ),
  _component(
    name: 'SpaceSyncChoice',
    path: 'Screens/Desktop',
    docs: 'New-space sync choice and sheet scene (desktop).',
    stories: [
      _desktopScreen('Create sync choice (local default)', spaceSyncChoiceUseCase),
      _desktopScreen('Scene - New space sheet (local default)', sceneNewSpaceSheetUseCase),
    ],
  ),
  _component(
    name: 'SpaceSyncTile',
    path: 'Screens/Desktop',
    docs: 'Local/cloud space tile and spaces scene (desktop).',
    stories: [
      _desktopScreen('Scene - Spaces (local / cloud + promote)', sceneSpacesUseCase),
      _desktopScreen('Space tile (local + promote / cloud)', spaceSyncTileUseCase),
    ],
  ),
  _component(
    name: 'MasterDetailScaffold',
    path: 'Screens/Desktop',
    docs: 'Responsive master-detail scaffold modes (desktop).',
    stories: [
      _desktopScreen('Always (split pane)', masterDetailScaffoldUseCase),
      _desktopScreen(
        'On click (split appears once selected)',
        masterDetailScaffoldOnClickUseCase,
      ),
    ],
  ),
  _component(
    name: 'MatomeDetailPanel',
    path: 'Screens/Desktop',
    docs: 'Complete Matome detail side panel in filed and inbox states (desktop).',
    stories: [
      _desktopScreen('Detail panel - filed', detailPanelFiledUseCase),
      _desktopScreen('Detail panel - inbox', detailPanelInboxUseCase),
    ],
  ),
  _component(
    name: 'MatomeTable',
    path: 'Screens/Desktop',
    docs: 'Matome table states at expanded desktop width.',
    stories: [
      _desktopScreen('Table - compact (mobile)', matomeTableCompactUseCase),
      _desktopScreen('Table - desktop (sortable)', matomeTableDesktopUseCase),
      _desktopScreen('Table - empty', matomeTableEmptyUseCase),
      _desktopScreen('Table - selection + bulk bar', matomeTableSelectionUseCase),
    ],
  ),
  _component(
    name: 'MatomeBottomDock',
    path: 'Screens/Desktop',
    docs: 'Mobile bottom dock in isolation and in phone context (desktop width).',
    stories: [
      _desktopScreen('Mobile dock - bare', mobileDockBareUseCase),
      _desktopScreen('Mobile dock - in context', mobileDockInContextUseCase),
    ],
  ),
  _component(
    name: 'MatomeSidebar',
    path: 'Screens/Desktop',
    docs: 'Desktop sidebar expanded and collapsed states (desktop).',
    stories: [
      _desktopScreen('Desktop sidebar - collapsed (rail)', desktopSidebarCollapsedUseCase),
      _desktopScreen('Desktop sidebar - expanded', desktopSidebarExpandedUseCase),
    ],
  ),
  _component(
    name: 'RelationshipPicker',
    path: 'Screens/Desktop',
    docs:
        'Relationship picker overlay variants for files, people, matomes, spaces, filters, and empty states (desktop).',
    stories: [
      _desktopScreen('Add anything (mixed / type filter)', relationshipPickerMixedUseCase),
      _desktopScreen('Add files (multi / search)', relationshipPickerFilesUseCase),
      _desktopScreen('Add people (multi / search)', relationshipPickerPeopleUseCase),
      _desktopScreen('Add to a matome (Files page / reuse)', relationshipPickerMatomeUseCase),
      _desktopScreen('Empty (no candidates yet)', relationshipPickerEmptyUseCase),
      _desktopScreen('File into a space (single)', relationshipPickerSpaceUseCase),
      _desktopScreen('Pre-filtered (opened from Add person)', relationshipPickerPrefilteredUseCase),
    ],
  ),
];

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

Widget welcomePageMobileUseCase(BuildContext context) {
  return _authPageScene(const WelcomePage(), viewport: _AuthViewport.mobile);
}

Widget welcomePageDesktopUseCase(BuildContext context) {
  return _authPageScene(const WelcomePage(), viewport: _AuthViewport.desktop);
}

Widget loginPageMobileUseCase(BuildContext context) {
  return _authPageScene(const LoginPage(), viewport: _AuthViewport.mobile);
}

Widget loginPageDesktopUseCase(BuildContext context) {
  return _authPageScene(const LoginPage(), viewport: _AuthViewport.desktop);
}

Widget signupPageMobileUseCase(BuildContext context) {
  return _authPageScene(const SignupPage(), viewport: _AuthViewport.mobile);
}

Widget signupPageDesktopUseCase(BuildContext context) {
  return _authPageScene(const SignupPage(), viewport: _AuthViewport.desktop);
}

Widget forgotPasswordPageMobileUseCase(BuildContext context) =>
    _authPageScene(const ForgotPasswordPage(), viewport: _AuthViewport.mobile);

Widget forgotPasswordPageDesktopUseCase(BuildContext context) =>
    _authPageScene(const ForgotPasswordPage(), viewport: _AuthViewport.desktop);

Widget resetPasswordPageMobileUseCase(BuildContext context) =>
    _authPageScene(const ResetPasswordPage(), viewport: _AuthViewport.mobile);

Widget resetPasswordPageDesktopUseCase(BuildContext context) =>
    _authPageScene(const ResetPasswordPage(), viewport: _AuthViewport.desktop);

// Auth state fixtures for the login/signup error and loading Page variants.
final _authInvalidCredentials = AsyncValue<AuthSession?>.error(
  const ApiException('Invalid credentials', statusCode: 401),
  StackTrace.empty,
);
final _authEmailTaken = AsyncValue<AuthSession?>.error(
  const ApiException('Email already registered', statusCode: 409),
  StackTrace.empty,
);
const _authLoading = AsyncValue<AuthSession?>.loading();

Widget loginPageInvalidMobileUseCase(BuildContext context) => _authPageScene(
  const LoginPage(),
  viewport: _AuthViewport.mobile,
  authState: _authInvalidCredentials,
);

Widget loginPageInvalidDesktopUseCase(BuildContext context) => _authPageScene(
  const LoginPage(),
  viewport: _AuthViewport.desktop,
  authState: _authInvalidCredentials,
);

Widget loginPageLoadingMobileUseCase(BuildContext context) => _authPageScene(
  const LoginPage(),
  viewport: _AuthViewport.mobile,
  authState: _authLoading,
);

Widget loginPageLoadingDesktopUseCase(BuildContext context) => _authPageScene(
  const LoginPage(),
  viewport: _AuthViewport.desktop,
  authState: _authLoading,
);

Widget signupPageEmailTakenMobileUseCase(BuildContext context) =>
    _authPageScene(
      const SignupPage(),
      viewport: _AuthViewport.mobile,
      authState: _authEmailTaken,
    );

Widget signupPageEmailTakenDesktopUseCase(BuildContext context) =>
    _authPageScene(
      const SignupPage(),
      viewport: _AuthViewport.desktop,
      authState: _authEmailTaken,
    );

Widget signupPageLoadingMobileUseCase(BuildContext context) => _authPageScene(
  const SignupPage(),
  viewport: _AuthViewport.mobile,
  authState: _authLoading,
);

Widget signupPageLoadingDesktopUseCase(BuildContext context) => _authPageScene(
  const SignupPage(),
  viewport: _AuthViewport.desktop,
  authState: _authLoading,
);

Widget authJourneyUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 1160, child: _AuthFlowScene());
}

Widget captureJourneyUseCase(BuildContext context) {
  return _PageFlowScene(
    width: 1440,
    steps: [
      _PageFlowStepSpec(
        title: '1. Capture',
        route: '/recording',
        note: 'Real RecordingPage with the Widgetbook-safe recorder binding.',
        width: 390,
        height: 760,
        child: ProviderScope(
          child: RecordingPage(binding: _widgetbookMicRecorderBinding),
        ),
      ),
      _PageFlowStepSpec(
        title: '2. Inbox triage',
        route: '/inbox',
        note:
            'Seeded inbox controllers show the captured happening waiting to file.',
        width: 390,
        height: 760,
        child: _inboxPageScene(
          matomes: _journeyInboxMatomes,
          inboxItems: _journeyLooseInboxItems,
          looseItems: _journeyLooseInboxItems,
        ),
      ),
      _PageFlowStepSpec(
        title: '3. Matome hub',
        route: '/matome/:id',
        note: 'Seeded MatomeDetailPage keeps the route target real.',
        width: 680,
        height: 760,
        child: _matomeDetailPageScene(_journeyMatome.id),
      ),
    ],
  );
}

Widget organizeJourneyUseCase(BuildContext context) {
  return _PageFlowScene(
    width: 1680,
    steps: [
      _PageFlowStepSpec(
        title: '1. Choose happening',
        route: '/inbox',
        note: 'The inbox is seeded with one Matome and one loose recording.',
        width: 430,
        height: 760,
        child: _inboxPageScene(
          matomes: _journeyInboxMatomes,
          inboxItems: _journeyLooseInboxItems,
          looseItems: _journeyLooseInboxItems,
        ),
      ),
      _PageFlowStepSpec(
        title: '2. Review Matome',
        route: '/matome/:id',
        note:
            'The app Page renders its real summary, files, notes, and filing CTA.',
        width: 680,
        height: 760,
        child: _matomeDetailPageScene(_journeyMatome.id),
      ),
      _PageFlowStepSpec(
        title: '3. Filed Space',
        route: '/spaces/:spaceId',
        note: 'SpaceDetailPage stays the canonical post-filing destination.',
        width: 430,
        height: 760,
        child: _spaceDetailPageScene('widgetbook-space-work'),
      ),
    ],
  );
}

Widget reviewJourneyUseCase(BuildContext context) {
  return _PageFlowScene(
    width: 1500,
    steps: [
      _PageFlowStepSpec(
        title: '1. Files library',
        route: '/files',
        note: 'FilesPage uses explicit sample rows from the catalog fixture.',
        width: 760,
        height: 760,
        child: _filesPageScene(
          filesForCurrentOwnerProvider.overrideWith(
            (ref) async => _filesSample,
          ),
        ),
      ),
      _PageFlowStepSpec(
        title: '2. Audio review',
        route: '/recording/detail/:id',
        note:
            'FileDetailPage.audio is seeded through its app DetailsController.',
        width: 560,
        height: 760,
        child: _fileDetailPageScene(_journeyAudioRow.id),
      ),
    ],
  );
}

Widget recoveryJourneyUseCase(BuildContext context) {
  return _PageFlowScene(
    width: 1420,
    steps: [
      _PageFlowStepSpec(
        title: '1. Defaults',
        route: '/inbox/settings',
        note:
            'SettingsPage is the real default-view and account control surface.',
        width: 430,
        height: 760,
        child: _settingsPageScene(),
      ),
      _PageFlowStepSpec(
        title: '2. Retry queue',
        route: '/inbox',
        note: 'InboxPage shows an explicit failed local item fixture.',
        width: 390,
        height: 760,
        child: _inboxPageScene(
          matomes: _journeyInboxMatomes,
          inboxItems: _journeyLooseInboxItems,
          looseItems: _journeyLooseInboxItems,
        ),
      ),
      _PageFlowStepSpec(
        title: '3. Back to files',
        route: '/files',
        note:
            'FilesPage confirms the same canonical review surface after recovery.',
        width: 520,
        height: 760,
        child: _filesPageScene(
          filesForCurrentOwnerProvider.overrideWith(
            (ref) async => _filesSample,
          ),
        ),
      ),
    ],
  );
}

Widget authJourneyWelcomeStepUseCase(BuildContext context) {
  return _authPageScene(const WelcomePage(), viewport: _AuthViewport.mobile);
}

Widget authJourneyLoginStepUseCase(BuildContext context) {
  return _authPageScene(const LoginPage(), viewport: _AuthViewport.mobile);
}

Widget authJourneySignupStepUseCase(BuildContext context) {
  return _authPageScene(const SignupPage(), viewport: _AuthViewport.mobile);
}

Widget captureJourneyCaptureStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: ProviderScope(
      child: RecordingPage(binding: _widgetbookMicRecorderBinding),
    ),
  );
}

Widget captureJourneyInboxStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _inboxPageScene(
      matomes: _journeyInboxMatomes,
      inboxItems: _journeyLooseInboxItems,
      looseItems: _journeyLooseInboxItems,
    ),
  );
}

Widget captureJourneyMatomeStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _matomeDetailPageScene(_journeyMatome.id),
  );
}

Widget organizeJourneyInboxStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _inboxPageScene(
      matomes: _journeyInboxMatomes,
      inboxItems: _journeyLooseInboxItems,
      looseItems: _journeyLooseInboxItems,
    ),
  );
}

Widget organizeJourneyMatomeStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _matomeDetailPageScene(_journeyMatome.id),
  );
}

Widget organizeJourneySpaceStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _spaceDetailPageScene('widgetbook-space-work'),
  );
}

Widget reviewJourneyFilesStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _filesPageScene(
      filesForCurrentOwnerProvider.overrideWith((ref) async => _filesSample),
    ),
  );
}

Widget reviewJourneyAudioStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _fileDetailPageScene(_journeyAudioRow.id),
  );
}

Widget recoveryJourneySettingsStepUseCase(BuildContext context) {
  return _routeSurface(width: 390, height: 760, child: _settingsPageScene());
}

Widget recoveryJourneyInboxStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _inboxPageScene(
      matomes: _journeyInboxMatomes,
      inboxItems: _journeyLooseInboxItems,
      looseItems: _journeyLooseInboxItems,
    ),
  );
}

Widget recoveryJourneyFilesStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 390,
    height: 760,
    child: _filesPageScene(
      filesForCurrentOwnerProvider.overrideWith((ref) async => _filesSample),
    ),
  );
}

Widget authJourneyWelcomeDesktopStepUseCase(BuildContext context) {
  return _authPageScene(const WelcomePage(), viewport: _AuthViewport.desktop);
}

Widget authJourneyLoginDesktopStepUseCase(BuildContext context) {
  return _authPageScene(const LoginPage(), viewport: _AuthViewport.desktop);
}

Widget authJourneySignupDesktopStepUseCase(BuildContext context) {
  return _authPageScene(const SignupPage(), viewport: _AuthViewport.desktop);
}

Widget captureJourneyCaptureDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 900,
    height: 760,
    child: ProviderScope(
      child: RecordingPage(binding: _widgetbookMicRecorderBinding),
    ),
  );
}

Widget captureJourneyInboxDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 1100,
    height: 760,
    child: _inboxPageScene(
      matomes: _journeyInboxMatomes,
      inboxItems: _journeyLooseInboxItems,
      looseItems: _journeyLooseInboxItems,
    ),
  );
}

Widget captureJourneyMatomeDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 900,
    height: 760,
    child: _matomeDetailPageScene(_journeyMatome.id),
  );
}

Widget organizeJourneyInboxDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 1100,
    height: 760,
    child: _inboxPageScene(
      matomes: _journeyInboxMatomes,
      inboxItems: _journeyLooseInboxItems,
      looseItems: _journeyLooseInboxItems,
    ),
  );
}

Widget organizeJourneyMatomeDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 900,
    height: 760,
    child: _matomeDetailPageScene(_journeyMatome.id),
  );
}

Widget organizeJourneySpaceDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 900,
    height: 760,
    child: _spaceDetailPageScene('widgetbook-space-work'),
  );
}

Widget reviewJourneyFilesDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 1100,
    height: 760,
    child: _filesPageScene(
      filesForCurrentOwnerProvider.overrideWith((ref) async => _filesSample),
    ),
  );
}

Widget reviewJourneyAudioDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 900,
    height: 760,
    child: _fileDetailPageScene(_journeyAudioRow.id),
  );
}

Widget recoveryJourneySettingsDesktopStepUseCase(BuildContext context) {
  return _routeSurface(width: 900, height: 760, child: _settingsPageScene());
}

Widget recoveryJourneyInboxDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 1100,
    height: 760,
    child: _inboxPageScene(
      matomes: _journeyInboxMatomes,
      inboxItems: _journeyLooseInboxItems,
      looseItems: _journeyLooseInboxItems,
    ),
  );
}

Widget recoveryJourneyFilesDesktopStepUseCase(BuildContext context) {
  return _routeSurface(
    width: 1100,
    height: 760,
    child: _filesPageScene(
      filesForCurrentOwnerProvider.overrideWith((ref) async => _filesSample),
    ),
  );
}

Widget routeFrameUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 438,
    child: _RouteFrame(
      width: 390,
      height: 640,
      child: _FramePreviewBody(title: 'Route frame'),
    ),
  );
}

Widget authPageFrameUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 388,
    child: _AuthPageFrame(
      size: Size(340, 640),
      child: _FramePreviewBody(title: 'Auth frame'),
    ),
  );
}

Widget phoneFrameUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 408,
    child: _PhoneFrame(child: _FramePreviewBody(title: 'Phone frame')),
  );
}

Widget windowFrameUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 1040,
    child: _WindowFrame(expanded: true),
  );
}

// Route Pages render responsively: the surface width drives the app's mobile vs
// desktop (master-detail) layout. Each Page therefore ships a Mobile and a
// Desktop use case that reuse the SAME viewport-agnostic scene, varying only the
// rendered width. These back the `Pages/Mobile/...` and `Pages/Desktop/...`
// catalog groups.
Widget _mobilePage(Widget child) =>
    _routeSurface(width: 390, height: 760, child: child);

Widget _desktopPage(Widget child) =>
    _routeSurface(width: 1280, height: 800, child: child);

// Screen stories are grouped under `Screens/Mobile/...` and `Screens/Desktop/...`
// by rendering the SAME use case inside a viewport of the matching width, so
// responsive screen bodies pick their compact vs expanded layout via MediaQuery.
_StorySpec _mobileScreen(String name, WidgetBuilder inner) =>
    _StorySpec(name, (context) => _screenViewport(width: 390, inner: inner));

_StorySpec _desktopScreen(String name, WidgetBuilder inner) =>
    _StorySpec(name, (context) => _screenViewport(width: 1280, inner: inner));

Widget _screenViewport({required double width, required WidgetBuilder inner}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: width,
      child: Builder(
        builder: (context) {
          final base = MediaQuery.maybeOf(context) ?? const MediaQueryData();
          return MediaQuery(
            data: base.copyWith(size: Size(width, base.size.height)),
            child: Builder(builder: inner),
          );
        },
      ),
    ),
  );
}

Override _filesSampleOverride() =>
    filesForCurrentOwnerProvider.overrideWith((ref) async => _filesSample);

Widget filesPageMobileUseCase(BuildContext context) =>
    _mobilePage(_filesPageScene(_filesSampleOverride()));

Widget filesPageDesktopUseCase(BuildContext context) =>
    _desktopPage(_filesPageScene(_filesSampleOverride()));

Widget inboxPageMobileUseCase(BuildContext context) =>
    _mobilePage(_inboxPageScene());

Widget inboxPageDesktopUseCase(BuildContext context) =>
    _desktopPage(_inboxPageScene());

Widget matomeDetailPageMobileUseCase(BuildContext context) => _mobilePage(
  const ProviderScope(child: MatomeDetailPage(id: 'widgetbook-matome')),
);

Widget matomeDetailPageDesktopUseCase(BuildContext context) => _desktopPage(
  const ProviderScope(child: MatomeDetailPage(id: 'widgetbook-matome')),
);

// Files page states: loaded (above), empty, perpetual loading, and load error.
Override _filesEmptyOverride() =>
    filesForCurrentOwnerProvider.overrideWith((ref) async => const <FileRow>[]);

Override _filesLoadingOverride() => filesForCurrentOwnerProvider.overrideWith(
  (ref) => Future<List<FileRow>>.delayed(const Duration(days: 1)),
);

Override _filesErrorOverride() => filesForCurrentOwnerProvider.overrideWith(
  (ref) async => throw const ApiException('Failed to load files'),
);

Widget filesPageEmptyMobileUseCase(BuildContext context) =>
    _mobilePage(_filesPageScene(_filesEmptyOverride()));

Widget filesPageEmptyDesktopUseCase(BuildContext context) =>
    _desktopPage(_filesPageScene(_filesEmptyOverride()));

Widget filesPageLoadingMobileUseCase(BuildContext context) =>
    _mobilePage(_filesPageScene(_filesLoadingOverride()));

Widget filesPageLoadingDesktopUseCase(BuildContext context) =>
    _desktopPage(_filesPageScene(_filesLoadingOverride()));

Widget filesPageErrorMobileUseCase(BuildContext context) =>
    _mobilePage(_filesPageScene(_filesErrorOverride()));

Widget filesPageErrorDesktopUseCase(BuildContext context) =>
    _desktopPage(_filesPageScene(_filesErrorOverride()));

// Inbox page states: empty (above), populated, and loading.
Widget inboxPagePopulatedMobileUseCase(BuildContext context) => _mobilePage(
  _inboxPageScene(
    matomes: _journeyInboxMatomes,
    inboxItems: _journeyLooseInboxItems,
    looseItems: _journeyLooseInboxItems,
  ),
);

Widget inboxPagePopulatedDesktopUseCase(BuildContext context) => _desktopPage(
  _inboxPageScene(
    matomes: _journeyInboxMatomes,
    inboxItems: _journeyLooseInboxItems,
    looseItems: _journeyLooseInboxItems,
  ),
);

Widget inboxPageLoadingMobileUseCase(BuildContext context) =>
    _mobilePage(_inboxPageScene(loading: true));

Widget inboxPageLoadingDesktopUseCase(BuildContext context) =>
    _desktopPage(_inboxPageScene(loading: true));

// Matome detail page states: not found (above) and loaded (seeded controller).
Widget matomeDetailLoadedMobileUseCase(BuildContext context) =>
    _mobilePage(_matomeDetailPageScene('widgetbook-matome'));

Widget matomeDetailLoadedDesktopUseCase(BuildContext context) =>
    _desktopPage(_matomeDetailPageScene('widgetbook-matome'));

Widget fileDetailPageAudioMobileUseCase(BuildContext context) => _mobilePage(
  const ProviderScope(child: FileDetailPage.audio(id: 'widgetbook-audio')),
);

Widget fileDetailPageAudioDesktopUseCase(BuildContext context) => _desktopPage(
  const ProviderScope(child: FileDetailPage.audio(id: 'widgetbook-audio')),
);

Widget fileDetailPageImageMobileUseCase(BuildContext context) => _mobilePage(
  const ProviderScope(child: FileDetailPage.image(id: 'widgetbook-image')),
);

Widget fileDetailPageImageDesktopUseCase(BuildContext context) => _desktopPage(
  const ProviderScope(child: FileDetailPage.image(id: 'widgetbook-image')),
);

Widget fileDetailPageDocumentMobileUseCase(BuildContext context) => _mobilePage(
  const ProviderScope(child: FileDetailPage.document(id: 'widgetbook-document')),
);

Widget fileDetailPageDocumentDesktopUseCase(BuildContext context) =>
    _desktopPage(
      const ProviderScope(
        child: FileDetailPage.document(id: 'widgetbook-document'),
      ),
    );

Widget recordingPageMobileUseCase(BuildContext context) => _mobilePage(
  ProviderScope(child: RecordingPage(binding: _widgetbookMicRecorderBinding)),
);

Widget recordingPageDesktopUseCase(BuildContext context) => _desktopPage(
  ProviderScope(child: RecordingPage(binding: _widgetbookMicRecorderBinding)),
);

Widget meetingRecordingPageMobileUseCase(BuildContext context) => _mobilePage(
  ProviderScope(
    child: MeetingRecordingPage(binding: _widgetbookMeetingRecorderBinding),
  ),
);

Widget meetingRecordingPageDesktopUseCase(BuildContext context) => _desktopPage(
  ProviderScope(
    child: MeetingRecordingPage(binding: _widgetbookMeetingRecorderBinding),
  ),
);

Widget settingsPageMobileUseCase(BuildContext context) =>
    _mobilePage(_settingsPageScene());

Widget settingsPageDesktopUseCase(BuildContext context) =>
    _desktopPage(_settingsPageScene());

Widget calendarPageMobileUseCase(BuildContext context) =>
    _mobilePage(const ProviderScope(child: CalendarPage()));

Widget calendarPageDesktopUseCase(BuildContext context) =>
    _desktopPage(const ProviderScope(child: CalendarPage()));

Widget spacesPageMobileUseCase(BuildContext context) =>
    _mobilePage(_spacesPageScene());

Widget spacesPageDesktopUseCase(BuildContext context) =>
    _desktopPage(_spacesPageScene());

Widget spaceDetailPageMobileUseCase(BuildContext context) =>
    _mobilePage(_spaceDetailPageScene('widgetbook-space'));

Widget spaceDetailPageDesktopUseCase(BuildContext context) =>
    _desktopPage(_spaceDetailPageScene('widgetbook-space'));

Widget contactsPageMobileUseCase(BuildContext context) =>
    _mobilePage(_contactsPageScene());

Widget contactsPageDesktopUseCase(BuildContext context) =>
    _desktopPage(_contactsPageScene());

Widget contactDetailPageMobileUseCase(BuildContext context) =>
    _mobilePage(_contactDetailPageScene('widgetbook-contact'));

Widget contactDetailPageDesktopUseCase(BuildContext context) =>
    _desktopPage(_contactDetailPageScene('widgetbook-contact'));

Widget _routeSurface({
  required double width,
  required double height,
  required Widget child,
}) {
  return _UseCaseSurface(
    width: width + 48,
    child: _RouteFrame(width: width, height: height, child: child),
  );
}

Widget _filesPageScene(Override filesOverride) {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore({'matome.files_view': 'grid'}),
      ),
      filesOverride,
    ],
    child: const FilesPage(),
  );
}

Widget _inboxPageScene({
  List<MatomeItem> matomes = const <MatomeItem>[],
  List<InboxItem> inboxItems = const <InboxItem>[],
  List<InboxItem> looseItems = const <InboxItem>[],
  bool loading = false,
}) {
  AsyncValue<List<T>> av<T>(List<T> data) =>
      loading ? AsyncValue<List<T>>.loading() : AsyncValue.data(data);
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore({'matome.inbox_view': 'cards'}),
      ),
      matomeInboxControllerProvider.overrideWith(
        (ref) => _WidgetbookMatomeInboxController(ref, av(matomes)),
      ),
      inboxControllerProvider.overrideWith(
        (ref) => _WidgetbookInboxController(ref, av(inboxItems)),
      ),
      looseInboxControllerProvider.overrideWith(
        (ref) => _WidgetbookLooseInboxController(ref, av(looseItems)),
      ),
      filingSpacesProvider.overrideWith((ref) async => const []),
      uploadRetryServiceProvider.overrideWith(
        _WidgetbookUploadRetryService.new,
      ),
    ],
    child: const InboxPage(),
  );
}

Widget _settingsPageScene() {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
    child: const SettingsPage(),
  );
}

Widget _matomeDetailPageScene(String id) {
  return ProviderScope(
    overrides: [
      matomeDetailControllerProvider.overrideWith(
        (ref, id) => _WidgetbookMatomeDetailController(ref, id),
      ),
    ],
    child: MatomeDetailPage(id: id),
  );
}

Widget _fileDetailPageScene(String id) {
  return ProviderScope(
    overrides: [
      detailsControllerProvider.overrideWith(
        (ref, id) => _WidgetbookDetailsController(ref, id),
      ),
    ],
    child: FileDetailPage.audio(id: id),
  );
}

Widget _spaceDetailPageScene(String spaceId) {
  return ProviderScope(
    overrides: [
      spaceDetailControllerProvider.overrideWith(
        (ref, id) => _WidgetbookSpaceDetailController(ref, id),
      ),
      filingSpacesProvider.overrideWith((ref) async => _journeySpaces),
    ],
    child: SpaceDetailPage(spaceId: spaceId),
  );
}

Widget _spacesPageScene() {
  return ProviderScope(
    overrides: [
      spacesControllerProvider.overrideWith(
        (ref) => _WidgetbookSpacesController(ref),
      ),
    ],
    child: const SpacesPage(),
  );
}

Widget _contactsPageScene() {
  return ProviderScope(
    overrides: [
      contactsControllerProvider.overrideWith(
        (ref) => _WidgetbookContactsController(ref),
      ),
    ],
    child: const ContactsPage(),
  );
}

Widget _contactDetailPageScene(String id) {
  return ProviderScope(
    overrides: [contactDetailProvider.overrideWith((ref, id) async => null)],
    child: ContactDetailPage(id: id),
  );
}

class _FramePreviewBody extends StatelessWidget {
  const _FramePreviewBody({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return ColoredBox(
      color: colors.background,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(context.radius.md),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: EdgeInsets.all(spacing.lg),
            child: Text(
              title,
              style: typography.title.copyWith(color: colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteFrame extends StatelessWidget {
  const _RouteFrame({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(radius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.lg),
        child: SizedBox(
          width: width,
          height: height,
          child: _PreviewViewport(size: Size(width, height), child: child),
        ),
      ),
    );
  }
}

class _PreviewViewport extends StatelessWidget {
  const _PreviewViewport({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = MediaQuery.maybeOf(context) ?? MediaQueryData(size: size);
    return MediaQuery(
      data: base.copyWith(
        size: size,
        padding: EdgeInsets.zero,
        viewPadding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
        systemGestureInsets: EdgeInsets.zero,
      ),
      child: child,
    );
  }
}

class _PageFlowScene extends StatelessWidget {
  const _PageFlowScene({required this.steps, required this.width});

  final List<_PageFlowStepSpec> steps;
  final double width;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return _UseCaseSurface(
      width: width,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _PageFlowStep(spec: steps[i]),
              if (i != steps.length - 1) SizedBox(width: spacing.md),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageFlowStepSpec {
  const _PageFlowStepSpec({
    required this.title,
    required this.route,
    required this.note,
    required this.width,
    required this.height,
    required this.child,
  });

  final String title;
  final String route;
  final String note;
  final double width;
  final double height;
  final Widget child;
}

class _PageFlowStep extends StatelessWidget {
  const _PageFlowStep({required this.spec});

  final _PageFlowStepSpec spec;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final colors = context.colors;
    return SizedBox(
      width: spec.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec.title,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            spec.route,
            style: typography.bodySmall.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.xs),
          _RouteFrame(
            width: spec.width,
            height: spec.height,
            child: spec.child,
          ),
          SizedBox(height: spacing.xs),
          Text(
            spec.note,
            style: typography.label.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _WidgetbookMatomeDetailController extends MatomeDetailController {
  _WidgetbookMatomeDetailController(Ref ref, String id) : super(ref, id) {
    state = _widgetbookMatomeDetailState(state.id);
  }

  @override
  Future<void> load() async {
    state = _widgetbookMatomeDetailState(state.id);
  }

  @override
  Future<void> fileIntoSpace(String spaceId) async {}

  @override
  Future<void> saveNotes(String notes) async {}

  @override
  Future<WorkspaceRow> defaultPersonalSpace() async => _journeySpaces.first;
}

class _WidgetbookDetailsController extends DetailsController {
  _WidgetbookDetailsController(Ref ref, String id) : super(ref, id) {
    state = _widgetbookDetailsState(state.id);
  }

  @override
  Future<void> load() async {
    state = _widgetbookDetailsState(state.id);
  }

  @override
  Future<void> save(String text) async {}

  @override
  Future<void> retry() async {
    state = state.copyWith(
      isLoading: false,
      isProcessing: false,
      processingFailed: false,
      pendingUpload: false,
    );
  }

  @override
  Future<void> delete() async {}

  @override
  Future<List<WorkspaceRow>> spaces() async => _journeySpaces;

  @override
  Future<void> moveToSpace(String workspaceId) async {}
}

class _WidgetbookSpaceDetailController extends SpaceDetailController {
  _WidgetbookSpaceDetailController(Ref ref, String spaceId)
    : super(ref, spaceId);

  @override
  Future<void> load() async {
    state = AsyncValue.data(_widgetbookSpaceDetailState(spaceId));
  }
}

class _WidgetbookSpacesController extends SpacesController {
  _WidgetbookSpacesController(Ref ref) : super(ref);

  @override
  Future<void> load() async {
    state = const AsyncValue.data(_widgetbookSpaceCards);
  }

  @override
  Future<void> createSpace(String name) async {}

  @override
  Future<void> deleteSpace(String id) async {}
}

class _WidgetbookContactsController extends ContactsController {
  _WidgetbookContactsController(Ref ref) : super(ref);

  @override
  Future<void> load() async {
    state = const AsyncValue.data(_widgetbookContactRows);
  }

  @override
  Future<void> createContact({
    required String displayName,
    String notes = '',
  }) async {}

  @override
  Future<void> updateContact({
    required String id,
    required String displayName,
    String notes = '',
  }) async {}

  @override
  Future<void> deleteContact(String id) async {}
}

MatomeDetailState _widgetbookMatomeDetailState(String id) {
  return MatomeDetailState(
    id: id,
    matome: _journeyMatome,
    spaces: _journeySpaces,
    isLoading: false,
  );
}

SpaceDetailState _widgetbookSpaceDetailState(String spaceId) {
  final space = _journeySpaces.firstWhere(
    (space) => space.id == spaceId,
    orElse: () => _journeySpaces.first,
  );
  return SpaceDetailState(
    name: space.name,
    items: const [_journeyMatome],
    isLocal: space.isLocal == 1,
  );
}

DetailsState _widgetbookDetailsState(String id) {
  return DetailsState(
    id: id,
    row: _journeyAudioRow,
    audioSource: const AudioSource.none(),
    isLoading: false,
    notFound: false,
    isProcessing: false,
    processingFailed: false,
    pendingUpload: false,
  );
}

const _journeyTimestamp = 1782691200000;

const _journeyAudioRecording = RecordingItem(
  id: 'widgetbook-audio-review',
  title: 'Weekly product review',
  summary: 'Decision log, launch risks, and owners captured from the review.',
  timestamp: 'Today 09:24',
  duration: '12:04',
  badge: 'Product',
  notes: 'Follow up with design on empty states before Friday.',
  isProcessing: false,
  mediaType: 'audio',
  processingStatus: 'done',
  coreId: 501,
  workspaceName: 'Product',
);

const _journeyFailedRecording = RecordingItem(
  id: 'widgetbook-retry-local',
  title: 'Parking-lot voice note',
  summary: 'Upload failed while offline; retry is available from the card.',
  timestamp: 'Today 08:10',
  duration: '01:42',
  badge: 'Inbox',
  notes: 'Re-capture the action items if retry keeps failing.',
  isProcessing: false,
  mediaType: 'audio',
  processingStatus: 'failed',
);

const _journeyMatome = MatomeItem(
  id: 'widgetbook-matome-review',
  spaceId: null,
  title: 'Launch readiness review',
  happenedAt: _journeyTimestamp,
  createdAt: _journeyTimestamp,
  description: 'Collected notes from the launch readiness review.',
  aggregatedSummary:
      'The team confirmed the release checklist, kept analytics as the highest '
      'risk, and assigned follow-ups before the Friday go/no-go.',
  summaryStale: false,
  recordingCount: 1,
  recordings: [_journeyAudioRecording],
  audioCount: 1,
  peopleCount: 3,
);

const _journeyInboxMatomes = <MatomeItem>[_journeyMatome];

const _journeyLooseInboxItems = <InboxItem>[
  InboxItem(card: _journeyFailedRecording, createdAt: _journeyTimestamp),
];

const _journeySpaces = <WorkspaceRow>[
  WorkspaceRow(
    id: 'widgetbook-space-personal',
    name: 'Personal',
    isDefault: 1,
    createdAt: _journeyTimestamp,
    spaceType: 'personal',
    isLocal: 1,
  ),
  WorkspaceRow(
    id: 'widgetbook-space-work',
    name: 'Product',
    isDefault: 0,
    createdAt: _journeyTimestamp,
    spaceType: 'workspace',
    isLocal: 0,
  ),
];

const _widgetbookSpaceCards = <SpaceCard>[
  SpaceCard(
    id: 'widgetbook-space-personal',
    name: 'Personal',
    count: 2,
    isLocal: true,
  ),
  SpaceCard(id: 'widgetbook-space-work', name: 'Product', count: 5),
];

const _widgetbookContactRows = <ContactRow>[
  ContactRow(
    id: 'widgetbook-contact-mika',
    ownerId: kPlaceholderContactOwnerId,
    displayName: 'Mika Tanaka',
    email: 'mika@example.com',
    company: 'Matome Labs',
    title: 'Product Lead',
    metadata: '{"notes":"Launch review owner."}',
    createdAt: _journeyTimestamp,
  ),
  ContactRow(
    id: 'widgetbook-contact-ren',
    ownerId: kPlaceholderContactOwnerId,
    displayName: 'Ren Ito',
    company: 'Design Studio',
    title: 'Designer',
    metadata: '{}',
    createdAt: _journeyTimestamp,
  ),
];

const _journeyAudioRow = RecordingRow(
  id: 'widgetbook-audio-review',
  title: 'Weekly product review',
  summary: 'Decision log, launch risks, and owners captured from the review.',
  timestamp: 'Today 09:24',
  duration: '12:04',
  badge: 'Product',
  isProcessing: 0,
  audioFilePath: '',
  createdAt: _journeyTimestamp,
  notes: 'Follow up with design on empty states before Friday.',
  workspaceId: 'widgetbook-space-work',
  mediaType: 'audio',
  processingStatus: 'done',
  coreId: 501,
  matomeId: 'widgetbook-matome-review',
  transcript:
      'We confirmed the launch checklist, kept analytics instrumentation as the '
      'highest risk, and assigned owners for support docs, billing copy, and the '
      'Friday go/no-go review.',
  ownerId: 'widgetbook-owner',
  byteSize: 2480000,
);

class _WidgetbookInboxController extends InboxController {
  _WidgetbookInboxController(super.ref, this._seed) {
    state = _seed;
  }

  final AsyncValue<List<InboxItem>> _seed;

  @override
  Future<void> refresh() async {
    state = _seed;
  }

  @override
  Future<void> reloadFromLocal() async {
    state = _seed;
  }
}

class _WidgetbookMatomeInboxController extends MatomeInboxController {
  _WidgetbookMatomeInboxController(super.ref, this._seed) {
    state = _seed;
  }

  final AsyncValue<List<MatomeItem>> _seed;

  @override
  Future<void> refresh() async {
    state = _seed;
  }

  @override
  Future<void> reloadFromLocal() async {
    state = _seed;
  }
}

class _WidgetbookLooseInboxController extends LooseInboxController {
  _WidgetbookLooseInboxController(super.ref, this._seed) {
    state = _seed;
  }

  final AsyncValue<List<InboxItem>> _seed;

  @override
  Future<void> reloadFromLocal() async {
    state = _seed;
  }
}

class _WidgetbookUploadRetryService extends UploadRetryService {
  _WidgetbookUploadRetryService(super.ref);

  @override
  Future<void> start() async {}
}

class _WidgetbookAudioRecordingService implements AudioRecordingService {
  const _WidgetbookAudioRecordingService();

  @override
  Future<bool> isCaptureSupported() async => false;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _widgetbookAudioRecordingServiceProvider =
    Provider<AudioRecordingService>((ref) {
      const service = _WidgetbookAudioRecordingService();
      ref.onDispose(service.dispose);
      return service;
    });

final _widgetbookRecordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingState>(
      (ref) => RecordingController(
        ref.watch(_widgetbookAudioRecordingServiceProvider),
      ),
    );

final _widgetbookRecordingFinisherProvider = Provider<RecordingFinisher>(
  (ref) => RecordingFinisher(
    ref,
    controllerProvider: _widgetbookRecordingControllerProvider,
    serviceProvider: _widgetbookAudioRecordingServiceProvider,
  ),
);

Future<String?> _widgetbookUnsupportedCaptureReason(WidgetRef ref) async {
  return 'Audio capture is disabled in Widgetbook fixtures.';
}

final _widgetbookMicRecorderBinding = RecorderBinding(
  serviceProvider: _widgetbookAudioRecordingServiceProvider,
  controllerProvider: _widgetbookRecordingControllerProvider,
  finisherProvider: _widgetbookRecordingFinisherProvider,
  unsupportedReason: _widgetbookUnsupportedCaptureReason,
);

final _widgetbookMeetingRecorderBinding = RecorderBinding(
  serviceProvider: _widgetbookAudioRecordingServiceProvider,
  controllerProvider: _widgetbookRecordingControllerProvider,
  finisherProvider: _widgetbookRecordingFinisherProvider,
  titleLabel: 'Record meeting',
  unsupportedReason: _widgetbookUnsupportedCaptureReason,
  supportsPause: false,
);

enum _AuthViewport { mobile, desktop }

Widget _authPageScene(
  Widget page, {
  required _AuthViewport viewport,
  AsyncValue<AuthSession?>? authState,
}) {
  final size = switch (viewport) {
    _AuthViewport.mobile => const Size(390, 760),
    _AuthViewport.desktop => const Size(900, 760),
  };

  final framed = _UseCaseSurface(
    width: size.width + 48,
    child: _AuthPageFrame(size: size, child: page),
  );

  if (authState == null) return framed;
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        (ref) => _WidgetbookAuthController(ref, authState),
      ),
    ],
    child: framed,
  );
}

/// Auth controller stub for the catalog: holds a fixed [AsyncValue] state so the
/// login/signup Pages can render their error and loading variants without any
/// network. Overrides the network entry points to keep the injected state.
class _WidgetbookAuthController extends AuthController {
  _WidgetbookAuthController(Ref ref, this._fixed) : super(ref) {
    state = _fixed;
  }

  final AsyncValue<AuthSession?> _fixed;

  @override
  Future<void> restoreSession() async {
    state = _fixed;
  }

  @override
  Future<void> login({required String email, required String password}) async {
    state = _fixed;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    state = _fixed;
  }
}

class _AuthFlowScene extends StatelessWidget {
  const _AuthFlowScene();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AuthFlowStep(title: '1. Welcome', child: WelcomePage()),
          SizedBox(width: spacing.md),
          const _AuthFlowStep(title: '2. Login', child: LoginPage()),
          SizedBox(width: spacing.md),
          const _AuthFlowStep(title: '3. Signup', child: SignupPage()),
        ],
      ),
    );
  }
}

class _AuthFlowStep extends StatelessWidget {
  const _AuthFlowStep({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final colors = context.colors;

    return SizedBox(
      width: 340,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: spacing.xs),
          _AuthPageFrame(size: const Size(340, 640), child: child),
        ],
      ),
    );
  }
}

class _AuthPageFrame extends StatelessWidget {
  const _AuthPageFrame({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(radius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.lg),
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: _PreviewViewport(
            size: size,
            child: ProviderScope(
              overrides: [
                tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
              ],
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Widget authFieldsUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthControlsSample());
}

Widget authFeedbackUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthFeedbackSample());
}

Widget primaryButtonsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _PrimaryButtonsSample());
}

Widget appTextButtonsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _TextButtonsSample());
}

Widget appTextFieldsUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _TextFieldsSample());
}

Widget avatarsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _AvatarsSample());
}

Widget appCardDoneUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.done),
  );
}

Widget appCardPendingUploadUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.pendingUpload),
  );
}

Widget appCardProcessingUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.processing),
  );
}

Widget appCardFailedUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.failed),
  );
}

Widget appCardCalendarUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _CalendarAppCardSample());
}

Widget statusBadgesUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _StatusBadgesSample());
}

Widget matomeSyncChipUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _MatomeSyncChipSample());
}

// ─── Matome Details panel scaffolding (#1458) ─────────────────────────────────
//
// CONVERGENCE: the catalog renders the REAL, PUBLIC panel widgets shipped in
// `package:matome_flutter/ui/matome_detail_panel.dart` — the SAME widgets the
// live `_MatomeDetails` composes. There is no private mock to drift from.

Widget matomePanelSectionUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _MatomePanelSectionSample());
}

Widget matomePanelRowUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _MatomePanelRowSample());
}

Widget matomePanelAddRowUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 360,
    child: MatomePanelAddRow(
      icon: Icons.add_photo_alternate_outlined,
      label: 'Add photo',
    ),
  );
}

// ─── Matome detail — the COMPLETE assembled panel (#1478) ────────────────────
//
// The owner-approved, fully-composed Details panel rendered via the public,
// presentational `MatomeDetailPanel` (Items · People · Space · Notes · Share),
// from `package:matome_flutter/ui/matome_detail_panel.dart` with static sample
// data. The `type:` is `MatomeDetailPanel` so the tree reads "MatomeDetailPanel"
// under [Screens]/Matome detail — not the atom "MatomePanelSection". The live
// `_MatomeDetails` still composes the section atoms against its providers;
// converging that screen onto this widget is tracked as a follow-up.

Widget detailPanelFiledUseCase(BuildContext context) {
  return const _DetailPanelSurface(child: MatomeDetailPanel(data: _filedPanel));
}

Widget detailPanelInboxUseCase(BuildContext context) {
  return const _DetailPanelSurface(child: MatomeDetailPanel(data: _inboxPanel));
}

const _panelItems = <MatomeDetailPanelItem>[
  MatomeDetailPanelItem(
    mediaType: 'audio',
    title: 'Meeting audio',
    meta: '14:30 · 12:04',
    onCloud: true,
  ),
  MatomeDetailPanelItem(
    mediaType: 'audio',
    title: 'Follow-up note',
    meta: '14:55 · 03:20',
    onCloud: false,
  ),
  MatomeDetailPanelItem(
    mediaType: 'image',
    title: 'Whiteboard photo',
    meta: '15:10',
    onCloud: true,
  ),
  MatomeDetailPanelItem(
    mediaType: 'document',
    title: 'Quarterly report',
    meta: '15:24',
    onCloud: true,
  ),
];

const _panelContacts = <MatomeDetailPanelContact>[
  MatomeDetailPanelContact(initial: 'A', name: 'Ana', role: 'Organizer'),
  MatomeDetailPanelContact(initial: 'K', name: 'Ken', role: 'Attendee'),
];

const _panelNotes =
    'Recap the decisions, owners, and next steps so the matome reads like a '
    'short letter rather than a transcript dump.';

const _filedPanel = MatomeDetailPanelData(
  items: _panelItems,
  contacts: _panelContacts,
  spaceName: 'Marketing',
  notes: _panelNotes,
);

const _inboxPanel = MatomeDetailPanelData(
  items: _panelItems,
  contacts: _panelContacts,
  spaceName: null,
  notes: _panelNotes,
);

/// Bounded, scrollable, themed surface for the assembled [MatomeDetailPanel].
class _DetailPanelSurface extends StatelessWidget {
  const _DetailPanelSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(radius.lg),
              border: Border.all(color: colors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── Relationship picker — the STANDARD "add a relationship" surface ──────────
//
// One generic, presentational component (from
// `package:matome_flutter/ui/relationship_picker.dart`) backing every "pick
// existing thing(s) and link them here" flow — People, Spaces, Matomes, Files —
// plus the create/source variant ("Add item" → Record · Photo · File). The same
// widget will back the Matome panel AND the future Files / Contacts pages, so
// these use cases double as the design review surface before any wiring.

Widget relationshipPickerPeopleUseCase(BuildContext context) {
  return _RelationshipPickerSurface(
    child: RelationshipPicker(
      onClose: () {},
      data: RelationshipPickerData(
        title: 'Add people',
        mode: RelationshipSelectMode.multi,
        searchHint: 'Search contacts',
        confirmLabel: 'Add',
        emptyLabel: 'No matching contacts.\nUse “Create new contact” above.',
        actions: const [
          RelationshipAction(
            id: 'create',
            label: 'Create new contact',
            icon: Icons.person_add_alt_1_outlined,
          ),
        ],
        candidates: const [
          RelationshipCandidate(
            id: 'ana',
            title: 'Ana Ribeiro',
            subtitle: 'Organizer',
            icon: Icons.person_outline,
            linked: true,
          ),
          RelationshipCandidate(
            id: 'ken',
            title: 'Ken Watanabe',
            subtitle: 'ken@studio.jp',
            icon: Icons.person_outline,
          ),
          RelationshipCandidate(
            id: 'mara',
            title: 'Mara Lopes',
            subtitle: 'Design',
            icon: Icons.person_outline,
          ),
          RelationshipCandidate(
            id: 'sergio',
            title: 'Sérgio Pinto',
            subtitle: 'sergio@acme.co',
            icon: Icons.person_outline,
          ),
        ],
      ),
    ),
  );
}

Widget relationshipPickerSpaceUseCase(BuildContext context) {
  return _RelationshipPickerSurface(
    child: RelationshipPicker(
      onClose: () {},
      data: const RelationshipPickerData(
        title: 'File into a space',
        actions: [
          RelationshipAction(
            id: 'create',
            label: 'New space',
            icon: Icons.create_new_folder_outlined,
          ),
        ],
        candidates: [
          RelationshipCandidate(
            id: 'personal',
            title: 'Personal',
            subtitle: 'Default',
            icon: Icons.person_outline,
          ),
          RelationshipCandidate(
            id: 'marketing',
            title: 'Marketing',
            icon: Icons.folder_outlined,
            linked: true,
          ),
          RelationshipCandidate(
            id: 'clients',
            title: 'Clients',
            icon: Icons.folder_outlined,
          ),
        ],
      ),
    ),
  );
}

Widget relationshipPickerPrefilteredUseCase(BuildContext context) {
  // What "Add person" opens: the SAME unified picker, but pre-filtered to
  // Contacts via initialTypeId. Create actions live behind the header "+".
  return _RelationshipPickerSurface(
    child: RelationshipPicker(
      onClose: () {},
      data: const RelationshipPickerData(
        title: 'Add to this matome',
        mode: RelationshipSelectMode.multi,
        searchHint: 'Search contacts, files, spaces',
        initialTypeId: 'contact',
        types: [
          RelationshipType(
            id: 'contact',
            label: 'Contacts',
            icon: Icons.person_outline,
          ),
          RelationshipType(
            id: 'file',
            label: 'Files',
            icon: Icons.insert_drive_file_outlined,
          ),
          RelationshipType(
            id: 'space',
            label: 'Spaces',
            icon: Icons.folder_outlined,
          ),
        ],
        actions: [
          RelationshipAction(
            id: 'create-contact',
            label: 'Create contact',
            icon: Icons.person_add_alt_1_outlined,
          ),
          RelationshipAction(
            id: 'new-space',
            label: 'New space',
            icon: Icons.create_new_folder_outlined,
          ),
        ],
        candidates: [
          RelationshipCandidate(
            id: 'ken',
            typeId: 'contact',
            title: 'Ken Watanabe',
            subtitle: 'Contact · ken@studio.jp',
            icon: Icons.person_outline,
          ),
          RelationshipCandidate(
            id: 'mara',
            typeId: 'contact',
            title: 'Mara Lopes',
            subtitle: 'Contact · Design',
            icon: Icons.person_outline,
          ),
          RelationshipCandidate(
            id: 'f1',
            typeId: 'file',
            title: 'Q3 roadmap.pdf',
            subtitle: 'File · PDF · 2.4 MB',
            icon: Icons.picture_as_pdf_outlined,
          ),
        ],
      ),
    ),
  );
}

Widget relationshipPickerMatomeUseCase(BuildContext context) {
  // The SAME widget on the future Files page: link a file to matome(s). Proves
  // the component is entity-agnostic — only the data changes.
  return _RelationshipPickerSurface(
    child: RelationshipPicker(
      onClose: () {},
      data: const RelationshipPickerData(
        title: 'Add to a matome',
        mode: RelationshipSelectMode.multi,
        searchHint: 'Search matomes',
        actions: [
          RelationshipAction(
            id: 'create',
            label: 'New matome',
            icon: Icons.add_circle_outline,
          ),
        ],
        candidates: [
          RelationshipCandidate(
            id: 'm1',
            title: 'Client X — weekly sync',
            subtitle: 'Marketing · 6 items',
            icon: Icons.workspaces_outline,
            linked: true,
          ),
          RelationshipCandidate(
            id: 'm2',
            title: 'Q3 planning',
            subtitle: 'Clients · 3 items',
            icon: Icons.workspaces_outline,
          ),
          RelationshipCandidate(
            id: 'm3',
            title: 'Brand refresh',
            subtitle: 'Inbox · 1 item',
            icon: Icons.workspaces_outline,
          ),
        ],
      ),
    ),
  );
}

Widget relationshipPickerFilesUseCase(BuildContext context) {
  // Link existing files to a matome / contact — the file analogue of "Add
  // people". Per-type leading glyph; subtitle carries kind · size. Same widget,
  // file data.
  return _RelationshipPickerSurface(
    child: RelationshipPicker(
      onClose: () {},
      data: const RelationshipPickerData(
        title: 'Add files',
        mode: RelationshipSelectMode.multi,
        searchHint: 'Search files',
        actions: [
          RelationshipAction(
            id: 'upload',
            label: 'Upload file',
            icon: Icons.upload_file_outlined,
          ),
        ],
        candidates: [
          RelationshipCandidate(
            id: 'f1',
            title: 'Q3 roadmap.pdf',
            subtitle: 'PDF · 2.4 MB',
            icon: Icons.picture_as_pdf_outlined,
            linked: true,
          ),
          RelationshipCandidate(
            id: 'f2',
            title: 'whiteboard.png',
            subtitle: 'Image · 1.1 MB',
            icon: Icons.image_outlined,
          ),
          RelationshipCandidate(
            id: 'f3',
            title: 'standup audio',
            subtitle: 'Audio · 12:04',
            icon: Icons.mic_none_rounded,
          ),
          RelationshipCandidate(
            id: 'f4',
            title: 'meeting-notes.md',
            subtitle: 'Document · 4 KB',
            icon: Icons.description_outlined,
          ),
        ],
      ),
    ),
  );
}

Widget relationshipPickerMixedUseCase(BuildContext context) {
  // The UNIFIED picker, opened from a matome: search across Contacts + Files +
  // Spaces in one list, with type-filter chips. The host's OWN type (Matomes)
  // is omitted by the caller, so you never re-link the matome to itself.
  return _RelationshipPickerSurface(
    child: RelationshipPicker(
      onClose: () {},
      data: const RelationshipPickerData(
        title: 'Add to this matome',
        mode: RelationshipSelectMode.multi,
        searchHint: 'Search contacts, files, spaces',
        actions: [
          RelationshipAction(
            id: 'photo',
            label: 'Add photo',
            icon: Icons.add_photo_alternate_outlined,
          ),
          RelationshipAction(
            id: 'record',
            label: 'Record audio',
            icon: Icons.mic_none_rounded,
            enabled: false,
            tooltip: 'Coming soon',
          ),
          RelationshipAction(
            id: 'create-contact',
            label: 'Create contact',
            icon: Icons.person_add_alt_1_outlined,
          ),
        ],
        types: [
          RelationshipType(
            id: 'contact',
            label: 'Contacts',
            icon: Icons.person_outline,
          ),
          RelationshipType(
            id: 'file',
            label: 'Files',
            icon: Icons.insert_drive_file_outlined,
          ),
          RelationshipType(
            id: 'space',
            label: 'Spaces',
            icon: Icons.folder_outlined,
          ),
        ],
        candidates: [
          RelationshipCandidate(
            id: 'ana',
            typeId: 'contact',
            title: 'Ana Ribeiro',
            subtitle: 'Contact · Organizer',
            icon: Icons.person_outline,
            linked: true,
          ),
          RelationshipCandidate(
            id: 'ken',
            typeId: 'contact',
            title: 'Ken Watanabe',
            subtitle: 'Contact · ken@studio.jp',
            icon: Icons.person_outline,
          ),
          RelationshipCandidate(
            id: 'f1',
            typeId: 'file',
            title: 'Q3 roadmap.pdf',
            subtitle: 'File · PDF · 2.4 MB',
            icon: Icons.picture_as_pdf_outlined,
          ),
          RelationshipCandidate(
            id: 'f2',
            typeId: 'file',
            title: 'whiteboard.png',
            subtitle: 'File · Image · 1.1 MB',
            icon: Icons.image_outlined,
          ),
          RelationshipCandidate(
            id: 'marketing',
            typeId: 'space',
            title: 'Marketing',
            subtitle: 'Space',
            icon: Icons.folder_outlined,
          ),
          RelationshipCandidate(
            id: 'clients',
            typeId: 'space',
            title: 'Clients',
            subtitle: 'Space',
            icon: Icons.folder_outlined,
          ),
        ],
      ),
    ),
  );
}

Widget relationshipPickerEmptyUseCase(BuildContext context) {
  return _RelationshipPickerSurface(
    child: RelationshipPicker(
      onClose: () {},
      data: const RelationshipPickerData(
        title: 'Add people',
        mode: RelationshipSelectMode.multi,
        searchHint: 'Search contacts',
        emptyLabel: 'No contacts yet.\nCreate one to link it here.',
        actions: [
          RelationshipAction(
            id: 'create',
            label: 'Create new contact',
            icon: Icons.person_add_alt_1_outlined,
          ),
        ],
      ),
    ),
  );
}

/// Sheet/popover-style framed surface for the [RelationshipPicker] catalog: a
/// bordered surface card at a phone-sheet width so the use cases read like the
/// real overlay.
class _RelationshipPickerSurface extends StatelessWidget {
  const _RelationshipPickerSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(radius.lg),
              border: Border.all(color: colors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

Widget appBottomSheetUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _BottomSheetSample());
}

Widget appDialogUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _DialogSample());
}

Widget loadingIndicatorUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 300, child: _LoadingIndicatorSample());
}

Widget emptyStateUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _EmptyStateSample());
}

Widget fileTypeChipUseCase(BuildContext context) {
  // The doc media header across its icon families plus a missing-size row, each
  // with the DISABLED "Open" / "soon" affordance (preview is deferred, #1455).
  return const _UseCaseSurface(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FileTypeChip(
          fileName: 'Q3 roadmap.pdf',
          extension: 'pdf',
          sizeLabel: '2.4 MB',
        ),
        SizedBox(height: 12),
        FileTypeChip(
          fileName: 'meeting-notes.md',
          extension: 'md',
          sizeLabel: '4 KB',
        ),
        SizedBox(height: 12),
        FileTypeChip(fileName: 'archive.xyz', extension: 'xyz'),
      ],
    ),
  );
}

Widget matomeChipUseCase(BuildContext context) {
  // Filled pill carrying a matome title, plus the italic muted "Unfiled" state
  // (no matome relation). The filled treatment is the deliberate opposite of
  // SpaceChip's outlined pill.
  return const _UseCaseSurface(
    width: 320,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        MatomeChip(matome: 'Client X — weekly sync'),
        MatomeChip(),
      ],
    ),
  );
}

Widget spaceChipUseCase(BuildContext context) {
  // Outlined pill carrying a space (folder) name, plus the italic muted "Inbox"
  // state (no space relation) — INDEPENDENT of the matome relation above.
  return const _UseCaseSurface(
    width: 320,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SpaceChip(space: 'Marketing'),
        SpaceChip(),
      ],
    ),
  );
}

Widget roleChipUseCase(BuildContext context) {
  // A contact's matome_contacts role, tinted by role.
  return const _UseCaseSurface(
    width: 320,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        RoleChip(role: MatomeContactRole.organizer),
        RoleChip(role: MatomeContactRole.speaker),
        RoleChip(role: MatomeContactRole.attendee),
      ],
    ),
  );
}

Widget peopleClusterUseCase(BuildContext context) {
  // Overlapping initials with a "+N" overflow chip + a names tooltip. An empty
  // list renders nothing (callers add their own placeholder).
  return const _UseCaseSurface(
    width: 320,
    child: Row(
      children: [
        PeopleCluster(names: ['Ana', 'Ken']),
        SizedBox(width: 16),
        PeopleCluster(names: ['Leo', 'Ana', 'Ken', 'Mika', 'Yui']),
      ],
    ),
  );
}

// ─── Matome table (#1463) ─────────────────────────────────────────────────────
//
// CONVERGENCE (DR-000 / DR-001): these stories render the REAL, graduated
// `MatomeTable` shipped in
// `package:matome_flutter/features/matome/widgets/matome_table.dart` — the same
// widget the live inbox renders. There is no proposal mock to drift from.

Widget matomeTableDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 920,
    child: MatomeTable(rows: _matomeTableRows),
  );
}

Widget matomeTableSelectionUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 920,
    child: MatomeTable(
      rows: _matomeTableRows,
      initialSelection: const {'r1', 'r4'},
    ),
  );
}

Widget matomeTableCompactUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 380,
    child: MatomeTable(rows: _matomeTableRows),
  );
}

Widget matomeTableEmptyUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 920, child: MatomeTable(rows: []));
}

// ─── Contact detail (#1464) ───────────────────────────────────────────────────
//
// CONVERGENCE (DR-000 / DR-004): these stories render the REAL, graduated
// `ContactDetail` shipped in
// `package:matome_flutter/features/contacts/widgets/contact_detail.dart` — the
// same widget the `/contacts/:id` screen hosts. The proposal mock has been
// deleted; there is no second implementation to drift from. Copy reads
// `t.contacts.detail.*`, so the Localization addon swaps it between en / ja.

Widget contactDetailDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 920,
    child: ContactDetail(contact: _contactDetailFull),
  );
}

Widget contactDetailMobileUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 380,
    child: ContactDetail(contact: _contactDetailFull),
  );
}

Widget contactDetailSparseUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 920,
    child: ContactDetail(contact: _contactDetailSparse),
  );
}

/// Sample data for the graduated [ContactDetail] stories — mirrors the shared
/// goldens' fixtures so the catalog and the regression baseline stay in lockstep.
const _contactDetailFull = ContactDetailData(
  id: 'c-full',
  name: 'Ana Ribeiro',
  avatarIndex: 2,
  sync: ContactSyncState.synced,
  company: 'Acme Inc.',
  title: 'Product Lead',
  email: 'ana.ribeiro@acme.com',
  phone: '+55 11 99876-5432',
  notes:
      'Met at the Q2 offsite. Owns the billing roadmap; loops in Ken for '
      'anything pricing-related. Prefers async updates.',
  matomes: [
    ContactMatomeRef(
      id: 'm1',
      title: 'Client X — weekly sync',
      role: MatomeContactRole.organizer,
      when: '2h',
    ),
    ContactMatomeRef(
      id: 'm2',
      title: 'Sales call — Acme',
      role: MatomeContactRole.attendee,
      when: '1d',
    ),
    ContactMatomeRef(
      id: 'm3',
      title: 'Roadmap review',
      role: MatomeContactRole.speaker,
      when: '3d',
    ),
  ],
  spaces: ['Marketing', 'Sales'],
  files: [
    ContactFileRef(
      id: 'f1',
      name: 'Q3 roadmap.pdf',
      kind: ContactFileKind.document,
    ),
    ContactFileRef(
      id: 'f2',
      name: 'Design sync.m4a',
      kind: ContactFileKind.audio,
    ),
    ContactFileRef(
      id: 'f3',
      name: 'whiteboard.jpg',
      kind: ContactFileKind.image,
    ),
  ],
);

const _contactDetailSparse = ContactDetailData(
  id: 'c-sparse',
  name: 'Leo',
  avatarIndex: 5,
  sync: ContactSyncState.onDevice,
  matomes: [
    ContactMatomeRef(
      id: 'm2',
      title: 'Sales call — Acme',
      role: MatomeContactRole.attendee,
      when: '1d',
    ),
  ],
);

// ─── Contact tile (W1) ────────────────────────────────────────────────────────
//
// The REAL `ContactTile` from
// `package:matome_flutter/features/contacts/widgets/contact_tile.dart` — one row
// in the `/contacts` directory (tinted person glyph · name · optional notes ·
// chevron). PRESENTATIONAL: the caller owns the accent [color]
// (`context.colors.spaceColor(index)`).

Widget contactTileUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 380,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ContactTile(
          name: 'Ana Ribeiro',
          color: context.colors.spaceColor(0),
          notes: 'Product Lead · Acme Inc.',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        ContactTile(
          name: 'Leo',
          color: context.colors.spaceColor(1),
          onTap: () {},
        ),
      ],
    ),
  );
}

// ─── Master–detail scaffold (W1) ─────────────────────────────────────────────
//
// The REAL, presentational `MasterDetailScaffold` from
// `package:matome_flutter/ui/master_detail_scaffold.dart`. On expanded widths
// with the pane on the right it renders master + reading pane side-by-side; this
// case is sized at 1280×720 so the pane is shown.

Widget masterDetailScaffoldUseCase(BuildContext context) {
  return const SizedBox(
    width: 1280,
    height: 720,
    child: MasterDetailScaffold(
      mode: ReadingPaneMode.always,
      master: _MasterDetailMasterSample(),
      detail: _MasterDetailDetailSample(),
      emptyState: _MasterDetailEmptySample(),
    ),
  );
}

Widget masterDetailScaffoldOnClickUseCase(BuildContext context) {
  return const SizedBox(
    width: 1280,
    height: 720,
    child: MasterDetailScaffold(
      mode: ReadingPaneMode.onClick,
      master: _MasterDetailMasterSample(),
      detail: _MasterDetailDetailSample(),
      emptyState: _MasterDetailEmptySample(),
    ),
  );
}

/// A short, scrollable list of cards standing in for the master column.
class _MasterDetailMasterSample extends StatelessWidget {
  const _MasterDetailMasterSample();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    const items = [
      ('Client X — weekly sync', 'Marketing · 2h'),
      ('Design review', 'Product · 4h'),
      ('Sales call — Acme', 'Sales · 1d'),
      ('Workshop notes', 'Product · 1d'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (index, (title, meta)) in items.indexed) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(radius.lg),
              border: Border.all(
                color: index == 0 ? colors.accent : colors.border,
              ),
            ),
            child: ListTile(
              title: Text(title),
              subtitle: Text(meta),
              selected: index == 0,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// The reading-pane content for the selected master row.
class _MasterDetailDetailSample extends StatelessWidget {
  const _MasterDetailDetailSample();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Client X — weekly sync',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Q3 budget approved. Ken to draft the proposal before next week.',
            style: TextStyle(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// The empty reading pane (no selection).
class _MasterDetailEmptySample extends StatelessWidget {
  const _MasterDetailEmptySample();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.list_alt_outlined,
      title: 'Nothing selected',
      message: 'Pick an item on the left to read it here.',
    );
  }
}

// ─── Files (grid + table, #1465) ──────────────────────────────────────────────
//
// CONVERGENCE (DR-000 / DR-003): these stories render the REAL, graduated
// `FilesGrid` / `FilesTable` shipped in
// `package:matome_flutter/features/files/widgets/...` — the same widgets the
// `/files` host screen renders. The proposal mock has been deleted; there is no
// second implementation to drift from. Copy reads `t.files.*`, so the
// Localization addon swaps it between en / ja.

Widget filesGridDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(width: 960, child: FilesGrid(files: _filesSample));
}

Widget filesGridMobileUseCase(BuildContext context) {
  return _UseCaseSurface(width: 380, child: FilesGrid(files: _filesSample));
}

Widget filesTableDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(width: 960, child: FilesTable(files: _filesSample));
}

Widget filesTableMobileUseCase(BuildContext context) {
  return _UseCaseSurface(width: 380, child: FilesTable(files: _filesSample));
}

/// Sample files for the graduated Files stories. Mirrors the DR-003 fixtures:
/// every combination of the three independent relations (matome / space /
/// people) plus their absences (Unfiled / Inbox) — including the load-bearing
/// "Unfiled but in a space" case (voice-memo). Size is null throughout because
/// it is not persisted (#1461), so the widgets render the dash, never a
/// fabricated size.
const _filesSample = <FileRow>[
  FileRow(
    id: 'f1',
    name: 'Q3 roadmap.pdf',
    kind: FileKind.document,
    ext: 'pdf',
    when: '2h',
    whenSort: 100,
    matome: 'Client X — weekly sync',
    space: 'Marketing',
    contacts: ['Ana', 'Ken'],
    rollup: MatomeSyncRollup.cloud,
  ),
  FileRow(
    id: 'f2',
    name: 'Design sync.m4a',
    kind: FileKind.audio,
    ext: 'm4a',
    when: '4h',
    whenSort: 90,
    matome: 'Design review',
    space: 'Product',
    contacts: ['Mika'],
    rollup: MatomeSyncRollup.partial,
    duration: '12:04',
  ),
  FileRow(
    id: 'f3',
    name: 'whiteboard.jpg',
    kind: FileKind.image,
    ext: 'jpg',
    when: '5h',
    whenSort: 80,
    matome: null, // loose → inbox, local-only
    space: null,
    rollup: MatomeSyncRollup.onDevice,
    localOnly: true,
  ),
  FileRow(
    id: 'f5',
    name: 'voice-memo.m4a',
    kind: FileKind.audio,
    ext: 'm4a',
    when: '1d',
    whenSort: 49,
    matome: null, // Unfiled, but filed into a space (space != matome)
    space: 'Personal',
    rollup: MatomeSyncRollup.onDevice,
    duration: '00:48',
  ),
  FileRow(
    id: 'f7',
    name: 'budget.xlsx',
    kind: FileKind.document,
    ext: 'xlsx',
    when: '3d',
    whenSort: 20,
    matome: null, // loose → inbox, local-only
    space: null,
    rollup: MatomeSyncRollup.cloud,
    localOnly: true,
  ),
];

// ─── [Screens]/Files — screen-level catalog (Storybook-parity demo) ─────────────
//
// Proof the catalog can host SCREEN-level nodes the same way Storybook's APPS
// root does: `[Screens]` is a WidgetbookCategory (root), `FilesScreen` the
// WidgetbookComponent (the screen), and each state below is a WidgetbookUseCase
// (one Storybook "story"). It renders the REAL, shipped `FilesScreen` — app-
// first, never a catalog-only reimplementation — and drives its four states
// purely by OVERRIDING the one provider the screen reads,
// `filesForCurrentOwnerProvider`. `settingsStoreProvider` is stubbed in-memory
// so `filesViewProvider` hydrates without touching platform secure storage.
//
// NOTE: `FeatureFlags.masterDetailLayout` is a `bool.fromEnvironment` const →
// false in the catalog (no --dart-define), so these render the shipped flag-OFF
// centred column. The open / overflow-menu callbacks use go_router + Navigator
// and fire only on interaction; the four static states render standalone.

/// Wrap the real [FilesScreen] in a [ProviderScope] that stubs settings storage
/// and applies one per-state override of [filesForCurrentOwnerProvider].
Widget _filesScreenScene(Override filesOverride) {
  return ProviderScope(
    overrides: [
      settingsStoreProvider.overrideWithValue(
        InMemorySettingsStore({'matome.files_view': 'grid'}),
      ),
      filesOverride,
    ],
    child: const FilesScreen(),
  );
}

/// Loaded — the owner has files; the grid renders every relation combination
/// (the DR-003 fixtures). The default state a returning user sees.
Widget filesScreenLoadedUseCase(BuildContext context) {
  return _filesScreenScene(
    filesForCurrentOwnerProvider.overrideWith((ref) async => _filesSample),
  );
}

/// Empty — signed in but no files yet (or none in the active scope); the screen
/// shows the centred empty state, not a spinner or an error row.
Widget filesScreenEmptyUseCase(BuildContext context) {
  return _filesScreenScene(
    filesForCurrentOwnerProvider.overrideWith((ref) async => const <FileRow>[]),
  );
}

/// Loading — the owner's files are still resolving; the screen shows the centred
/// spinner. Modelled with a never-completing fetch.
Widget filesScreenLoadingUseCase(BuildContext context) {
  return _filesScreenScene(
    filesForCurrentOwnerProvider.overrideWith(
      (ref) => Future<List<FileRow>>.delayed(const Duration(days: 365)),
    ),
  );
}

/// Error — the files fetch threw; the screen shows the centred error message
/// instead of the grid. Where the user lands on a failed read.
Widget filesScreenErrorUseCase(BuildContext context) {
  return _filesScreenScene(
    filesForCurrentOwnerProvider.overrideWith(
      (ref) => Future<List<FileRow>>.error('Failed to load files'),
    ),
  );
}

// ─── Files chrome (selection / undo / empty / menu, #1477) ───────────────────
//
// The presentational chrome shipped in
// `package:matome_flutter/features/files/widgets/files_view_shared.dart` — the
// SAME widgets `FilesGrid` / `FilesTable` compose: the bulk-action bar, the undo
// bar, the empty state, the per-file overflow menu, and the muted "no size"
// dash. Strictly props-in / callbacks-out, so each renders standalone here.

Widget filesBulkBarUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 720,
    child: FilesBulkBar(
      count: 3,
      onClear: () {},
      onMove: () {},
      onDownload: () {},
      onDelete: () {},
    ),
  );
}

Widget filesUndoBarUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 720,
    child: FilesUndoBar(
      message: t.files.deletedMsg(n: 3),
      onUndo: () {},
      onDismiss: () {},
    ),
  );
}

Widget filesEmptyStateUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 480, child: FilesEmptyState());
}

Widget filesMutedDashUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 240, child: FilesMutedDash());
}

Widget filesFileActionsMenuUseCase(BuildContext context) {
  // The shared files overflow menu (open · move · download · delete). Rendered
  // top-aligned so the popup has room to expand when opened.
  return _UseCaseSurface(
    width: 240,
    child: Align(
      alignment: Alignment.centerLeft,
      child: FileActionsMenu(onAction: (_) {}),
    ),
  );
}

// ─── Details / overflow + auth + audio (#1477) ───────────────────────────────

Widget detailsFileActionsMenuUseCase(BuildContext context) {
  // The Details-screen file overflow ("…") — a single destructive Delete,
  // anchored like the matome actions menu. Both the default and the [dense]
  // (list-row) trigger are shown.
  return _UseCaseSurface(
    width: 240,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        details_actions.FileActionsMenu(onDelete: () {}),
        details_actions.FileActionsMenu(onDelete: () {}, dense: true),
      ],
    ),
  );
}

Widget matomeActionsMenuUseCase(BuildContext context) {
  // Matome-level secondary actions (rename · edit · regenerate · move · share
  // (soon) · copy · archive), default and [dense] triggers.
  return _UseCaseSurface(
    width: 240,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        MatomeActionsMenu(onAction: (_) {}),
        MatomeActionsMenu(onAction: (_) {}, dense: true),
      ],
    ),
  );
}

Widget matomeAddFabUseCase(BuildContext context) {
  // The mobile-shell "add" FAB in isolation (also shown in context under
  // [Screens]/Navigation › Mobile dock).
  return const _UseCaseSurface(
    width: 200,
    child: Center(child: MatomeAddFab()),
  );
}

// ─── Auth widgets (#1477) ────────────────────────────────────────────────────
//
// The shared auth primitives shipped in
// `package:matome_flutter/features/auth/auth_widgets.dart`: the responsive
// [AuthScaffold], the labeled [AuthField], and the loading-aware
// [AuthSubmitButton]. (AuthErrorBanner already has a story under [Screens]/
// Design system/Auth.)

Widget authScaffoldUseCase(BuildContext context) {
  return SizedBox(
    height: 560,
    child: AuthScaffold(
      title: t.welcome.signIn,
      onBack: () {},
      children: const [_AuthScaffoldBody()],
    ),
  );
}

Widget authFieldUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthFieldSample());
}

Widget authSubmitButtonUseCase(BuildContext context) {
  return _UseCaseSurface(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSubmitButton(
          label: t.welcome.signIn,
          loading: false,
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        AuthSubmitButton(
          label: t.welcome.signIn,
          loading: true,
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        AuthSubmitButton(
          label: t.welcome.signIn,
          loading: false,
          onPressed: null,
        ),
      ],
    ),
  );
}

// ─── Audio player bar (#1477) ────────────────────────────────────────────────
//
// `AudioPlayerBar` from
// `package:matome_flutter/features/details/audio_player_bar.dart`. It is NOT
// provider-bound — it takes an [AudioSource] plus an INJECTABLE [AudioPlayback]
// (the production factory is for real builds). The catalog injects a tiny fake
// playback so the "playing" surface renders deterministically with no engine,
// and renders the graceful "unavailable" state from `AudioSource.none()`.

Widget audioPlayerBarPlayingUseCase(BuildContext context) {
  return _UseCaseSurface(
    child: AudioPlayerBar(
      source: const AudioSource(AudioSourceKind.remoteUrl, 'sample://clip'),
      player: _FakeAudioPlayback(
        duration: const Duration(minutes: 12, seconds: 4),
        position: const Duration(minutes: 3, seconds: 18),
        playing: true,
      ),
    ),
  );
}

Widget audioPlayerBarUnavailableUseCase(BuildContext context) {
  // No playable source resolved → the graceful "audio unavailable" surface.
  return const _UseCaseSurface(
    child: AudioPlayerBar(source: AudioSource.none()),
  );
}

Widget fileViewAudioReadyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioReady);
}

Widget fileViewAudioProcessingUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioProcessing);
}

Widget fileViewAudioFailedUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioFailed);
}

Widget fileViewAudioEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioEmpty);
}

Widget fileViewImageReadyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.imageReady);
}

Widget fileViewImageEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.imageEmpty);
}

Widget fileViewNotesFilledUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.notesFilled);
}

Widget fileViewNotesEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.notesEmpty);
}

// ─── Local-first spaces (plan #102, W0) ──────────────────────────────────────
//
// The missing widgets for the local/cloud-space model: the sync-state chip with
// the new `local` state, the inbox entry cards (loose item + draft matome), the
// space tile with promote affordance + the create sync choice, and the files
// scope filter. Presentational, not wired — this is the W0 approval gate.

Widget spaceSyncChipUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 320,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        SpaceSyncChip(state: SpaceSyncState.local),
        SpaceSyncChip(state: SpaceSyncState.promoting),
        SpaceSyncChip(state: SpaceSyncState.cloud),
      ],
    ),
  );
}

Widget inboxItemCardUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 380,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InboxItemCard(
          kind: InboxEntryKind.looseItem,
          icon: Icons.mic_none_rounded,
          title: 'Standup audio',
          meta: '2h · 12:04',
          tagLabel: 'Loose',
          fileLabel: 'File',
        ),
        SizedBox(height: 12),
        InboxItemCard(
          kind: InboxEntryKind.draftMatome,
          title: 'Client X — notes',
          meta: '3 items · 2h',
          tagLabel: 'Draft',
          fileLabel: 'Organize',
        ),
      ],
    ),
  );
}

Widget spaceSyncTileUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 380,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpaceSyncTile(
          name: 'Personal',
          meta: '4 matomes',
          state: SpaceSyncState.local,
          promoteLabel: 'Turn on sync',
          onPromote: () {},
        ),
        const SizedBox(height: 12),
        const SpaceSyncTile(
          name: 'Marketing',
          meta: '8 matomes',
          state: SpaceSyncState.cloud,
          promoteLabel: 'Turn on sync',
        ),
      ],
    ),
  );
}

Widget spaceSyncChoiceUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 360,
    child: SpaceSyncChoice(
      isLocal: true,
      localLabel: 'Local (this device)',
      cloudLabel: 'Cloud (synced)',
      onChanged: (_) {},
    ),
  );
}

Widget filesScopeFilterUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 360,
    child: FilesScopeFilter(
      value: FilesScope.loose,
      allLabel: 'All',
      looseLabel: 'Loose',
      inSpaceLabel: 'In a space',
      onChanged: (_) {},
    ),
  );
}

// ─── Local-first spaces — assembled SCENES (how the screens look) ────────────
//
// Atoms in isolation don't show the flow; these compose the W0 widgets into
// screen-like mockups so the model reads as a real UI. Still presentational /
// not wired — the live screens map onto these in later waves.

Widget sceneInboxUseCase(BuildContext context) {
  return const _SceneSurface(child: _InboxScene());
}

Widget sceneSpacesUseCase(BuildContext context) {
  return const _SceneSurface(child: _SpacesScene());
}

Widget sceneFilesUseCase(BuildContext context) {
  return const _SceneSurface(child: _FilesScene());
}

Widget sceneNewSpaceSheetUseCase(BuildContext context) {
  return const _SceneSurface(child: _NewSpaceSheetScene());
}

Widget scenePromoteConsentUseCase(BuildContext context) {
  return const _SceneSurface(child: _PromoteConsentScene());
}

/// A phone-width device frame for the scenes: the screen background framed by a
/// rounded border, so a composed scene reads like a real screen.
class _SceneSurface extends StatelessWidget {
  const _SceneSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(radius.lg),
                border: Border.all(color: colors.border),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A scene section header (screen title + optional trailing).
class _SceneHeader extends StatelessWidget {
  const _SceneHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.lg,
        spacing.md,
        spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.display.copyWith(color: colors.textPrimary),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: typography.label.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}

/// The INBOX scene: the unorganized staging — loose items + a draft matome,
/// each local and offering a file/organize affordance.
class _InboxScene extends StatelessWidget {
  const _InboxScene();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SceneHeader(title: 'Inbox', subtitle: '4 to organize'),
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
          child: Column(
            children: const [
              InboxItemCard(
                kind: InboxEntryKind.looseItem,
                icon: Icons.mic_none_rounded,
                title: 'Standup audio',
                meta: '2h · 12:04',
                tagLabel: 'Loose',
                fileLabel: 'File',
              ),
              SizedBox(height: 10),
              InboxItemCard(
                kind: InboxEntryKind.looseItem,
                icon: Icons.image_outlined,
                title: 'whiteboard.png',
                meta: '3h · 1.1 MB',
                tagLabel: 'Loose',
                fileLabel: 'File',
              ),
              SizedBox(height: 10),
              InboxItemCard(
                kind: InboxEntryKind.draftMatome,
                title: 'Client X — notes',
                meta: '3 items · 4h',
                tagLabel: 'Draft',
                fileLabel: 'Organize',
              ),
              SizedBox(height: 10),
              InboxItemCard(
                kind: InboxEntryKind.looseItem,
                icon: Icons.description_outlined,
                title: 'Q3 roadmap.pdf',
                meta: 'yesterday · 2.4 MB',
                tagLabel: 'Loose',
                fileLabel: 'File',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The SPACES scene: spaces with their sync state — a local space offers
/// "turn on sync", a cloud space is synced.
class _SpacesScene extends StatelessWidget {
  const _SpacesScene();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SceneHeader(title: 'Spaces'),
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
          child: Column(
            children: [
              SpaceSyncTile(
                name: 'Personal',
                meta: '4 matomes',
                state: SpaceSyncState.local,
                promoteLabel: 'Turn on sync',
                onPromote: () {},
              ),
              const SizedBox(height: 10),
              const SpaceSyncTile(
                name: 'Marketing',
                meta: '8 matomes',
                state: SpaceSyncState.cloud,
                promoteLabel: 'Turn on sync',
              ),
              const SizedBox(height: 10),
              SpaceSyncTile(
                name: 'Ideas',
                meta: '1 matome',
                state: SpaceSyncState.local,
                promoteLabel: 'Turn on sync',
                onPromote: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The FILES scene: the scope filter over a list of files, showing loose vs
/// in-a-space + each file's sync state.
class _FilesScene extends StatelessWidget {
  const _FilesScene();

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SceneHeader(title: 'Files'),
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.sm),
          child: FilesScopeFilter(
            value: FilesScope.all,
            allLabel: 'All',
            looseLabel: 'Loose',
            inSpaceLabel: 'In a space',
            onChanged: (_) {},
          ),
        ),
        // The REAL FilesGrid (same widget the Files screen ships), composed
        // under the new scope filter — loose rows render the `local` sync state.
        // FilesGrid shrink-wraps (Column+Wrap), so it sizes to its content like
        // the sibling scenes — no fixed height (a pinned box clipped it).
        Padding(
          padding: EdgeInsets.fromLTRB(spacing.md, 0, spacing.md, spacing.lg),
          child: FilesGrid(files: _filesSample),
        ),
      ],
    );
  }
}

/// The NEW SPACE sheet scene: name field + the local/cloud choice (default
/// local) + actions.
class _NewSpaceSheetScene extends StatelessWidget {
  const _NewSpaceSheetScene();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New space',
            style: typography.title.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.md),
          // Name field mock.
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            decoration: BoxDecoration(
              color: colors.subtleFill,
              borderRadius: BorderRadius.circular(radius.md),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'Q4 planning',
              style: typography.bodySmall.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(height: spacing.md),
          Text(
            'Sync',
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: spacing.xs),
          SpaceSyncChoice(
            isLocal: true,
            localLabel: 'Local (this device)',
            cloudLabel: 'Cloud (synced)',
            onChanged: (_) {},
          ),
          SizedBox(height: spacing.xs),
          Text(
            'Local stays on this device until you turn on sync.',
            style: typography.label.copyWith(color: colors.textMuted),
          ),
          SizedBox(height: spacing.lg),
          PrimaryButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onAccent,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// The PROMOTE-TO-CLOUD consent scene: the data-egress moment — what uploads.
class _PromoteConsentScene extends StatelessWidget {
  const _PromoteConsentScene();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: spacing.lg,
                color: colors.accent,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  'Turn on sync for “Personal”?',
                  style: typography.title.copyWith(color: colors.textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            '4 matomes · 12 files will upload to the cloud and sync across your '
            'devices. This can’t be undone.',
            style: typography.bodySmall.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              const SpaceSyncChip(state: SpaceSyncState.local),
              Icon(
                Icons.arrow_forward,
                size: spacing.md,
                color: colors.textMuted,
              ),
              const SpaceSyncChip(state: SpaceSyncState.cloud),
            ],
          ),
          SizedBox(height: spacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppTextButton(onPressed: () {}, child: const Text('Cancel')),
              SizedBox(width: spacing.sm),
              PrimaryButton(
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onAccent,
                ),
                child: const Text('Turn on sync'),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

/// The FileView state matrix rendered in the catalog + shared goldens.
enum _FileViewSample {
  audioReady,
  audioProcessing,
  audioFailed,
  audioEmpty,
  imageReady,
  imageEmpty,
  notesFilled,
  notesEmpty,
}

/// Builds the presentational [FileViewData] for a given catalog sample. Shared
/// verbatim with the alchemist golden suite so the documented states and the
/// regression baseline never drift apart.
FileViewData fileViewSampleData(_FileViewSample sample) {
  return switch (sample) {
    _FileViewSample.audioReady => const FileViewData(
      title: 'Design sync',
      mediaKind: FileMediaKind.audio,
      place: 'Design Lab',
      syncCoreId: 42,
      processingStatus: 'done',
      contentsState: ContentsState.ready,
      contentsText:
          'We locked the file-detail layout: header, meta row, media '
          'header, read-only Contents, then editable Notes. Per-file '
          'Summary is intentionally dropped.',
      notesText: 'Ship the goldens before wiring the host screen.',
    ),
    _FileViewSample.audioProcessing => const FileViewData(
      title: 'Interview notes',
      mediaKind: FileMediaKind.audio,
      place: 'Ideas',
      syncCoreId: 77,
      processingStatus: 'processing',
      contentsState: ContentsState.processing,
    ),
    _FileViewSample.audioFailed => const FileViewData(
      title: 'Retry upload',
      mediaKind: FileMediaKind.audio,
      place: 'Personal',
      processingStatus: 'failed',
      contentsState: ContentsState.failed,
    ),
    _FileViewSample.audioEmpty => const FileViewData(
      title: 'Quiet take',
      mediaKind: FileMediaKind.audio,
      syncCoreId: 12,
      processingStatus: 'done',
      contentsState: ContentsState.empty,
    ),
    _FileViewSample.imageReady => const FileViewData(
      title: 'Whiteboard photo',
      mediaKind: FileMediaKind.image,
      place: 'Design Lab',
      syncCoreId: 91,
      processingStatus: 'done',
      contentsState: ContentsState.ready,
      contentsText:
          'A whiteboard sketch of the recording sync rollup: on-device → '
          'partial → cloud, with the retry path called out in red.',
    ),
    _FileViewSample.imageEmpty => const FileViewData(
      title: 'Reference shot',
      mediaKind: FileMediaKind.image,
      syncCoreId: 105,
      processingStatus: 'done',
      // Image producer is deferred (#1445): no description converges on empty.
      contentsState: ContentsState.empty,
    ),
    _FileViewSample.notesFilled => const FileViewData(
      title: 'Roadmap review',
      mediaKind: FileMediaKind.audio,
      place: 'Work',
      syncCoreId: 7,
      processingStatus: 'done',
      contentsState: ContentsState.ready,
      contentsText:
          'Decisions, owners, and next steps from the product review.',
      notesText:
          'My own follow-ups: ping infra about the staging quota, draft the '
          'rollout note, and book the retro for Friday.',
    ),
    _FileViewSample.notesEmpty => const FileViewData(
      title: 'Fresh capture',
      mediaKind: FileMediaKind.audio,
      syncCoreId: 8,
      processingStatus: 'done',
      contentsState: ContentsState.ready,
      contentsText: 'A short voice memo with the machine transcript attached.',
      // notesText omitted → the editable Notes field renders its hint only.
    ),
  };
}

/// Renders a [FileView] sample inside a bounded, scrollable surface. FileView is
/// a `ListView`, so it needs a tight height; the catalog gives it a phone-ish
/// frame and a real retry handler for the failed state.
class _FileViewSampleWidget extends StatelessWidget {
  const _FileViewSampleWidget({required this.sample});

  final _FileViewSample sample;

  @override
  Widget build(BuildContext context) {
    final data = fileViewSampleData(sample);
    final withRetry = sample == _FileViewSample.audioFailed
        ? FileViewData(
            title: data.title,
            mediaKind: data.mediaKind,
            place: data.place,
            syncCoreId: data.syncCoreId,
            processingStatus: data.processingStatus,
            contentsState: data.contentsState,
            contentsText: data.contentsText,
            notesText: data.notesText,
            onContentsRetry: () {},
          )
        : data;
    return FileView(data: withRetry);
  }
}

class _FileViewSurface extends StatelessWidget {
  const _FileViewSurface({required this.sample});

  final _FileViewSample sample;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: SizedBox(
            height: 640,
            child: _FileViewSampleWidget(sample: sample),
          ),
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

/// The body of the [AuthScaffold] story: the real auth field + submit button so
/// the scaffold is shown doing its actual job (centered, width-constrained,
/// scrollable form column) rather than empty.
class _AuthScaffoldBody extends StatefulWidget {
  const _AuthScaffoldBody();

  @override
  State<_AuthScaffoldBody> createState() => _AuthScaffoldBodyState();
}

class _AuthScaffoldBodyState extends State<_AuthScaffoldBody> {
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
        ),
        const SizedBox(height: 16),
        AuthField(
          controller: _password,
          label: t.auth.password,
          hint: t.auth.passwordPlaceholder,
          obscure: true,
          textInputAction: TextInputAction.done,
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

/// A single [AuthField] (label + obscured sibling) in isolation.
class _AuthFieldSample extends StatefulWidget {
  const _AuthFieldSample();

  @override
  State<_AuthFieldSample> createState() => _AuthFieldSampleState();
}

class _AuthFieldSampleState extends State<_AuthFieldSample> {
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
        ),
        const SizedBox(height: 16),
        AuthField(
          controller: _password,
          label: t.auth.password,
          hint: t.auth.passwordPlaceholder,
          obscure: true,
        ),
      ],
    );
  }
}

/// A tiny in-catalog [AudioPlayback] fake so [AudioPlayerBar]'s "playing" surface
/// renders deterministically with no real engine. It holds a fixed
/// position/duration and a single play/pause snapshot — enough to draw the
/// button, the scrubber and the time labels. Seeks/plays are inert.
class _FakeAudioPlayback implements AudioPlayback {
  _FakeAudioPlayback({
    required Duration duration,
    required Duration position,
    required this.playing,
  }) : _duration = duration,
       _position = position;

  final Duration _duration;
  final Duration _position;

  @override
  final bool playing;

  @override
  Duration get duration => _duration;

  @override
  Duration get position => _position;

  @override
  Stream<PlaybackState> get playerStateStream =>
      Stream<PlaybackState>.value(PlaybackState(playing: playing));

  @override
  Stream<Duration> get positionStream => Stream<Duration>.value(_position);

  @override
  Future<Duration?> setFilePath(String path) async => _duration;

  @override
  Future<Duration?> setUrl(String url) async => _duration;

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {}
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

Widget authNoticeUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 420,
    child: AuthNoticeBanner(message: t.auth.forgotPasswordSent),
  );
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

/// Sample rows for the graduated [MatomeTable] stories — the same fixture the
/// shared goldens render so the catalog and the regression baseline stay in
/// lockstep. (Copy is English; the table reads `t.matome.table.*`, so the
/// Localization addon swaps column labels / chips between en and ja.)
const _matomeTableRows = <MatomeTableRow>[
  MatomeTableRow(
    id: 'r1',
    title: 'Client X — weekly sync',
    summary: 'Q3 budget approved. Ken to draft the proposal before next week.',
    when: '2h',
    whenSort: 100,
    audio: 2,
    image: 1,
    doc: 1,
    people: 2,
    space: 'Marketing',
    rollup: MatomeSyncRollup.cloud,
  ),
  MatomeTableRow(
    id: 'r2',
    title: 'Design review',
    summary: 'Walking through the new onboarding screens with the team.',
    when: '4h',
    whenSort: 90,
    audio: 1,
    image: 0,
    doc: 0,
    people: 1,
    space: null,
    rollup: MatomeSyncRollup.partial,
  ),
  MatomeTableRow(
    id: 'r3',
    title: 'Quick voice memo',
    summary: '',
    when: '5h',
    whenSort: 80,
    audio: 1,
    image: 0,
    doc: 0,
    people: 0,
    space: null,
    rollup: MatomeSyncRollup.onDevice,
  ),
  MatomeTableRow(
    id: 'r4',
    title: 'Sales call — Acme',
    summary: 'Deal slips to next quarter. Revisit the terms in the contract.',
    when: '1d',
    whenSort: 50,
    audio: 1,
    image: 0,
    doc: 2,
    people: 3,
    space: 'Sales',
    rollup: MatomeSyncRollup.cloud,
  ),
  MatomeTableRow(
    id: 'r5',
    title: 'Workshop notes',
    summary: 'Roadmap prioritisation exercise with the whole product team.',
    when: '1d',
    whenSort: 49,
    audio: 3,
    image: 2,
    doc: 0,
    people: 4,
    space: 'Product',
    rollup: MatomeSyncRollup.partial,
  ),
];

class _MatomeSyncChipSample extends StatelessWidget {
  const _MatomeSyncChipSample();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        MatomeSyncChip(rollup: MatomeSyncRollup.cloud),
        MatomeSyncChip(rollup: MatomeSyncRollup.partial),
        MatomeSyncChip(rollup: MatomeSyncRollup.onDevice),
      ],
    );
  }
}

/// A framed Matome panel section with a compact item row and the accent Add row
/// — the approved Details-panel scaffolding (#1458), rendered from the real
/// public `lib/ui` widgets.
class _MatomePanelSectionSample extends StatelessWidget {
  const _MatomePanelSectionSample();

  @override
  Widget build(BuildContext context) {
    return MatomePanelSection(
      label: 'Items · 2',
      showDivider: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          MatomePanelRow(
            icon: Icons.mic_none_rounded,
            title: 'Meeting audio',
            meta: '14:30 · 12:04',
            trailing: MatomeSyncChip(rollup: MatomeSyncRollup.cloud),
          ),
          SizedBox(height: 8),
          MatomePanelRow(
            icon: Icons.description_outlined,
            title: 'Quarterly report',
            meta: '14:55',
            trailing: MatomeSyncChip(rollup: MatomeSyncRollup.onDevice),
          ),
          SizedBox(height: 8),
          MatomePanelAddRow(label: 'Add photo'),
        ],
      ),
    );
  }
}

/// A single compact item row in isolation.
class _MatomePanelRowSample extends StatelessWidget {
  const _MatomePanelRowSample();

  @override
  Widget build(BuildContext context) {
    return const MatomePanelRow(
      icon: Icons.mic_none_rounded,
      title: 'Meeting audio',
      meta: '14:30 · 12:04',
      trailing: MatomeSyncChip(rollup: MatomeSyncRollup.cloud),
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

// ─── Navigation (dock + sidebar, #1466) ───────────────────────────────────────
//
// CONVERGENCE (DR-000 / DR-002): these stories render the REAL, graduated
// `MatomeBottomDock` / `MatomeAddFab` / `MatomeSidebar` shipped in
// `package:matome_flutter/features/shell/widgets/matome_nav.dart`. They are
// presentational — driven by a NavDestinationSpec list + selected/expanded
// props and callbacks. The proposal mock is deleted; there is no second
// implementation to drift from. Labels read the per-tab `t.*.title` + `t.nav.*`,
// so the Localization addon swaps them between en / ja. Satori is excluded by
// the caller (this story), matching the live shell.

/// The visible destinations the shell drives (inbox · calendar · files ·
/// contacts · spaces). Built per-locale so the labels follow the addon.
List<NavDestinationSpec> _navDestinations(BuildContext context) {
  final t = Translations.of(context);
  return [
    NavDestinationSpec(
      id: 'inbox',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox,
      label: t.inbox.title,
    ),
    NavDestinationSpec(
      id: 'calendar',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today,
      label: t.calendar.title,
    ),
    NavDestinationSpec(
      id: 'files',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
      label: t.files.title,
    ),
    NavDestinationSpec(
      id: 'contacts',
      icon: Icons.contacts_outlined,
      selectedIcon: Icons.contacts,
      label: t.contacts.title,
    ),
    NavDestinationSpec(
      id: 'spaces',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: t.spaces.title,
    ),
  ];
}

Widget mobileDockInContextUseCase(BuildContext context) {
  return const _PhoneFrame(child: _MobileNavDemo());
}

Widget mobileDockBareUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 400, child: _BareDock());
}

Widget desktopSidebarExpandedUseCase(BuildContext context) {
  return const _WindowFrame(expanded: true);
}

Widget desktopSidebarCollapsedUseCase(BuildContext context) {
  return const _WindowFrame(expanded: false);
}

/// Interactive mobile preview: faux content + the real dock + the real FAB.
class _MobileNavDemo extends StatefulWidget {
  const _MobileNavDemo();

  @override
  State<_MobileNavDemo> createState() => _MobileNavDemoState();
}

class _MobileNavDemoState extends State<_MobileNavDemo> {
  String _selected = 'inbox';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final dests = _navDestinations(context);
    final title = dests.firstWhere((d) => d.id == _selected).label;

    return Stack(
      children: [
        Positioned.fill(child: _NavFauxContent(title: title)),
        Positioned(
          right: spacing.lg,
          bottom: 84 + spacing.sm,
          child: const MatomeAddFab(),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: spacing.md,
          child: SafeArea(
            top: false,
            child: MatomeBottomDock(
              destinations: dests,
              selectedId: _selected,
              onSelect: (id) => setState(() => _selected = id),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 96,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.background.withValues(alpha: 0),
                    colors.background.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The dock on its own surface (no phone frame) for tweaking spacing / states.
class _BareDock extends StatefulWidget {
  const _BareDock();

  @override
  State<_BareDock> createState() => _BareDockState();
}

class _BareDockState extends State<_BareDock> {
  String _selected = 'inbox';

  @override
  Widget build(BuildContext context) {
    return MatomeBottomDock(
      destinations: _navDestinations(context),
      selectedId: _selected,
      onSelect: (id) => setState(() => _selected = id),
    );
  }
}

/// Desktop preview: the real sidebar beside a faux content pane, with a working
/// collapse toggle and destination selection.
class _WindowFrame extends StatefulWidget {
  const _WindowFrame({required this.expanded});

  final bool expanded;

  @override
  State<_WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<_WindowFrame> {
  late bool _expanded = widget.expanded;
  String _selected = 'inbox';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final dests = _navDestinations(context);
    final title = dests.firstWhere((d) => d.id == _selected).label;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(radius.lg),
                border: Border.all(color: colors.border),
              ),
              child: SizedBox(
                height: 560,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MatomeSidebar(
                      destinations: dests,
                      selectedId: _selected,
                      expanded: _expanded,
                      onSelect: (id) => setState(() => _selected = id),
                      onToggle: () => setState(() => _expanded = !_expanded),
                      onSettings: () {},
                      accountName: 'Mika Tanaka',
                    ),
                    Expanded(child: _NavFauxContent(title: title)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Neutral faux screen body so the nav can be validated in context.
class _NavFauxContent extends StatelessWidget {
  const _NavFauxContent({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      color: colors.background,
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.sm),
          Text(
            title,
            style: typography.title.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.lg),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(context.radius.md),
                  border: Border.all(color: colors.border),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A phone-ish frame for the mobile dock preview.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 360,
            height: 720,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: colors.border, width: 1.5),
            ),
            child: _PreviewViewport(size: const Size(360, 720), child: child),
          ),
        ),
      ),
    );
  }
}
