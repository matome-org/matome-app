// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/auth/auth_widgets.dart';
import 'package:matome_flutter/core/audio/audio_playback.dart';
import 'package:matome_flutter/core/db/file_row.dart';
import 'package:matome_flutter/features/contacts/widgets/contact_detail.dart';
import 'package:matome_flutter/features/contacts/widgets/contact_tile.dart';
import 'package:matome_flutter/features/details/audio_player_bar.dart';
import 'package:matome_flutter/features/details/details_controller.dart'
    show AudioSource, AudioSourceKind;
import 'package:matome_flutter/features/details/file_actions_menu.dart'
    as details_actions;
import 'package:matome_flutter/features/details/file_view.dart';
import 'package:matome_flutter/features/files/widgets/files_grid.dart';
import 'package:matome_flutter/features/files/widgets/files_table.dart';
import 'package:matome_flutter/features/files/widgets/files_view_shared.dart';
import 'package:matome_flutter/features/matome/matome_actions_menu.dart';
import 'package:matome_flutter/features/matome/widgets/matome_table.dart';
import 'package:matome_flutter/features/recordings/recording_ids.dart';
import 'package:matome_flutter/features/shell/widgets/matome_nav.dart';
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
  path: '[Widgets]/Design system/Auth',
)
Widget authFieldsUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthControlsSample());
}

@widgetbook.UseCase(
  name: 'Error + loading',
  type: AuthErrorBanner,
  path: '[Widgets]/Design system/Auth',
)
Widget authFeedbackUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthFeedbackSample());
}

@widgetbook.UseCase(
  name: 'Primary states',
  type: PrimaryButton,
  path: '[Widgets]/Design system/Buttons',
)
Widget primaryButtonsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _PrimaryButtonsSample());
}

@widgetbook.UseCase(
  name: 'Text actions',
  type: AppTextButton,
  path: '[Widgets]/Design system/Buttons',
)
Widget appTextButtonsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _TextButtonsSample());
}

@widgetbook.UseCase(
  name: 'Labeled states',
  type: AppTextField,
  path: '[Widgets]/Design system/Inputs',
)
Widget appTextFieldsUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _TextFieldsSample());
}

@widgetbook.UseCase(
  name: 'Icon + initials',
  type: Avatar,
  path: '[Widgets]/Design system/Avatars',
)
Widget avatarsUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _AvatarsSample());
}

@widgetbook.UseCase(name: 'Done', type: AppCard, path: '[Widgets]/Design system/Cards')
Widget appCardDoneUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.done),
  );
}

@widgetbook.UseCase(
  name: 'Pending upload',
  type: AppCard,
  path: '[Widgets]/Design system/Cards',
)
Widget appCardPendingUploadUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.pendingUpload),
  );
}

@widgetbook.UseCase(name: 'Processing', type: AppCard, path: '[Widgets]/Design system/Cards')
Widget appCardProcessingUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.processing),
  );
}

@widgetbook.UseCase(name: 'Failed', type: AppCard, path: '[Widgets]/Design system/Cards')
Widget appCardFailedUseCase(BuildContext context) {
  return const _UseCaseSurface(
    child: _AppCardSample(state: _CardSampleState.failed),
  );
}

@widgetbook.UseCase(
  name: 'Calendar row',
  type: AppCard,
  path: '[Widgets]/Design system/Cards',
)
Widget appCardCalendarUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _CalendarAppCardSample());
}

@widgetbook.UseCase(
  name: 'Sync states',
  type: StatusBadge,
  path: '[Widgets]/Design system/Status',
)
Widget statusBadgesUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 320, child: _StatusBadgesSample());
}

@widgetbook.UseCase(
  name: 'Sync chip',
  type: MatomeSyncChip,
  path: '[Widgets]/Design system/Status',
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
  path: '[Widgets]/Design system/Panel atoms',
)
Widget matomePanelSectionUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _MatomePanelSectionSample());
}

@widgetbook.UseCase(
  name: 'Item row (icon + meta + sync chip)',
  type: MatomePanelRow,
  path: '[Widgets]/Design system/Panel atoms',
)
Widget matomePanelRowUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 360, child: _MatomePanelRowSample());
}

@widgetbook.UseCase(
  name: 'Add row (accent affordance)',
  type: MatomePanelAddRow,
  path: '[Widgets]/Design system/Panel atoms',
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

// ─── Matome detail — the COMPLETE assembled panel (#1478) ────────────────────
//
// The owner-approved, fully-composed Details panel rendered via the public,
// presentational `MatomeDetailPanel` (Items · People · Space · Notes · Share),
// from `package:matome_flutter/ui/matome_detail_panel.dart` with static sample
// data. The `type:` is `MatomeDetailPanel` so the tree reads "MatomeDetailPanel"
// under [Widgets]/Matome detail — not the atom "MatomePanelSection". The live
// `_MatomeDetails` still composes the section atoms against its providers;
// converging that screen onto this widget is tracked as a follow-up.

@widgetbook.UseCase(
  name: 'Detail panel — filed',
  type: MatomeDetailPanel,
  path: '[Widgets]/Matome detail',
)
Widget detailPanelFiledUseCase(BuildContext context) {
  return const _DetailPanelSurface(child: MatomeDetailPanel(data: _filedPanel));
}

@widgetbook.UseCase(
  name: 'Detail panel — inbox',
  type: MatomeDetailPanel,
  path: '[Widgets]/Matome detail',
)
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

@widgetbook.UseCase(
  name: 'Add people (multi · search)',
  type: RelationshipPicker,
  path: '[Widgets]/Relationship picker',
)
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

@widgetbook.UseCase(
  name: 'File into a space (single)',
  type: RelationshipPicker,
  path: '[Widgets]/Relationship picker',
)
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

@widgetbook.UseCase(
  name: 'Pre-filtered (opened from Add person)',
  type: RelationshipPicker,
  path: '[Widgets]/Relationship picker',
)
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

@widgetbook.UseCase(
  name: 'Add to a matome (Files page · reuse)',
  type: RelationshipPicker,
  path: '[Widgets]/Relationship picker',
)
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

@widgetbook.UseCase(
  name: 'Add files (multi · search)',
  type: RelationshipPicker,
  path: '[Widgets]/Relationship picker',
)
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

@widgetbook.UseCase(
  name: 'Add anything (mixed · type filter)',
  type: RelationshipPicker,
  path: '[Widgets]/Relationship picker',
)
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

@widgetbook.UseCase(
  name: 'Empty (no candidates yet)',
  type: RelationshipPicker,
  path: '[Widgets]/Relationship picker',
)
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

@widgetbook.UseCase(
  name: 'Action list',
  type: AppBottomSheet,
  path: '[Widgets]/Design system/Overlays',
)
Widget appBottomSheetUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _BottomSheetSample());
}

@widgetbook.UseCase(
  name: 'Confirmation',
  type: AppDialog,
  path: '[Widgets]/Design system/Overlays',
)
Widget appDialogUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _DialogSample());
}

@widgetbook.UseCase(
  name: 'Spinner sizes',
  type: LoadingIndicator,
  path: '[Widgets]/Design system/Feedback',
)
Widget loadingIndicatorUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 300, child: _LoadingIndicatorSample());
}

@widgetbook.UseCase(
  name: 'Centered message',
  type: EmptyState,
  path: '[Widgets]/Design system/Feedback',
)
Widget emptyStateUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _EmptyStateSample());
}

@widgetbook.UseCase(
  name: 'Document media header',
  type: FileTypeChip,
  path: '[Widgets]/Design system/File view',
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
  path: '[Widgets]/Design system/Relations',
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
  path: '[Widgets]/Design system/Relations',
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
  path: '[Widgets]/Design system/Relations',
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
  path: '[Widgets]/Design system/Relations',
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
  path: '[Widgets]/Matome table',
)
Widget matomeTableDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(width: 920, child: MatomeTable(rows: _matomeTableRows));
}

@widgetbook.UseCase(
  name: 'Table — selection + bulk bar',
  type: MatomeTable,
  path: '[Widgets]/Matome table',
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
  path: '[Widgets]/Matome table',
)
Widget matomeTableCompactUseCase(BuildContext context) {
  return _UseCaseSurface(width: 380, child: MatomeTable(rows: _matomeTableRows));
}

@widgetbook.UseCase(
  name: 'Table — empty',
  type: MatomeTable,
  path: '[Widgets]/Matome table',
)
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

@widgetbook.UseCase(
  name: 'Detail — desktop',
  type: ContactDetail,
  path: '[Widgets]/Contact detail',
)
Widget contactDetailDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 920,
    child: ContactDetail(contact: _contactDetailFull),
  );
}

@widgetbook.UseCase(
  name: 'Detail — mobile',
  type: ContactDetail,
  path: '[Widgets]/Contact detail',
)
Widget contactDetailMobileUseCase(BuildContext context) {
  return _UseCaseSurface(
    width: 380,
    child: ContactDetail(contact: _contactDetailFull),
  );
}

@widgetbook.UseCase(
  name: 'Detail — sparse (minimal info)',
  type: ContactDetail,
  path: '[Widgets]/Contact detail',
)
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
  notes: 'Met at the Q2 offsite. Owns the billing roadmap; loops in Ken for '
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
        id: 'f1', name: 'Q3 roadmap.pdf', kind: ContactFileKind.document),
    ContactFileRef(
        id: 'f2', name: 'Design sync.m4a', kind: ContactFileKind.audio),
    ContactFileRef(
        id: 'f3', name: 'whiteboard.jpg', kind: ContactFileKind.image),
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

@widgetbook.UseCase(
  name: 'Default',
  type: ContactTile,
  path: '[Widgets]/Contact tile',
)
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

@widgetbook.UseCase(
  name: 'Always (split pane)',
  type: MasterDetailScaffold,
  path: '[Widgets]/Master-detail scaffold',
)
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

@widgetbook.UseCase(
  name: 'On click (split appears once selected)',
  type: MasterDetailScaffold,
  path: '[Widgets]/Master-detail scaffold',
)
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

@widgetbook.UseCase(
  name: 'Grid — desktop',
  type: FilesGrid,
  path: '[Widgets]/Files',
)
Widget filesGridDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(width: 960, child: FilesGrid(files: _filesSample));
}

@widgetbook.UseCase(
  name: 'Grid — mobile',
  type: FilesGrid,
  path: '[Widgets]/Files',
)
Widget filesGridMobileUseCase(BuildContext context) {
  return _UseCaseSurface(width: 380, child: FilesGrid(files: _filesSample));
}

@widgetbook.UseCase(
  name: 'Table — desktop',
  type: FilesTable,
  path: '[Widgets]/Files',
)
Widget filesTableDesktopUseCase(BuildContext context) {
  return _UseCaseSurface(width: 960, child: FilesTable(files: _filesSample));
}

@widgetbook.UseCase(
  name: 'Table — mobile (compact)',
  type: FilesTable,
  path: '[Widgets]/Files',
)
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

// ─── Files chrome (selection / undo / empty / menu, #1477) ───────────────────
//
// The presentational chrome shipped in
// `package:matome_flutter/features/files/widgets/files_view_shared.dart` — the
// SAME widgets `FilesGrid` / `FilesTable` compose: the bulk-action bar, the undo
// bar, the empty state, the per-file overflow menu, and the muted "no size"
// dash. Strictly props-in / callbacks-out, so each renders standalone here.

@widgetbook.UseCase(
  name: 'Bulk bar (selection active)',
  type: FilesBulkBar,
  path: '[Widgets]/Design system/Files chrome',
)
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

@widgetbook.UseCase(
  name: 'Undo bar (after delete)',
  type: FilesUndoBar,
  path: '[Widgets]/Design system/Files chrome',
)
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

@widgetbook.UseCase(
  name: 'Empty state (no files)',
  type: FilesEmptyState,
  path: '[Widgets]/Design system/Files chrome',
)
Widget filesEmptyStateUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 480, child: FilesEmptyState());
}

@widgetbook.UseCase(
  name: 'Muted dash (absent value)',
  type: FilesMutedDash,
  path: '[Widgets]/Design system/Files chrome',
)
Widget filesMutedDashUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 240, child: FilesMutedDash());
}

@widgetbook.UseCase(
  name: 'Per-file overflow menu',
  type: FileActionsMenu,
  path: '[Widgets]/Design system/Files chrome',
)
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

@widgetbook.UseCase(
  name: 'File overflow menu (delete-only)',
  type: FileActionsMenu,
  path: '[Widgets]/Design system/Details',
)
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

@widgetbook.UseCase(
  name: 'Matome overflow menu',
  type: MatomeActionsMenu,
  path: '[Widgets]/Design system/Matome',
)
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

@widgetbook.UseCase(
  name: 'Add FAB',
  type: MatomeAddFab,
  path: '[Widgets]/Design system/Matome',
)
Widget matomeAddFabUseCase(BuildContext context) {
  // The mobile-shell "add" FAB in isolation (also shown in context under
  // [Widgets]/Navigation › Mobile dock).
  return const _UseCaseSurface(width: 200, child: Center(child: MatomeAddFab()));
}

// ─── Auth widgets (#1477) ────────────────────────────────────────────────────
//
// The shared auth primitives shipped in
// `package:matome_flutter/features/auth/auth_widgets.dart`: the responsive
// [AuthScaffold], the labeled [AuthField], and the loading-aware
// [AuthSubmitButton]. (AuthErrorBanner already has a story under [Widgets]/
// Design system/Auth.)

@widgetbook.UseCase(
  name: 'Scaffold (form column + back)',
  type: AuthScaffold,
  path: '[Widgets]/Auth',
)
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

@widgetbook.UseCase(
  name: 'Field (labeled + obscured)',
  type: AuthField,
  path: '[Widgets]/Design system/Auth',
)
Widget authFieldUseCase(BuildContext context) {
  return const _UseCaseSurface(child: _AuthFieldSample());
}

@widgetbook.UseCase(
  name: 'Submit button (idle · loading · disabled)',
  type: AuthSubmitButton,
  path: '[Widgets]/Design system/Auth',
)
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

@widgetbook.UseCase(
  name: 'Player — playing (12:04)',
  type: AudioPlayerBar,
  path: '[Widgets]/Design system/Details',
)
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

@widgetbook.UseCase(
  name: 'Player — unavailable',
  type: AudioPlayerBar,
  path: '[Widgets]/Design system/Details',
)
Widget audioPlayerBarUnavailableUseCase(BuildContext context) {
  // No playable source resolved → the graceful "audio unavailable" surface.
  return const _UseCaseSurface(
    child: AudioPlayerBar(source: AudioSource.none()),
  );
}

@widgetbook.UseCase(
  name: 'Audio — ready (transcript)',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewAudioReadyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioReady);
}

@widgetbook.UseCase(
  name: 'Audio — processing',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewAudioProcessingUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioProcessing);
}

@widgetbook.UseCase(
  name: 'Audio — failed',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewAudioFailedUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioFailed);
}

@widgetbook.UseCase(
  name: 'Audio — empty',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewAudioEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.audioEmpty);
}

@widgetbook.UseCase(
  name: 'Image — ready (description)',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewImageReadyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.imageReady);
}

@widgetbook.UseCase(
  name: 'Image — empty',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewImageEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.imageEmpty);
}

@widgetbook.UseCase(
  name: 'Notes — filled',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewNotesFilledUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.notesFilled);
}

@widgetbook.UseCase(
  name: 'Notes — empty',
  type: FileView,
  path: '[Widgets]/File view',
)
Widget fileViewNotesEmptyUseCase(BuildContext context) {
  return const _FileViewSurface(sample: _FileViewSample.notesEmpty);
}

// ─── Local-first spaces (plan #102, W0) ──────────────────────────────────────
//
// The missing widgets for the local/cloud-space model: the sync-state chip with
// the new `local` state, the inbox entry cards (loose item + draft matome), the
// space tile with promote affordance + the create sync choice, and the files
// scope filter. Presentational, not wired — this is the W0 approval gate.

@widgetbook.UseCase(
  name: 'Sync chip (local · promoting · cloud)',
  type: SpaceSyncChip,
  path: '[Widgets]/Local-first spaces',
)
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

@widgetbook.UseCase(
  name: 'Inbox entry (loose item · draft matome)',
  type: InboxItemCard,
  path: '[Widgets]/Local-first spaces',
)
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

@widgetbook.UseCase(
  name: 'Space tile (local + promote · cloud)',
  type: SpaceSyncTile,
  path: '[Widgets]/Local-first spaces',
)
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

@widgetbook.UseCase(
  name: 'Create sync choice (local default)',
  type: SpaceSyncChoice,
  path: '[Widgets]/Local-first spaces',
)
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

@widgetbook.UseCase(
  name: 'Files scope filter (All · Loose · In a space)',
  type: FilesScopeFilter,
  path: '[Widgets]/Local-first spaces',
)
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

@widgetbook.UseCase(
  name: 'Scene — Inbox (loose items + draft matomes)',
  type: InboxItemCard,
  path: '[Widgets]/Local-first spaces',
)
Widget sceneInboxUseCase(BuildContext context) {
  return const _SceneSurface(child: _InboxScene());
}

@widgetbook.UseCase(
  name: 'Scene — Spaces (local / cloud + promote)',
  type: SpaceSyncTile,
  path: '[Widgets]/Local-first spaces',
)
Widget sceneSpacesUseCase(BuildContext context) {
  return const _SceneSurface(child: _SpacesScene());
}

@widgetbook.UseCase(
  name: 'Scene — Files (scope filter)',
  type: FilesScopeFilter,
  path: '[Widgets]/Local-first spaces',
)
Widget sceneFilesUseCase(BuildContext context) {
  return const _SceneSurface(child: _FilesScene());
}

@widgetbook.UseCase(
  name: 'Scene — New space sheet (local default)',
  type: SpaceSyncChoice,
  path: '[Widgets]/Local-first spaces',
)
Widget sceneNewSpaceSheetUseCase(BuildContext context) {
  return const _SceneSurface(child: _NewSpaceSheetScene());
}

@widgetbook.UseCase(
  name: 'Scene — Promote to cloud consent',
  type: SpaceSyncChip,
  path: '[Widgets]/Local-first spaces',
)
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
      padding: EdgeInsets.fromLTRB(spacing.md, spacing.lg, spacing.md, spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: typography.display.copyWith(color: colors.textPrimary)),
          if (subtitle != null)
            Text(subtitle!,
                style: typography.label.copyWith(color: colors.textSecondary)),
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
          Text('New space',
              style: typography.title.copyWith(color: colors.textPrimary)),
          SizedBox(height: spacing.md),
          // Name field mock.
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: spacing.md, vertical: spacing.sm),
            decoration: BoxDecoration(
              color: colors.subtleFill,
              borderRadius: BorderRadius.circular(radius.md),
              border: Border.all(color: colors.border),
            ),
            child: Text('Q4 planning',
                style:
                    typography.bodySmall.copyWith(color: colors.textPrimary)),
          ),
          SizedBox(height: spacing.md),
          Text('Sync',
              style: typography.label.copyWith(color: colors.textMuted)),
          SizedBox(height: spacing.xs),
          SpaceSyncChoice(
            isLocal: true,
            localLabel: 'Local (this device)',
            cloudLabel: 'Cloud (synced)',
            onChanged: (_) {},
          ),
          SizedBox(height: spacing.xs),
          Text('Local stays on this device until you turn on sync.',
              style: typography.label.copyWith(color: colors.textMuted)),
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
              Icon(Icons.cloud_upload_outlined,
                  size: spacing.lg, color: colors.accent),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text('Turn on sync for “Personal”?',
                    style:
                        typography.title.copyWith(color: colors.textPrimary)),
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
              Icon(Icons.arrow_forward, size: spacing.md, color: colors.textMuted),
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
  })  : _duration = duration,
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

@widgetbook.UseCase(
  name: 'Mobile dock — in context',
  type: MatomeBottomDock,
  path: '[Widgets]/Navigation',
)
Widget mobileDockInContextUseCase(BuildContext context) {
  return const _PhoneFrame(child: _MobileNavDemo());
}

@widgetbook.UseCase(
  name: 'Mobile dock — bare',
  type: MatomeBottomDock,
  path: '[Widgets]/Navigation',
)
Widget mobileDockBareUseCase(BuildContext context) {
  return const _UseCaseSurface(width: 400, child: _BareDock());
}

@widgetbook.UseCase(
  name: 'Desktop sidebar — expanded',
  type: MatomeSidebar,
  path: '[Widgets]/Navigation',
)
Widget desktopSidebarExpandedUseCase(BuildContext context) {
  return const _WindowFrame(expanded: true);
}

@widgetbook.UseCase(
  name: 'Desktop sidebar — collapsed (rail)',
  type: MatomeSidebar,
  path: '[Widgets]/Navigation',
)
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
          Text(title, style: typography.title.copyWith(color: colors.textPrimary)),
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
            child: child,
          ),
        ),
      ),
    );
  }
}
