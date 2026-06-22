// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/auth/auth_widgets.dart';
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/features/matome/widgets/matome_table.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/app_bottom_sheet.dart';
import 'package:matome_flutter/ui/app_button.dart';
import 'package:matome_flutter/ui/app_card.dart';
import 'package:matome_flutter/ui/app_dialog.dart';
import 'package:matome_flutter/ui/app_text_field.dart';
import 'package:matome_flutter/ui/avatar.dart';
import 'package:matome_flutter/ui/empty_state.dart';
import 'package:matome_flutter/ui/file_type_chip.dart';
import 'package:matome_flutter/ui/loading_indicator.dart';
import 'package:matome_flutter/ui/matome_chip.dart';
import 'package:matome_flutter/ui/matome_detail_panel.dart';
import 'package:matome_flutter/ui/people_cluster.dart';
import 'package:matome_flutter/ui/role_chip.dart';
import 'package:matome_flutter/ui/space_chip.dart';
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
  name: 'Sync chip',
  type: MatomeSyncChip,
  path: '[Catalog]/Status',
)
Widget matomeSyncChipUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _MatomeSyncChipSample());
}

// ─── Matome Details panel scaffolding (#1458) ─────────────────────────────────
//
// CONVERGENCE: the catalog renders the REAL, PUBLIC panel widgets shipped in
// `package:matome_flutter/ui/matome_detail_panel.dart` — the SAME widgets the
// live `_MatomeDetails` composes. There is no private mock to drift from.

@widgetbook.UseCase(
  name: 'Section (label + divider)',
  type: MatomePanelSection,
  path: '[Catalog]/Matome panel',
)
Widget matomePanelSectionUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _MatomePanelSectionSample());
}

@widgetbook.UseCase(
  name: 'Item row (icon + meta + sync chip)',
  type: MatomePanelRow,
  path: '[Catalog]/Matome panel',
)
Widget matomePanelRowUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _MatomePanelRowSample());
}

@widgetbook.UseCase(
  name: 'Add row (accent affordance)',
  type: MatomePanelAddRow,
  path: '[Catalog]/Matome panel',
)
Widget matomePanelAddRowUseCase(BuildContext context) {
  return const _UseCaseSurface(
    width: 360,
    child: MatomePanelAddRow(
      icon: Icons.add_photo_alternate_outlined,
      label: 'Add photo',
    ),
  );
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

@widgetbook.UseCase(
  name: 'Document media header',
  type: FileTypeChip,
  path: '[Catalog]/File view',
)
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

@widgetbook.UseCase(
  name: 'Matome chip (filled · Unfiled)',
  type: MatomeChip,
  path: '[Catalog]/Relations',
)
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

@widgetbook.UseCase(
  name: 'Space chip (outlined · Inbox)',
  type: SpaceChip,
  path: '[Catalog]/Relations',
)
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

@widgetbook.UseCase(
  name: 'Role chip (organizer · speaker · attendee)',
  type: RoleChip,
  path: '[Catalog]/Relations',
)
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

@widgetbook.UseCase(
  name: 'People cluster (overlap · +N overflow)',
  type: PeopleCluster,
  path: '[Catalog]/Relations',
)
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

@widgetbook.UseCase(
  name: 'Table — desktop (sortable)',
  type: MatomeTable,
  path: '[Catalog]/Matome table',
)
Widget matomeTableDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(width: 920, child: MatomeTable(rows: _matomeTableRows));
}

@widgetbook.UseCase(
  name: 'Table — selection + bulk bar',
  type: MatomeTable,
  path: '[Catalog]/Matome table',
)
Widget matomeTableSelectionUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 920,
    child: MatomeTable(
      rows: _matomeTableRows,
      initialSelection: const {'r1', 'r4'},
    ),
  );
}

@widgetbook.UseCase(
  name: 'Table — compact (mobile)',
  type: MatomeTable,
  path: '[Catalog]/Matome table',
)
Widget matomeTableCompactUseCase(BuildContext context) {
  return _UseCaseSurface(width: 380, child: MatomeTable(rows: _matomeTableRows));
}

@widgetbook.UseCase(
  name: 'Table — empty',
  type: MatomeTable,
  path: '[Catalog]/Matome table',
)
Widget matomeTableEmptyUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 920, child: MatomeTable(rows: []));
}

@widgetbook.UseCase(
  name: 'Audio — ready (transcript)',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewAudioReadyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioReady);
}

@widgetbook.UseCase(
  name: 'Audio — processing',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewAudioProcessingUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioProcessing);
}

@widgetbook.UseCase(
  name: 'Audio — failed',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewAudioFailedUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioFailed);
}

@widgetbook.UseCase(
  name: 'Audio — empty',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewAudioEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioEmpty);
}

@widgetbook.UseCase(
  name: 'Image — ready (description)',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewImageReadyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.imageReady);
}

@widgetbook.UseCase(
  name: 'Image — empty',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewImageEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.imageEmpty);
}

@widgetbook.UseCase(
  name: 'Notes — filled',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewNotesFilledUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.notesFilled);
}

@widgetbook.UseCase(
  name: 'Notes — empty',
  type: FileView,
  path: '[Catalog]/File view',
)
Widget fileViewNotesEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.notesEmpty);
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
      contentsText: 'Decisions, owners, and next steps from the product review.',
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
