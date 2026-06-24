import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/auth/auth_widgets.dart';
import 'package:matome_flutter/features/contacts/widgets/contact_detail.dart';
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
import 'package:matome_flutter/ui/master_detail_scaffold.dart';
import 'package:matome_flutter/ui/matome_detail_panel.dart';
import 'package:matome_flutter/ui/files_scope_filter.dart';
import 'package:matome_flutter/ui/inbox_item_card.dart';
import 'package:matome_flutter/ui/people_cluster.dart';
import 'package:matome_flutter/ui/relationship_picker.dart';
import 'package:matome_flutter/ui/space_sync_chip.dart';
import 'package:matome_flutter/ui/space_sync_tile.dart';
import 'package:matome_flutter/ui/role_chip.dart';
import 'package:matome_flutter/ui/space_chip.dart';
import 'package:matome_flutter/ui/status_badge.dart';

void main() {
  group('shared widget goldens', () {
    for (final variant in _variants) {
      goldenTest(
        'renders ${variant.label}',
        fileName: 'shared_widgets_${variant.fileSuffix}',
        constraints: const BoxConstraints.tightFor(width: 1040, height: 1600),
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
                  name: 'catalog primary buttons',
                  child: _PrimaryButtonsSample(),
                ),
                GoldenTestScenario(
                  name: 'catalog text buttons',
                  child: _TextButtonsSample(),
                ),
                GoldenTestScenario(
                  name: 'catalog text fields',
                  child: _TextFieldsSample(),
                ),
                GoldenTestScenario(
                  name: 'catalog avatars',
                  child: _AvatarsSample(),
                ),
                GoldenTestScenario(
                  name: 'app card - done',
                  child: _AppCardSample(state: _CardSampleState.done),
                ),
                GoldenTestScenario(
                  name: 'app card - pending upload',
                  child: _AppCardSample(state: _CardSampleState.pendingUpload),
                ),
                GoldenTestScenario(
                  name: 'app card - processing',
                  child: _AppCardSample(state: _CardSampleState.processing),
                ),
                GoldenTestScenario(
                  name: 'app card - failed',
                  child: _AppCardSample(state: _CardSampleState.failed),
                ),
                GoldenTestScenario(
                  name: 'app card - calendar row',
                  child: _CalendarAppCardSample(),
                ),
                GoldenTestScenario(
                  name: 'status badges',
                  child: _StatusBadgesSample(),
                ),
                GoldenTestScenario(
                  name: 'matome sync chip',
                  child: _MatomeSyncChipSample(),
                ),
                GoldenTestScenario(
                  name: 'matome detail panel sections',
                  child: _MatomeDetailPanelSample(),
                ),
                GoldenTestScenario(
                  name: 'matome detail panel (assembled)',
                  child: _MatomeDetailPanelAssembledSample(),
                ),
                GoldenTestScenario(
                  name: 'bottom sheet shell',
                  child: _BottomSheetSample(),
                ),
                GoldenTestScenario(
                  name: 'dialog shell',
                  child: _DialogSample(),
                ),
                GoldenTestScenario(
                  name: 'loading indicators',
                  child: _LoadingIndicatorSample(),
                ),
                GoldenTestScenario(
                  name: 'empty state',
                  child: _EmptyStateSample(),
                ),
                GoldenTestScenario(
                  name: 'file type chip',
                  child: _FileTypeChipSample(),
                ),
                GoldenTestScenario(
                  name: 'relation atoms',
                  child: _RelationAtomsSample(),
                ),
                GoldenTestScenario(
                  name: 'relationship picker (link · multi)',
                  child: _RelationshipPickerSample(),
                ),
                GoldenTestScenario(
                  name: 'relationship picker (mixed · filter)',
                  child: _RelationshipPickerMixedSample(),
                ),
                GoldenTestScenario(
                  name: 'local-first spaces (W0 widgets)',
                  child: _LocalFirstSpacesSample(),
                ),
              ],
            ),
          );
        },
      );
    }
  });

  group('matome table goldens (desktop)', () {
    for (final variant in _variants) {
      goldenTest(
        'renders ${variant.label}',
        fileName: 'matome_table_desktop_${variant.fileSuffix}',
        constraints: const BoxConstraints.tightFor(width: 980, height: 920),
        pumpBeforeTest: pumpOnce,
        builder: () {
          LocaleSettings.setLocaleSync(variant.locale);
          return _GoldenApp(
            variant: variant,
            child: GoldenTestGroup(
              columns: 1,
              children: [
                GoldenTestScenario(
                  name: 'sortable',
                  child: const _TableFrame(
                    height: 480,
                    child: MatomeTable(rows: _matomeTableRows),
                  ),
                ),
                GoldenTestScenario(
                  name: 'selection + bulk bar',
                  child: const _TableFrame(
                    height: 560,
                    child: MatomeTable(
                      rows: _matomeTableRows,
                      initialSelection: {'r1', 'r4'},
                    ),
                  ),
                ),
                GoldenTestScenario(
                  name: 'empty',
                  child: const _TableFrame(
                    height: 180,
                    child: MatomeTable(rows: []),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  });

  group('matome table goldens (compact)', () {
    for (final variant in _variants) {
      goldenTest(
        'renders ${variant.label}',
        fileName: 'matome_table_compact_${variant.fileSuffix}',
        constraints: const BoxConstraints.tightFor(width: 440, height: 760),
        pumpBeforeTest: pumpOnce,
        builder: () {
          LocaleSettings.setLocaleSync(variant.locale);
          return _GoldenApp(
            variant: variant,
            child: GoldenTestGroup(
              columns: 1,
              children: [
                GoldenTestScenario(
                  name: 'mobile rows + sort selector',
                  child: const _TableFrame(
                    width: 360,
                    height: 720,
                    child: MatomeTable(rows: _matomeTableRows),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  });

  group('contact detail goldens', () {
    for (final variant in _variants) {
      goldenTest(
        'renders ${variant.label}',
        fileName: 'contact_detail_${variant.fileSuffix}',
        constraints: const BoxConstraints.tightFor(width: 1000, height: 2280),
        pumpBeforeTest: pumpOnce,
        builder: () {
          LocaleSettings.setLocaleSync(variant.locale);
          return _GoldenApp(
            variant: variant,
            child: GoldenTestGroup(
              columns: 1,
              children: [
                GoldenTestScenario(
                  name: 'detail - desktop (full)',
                  child: const _TableFrame(
                    width: 920,
                    height: 640,
                    child: ContactDetail(contact: _contactDetailFull),
                  ),
                ),
                GoldenTestScenario(
                  name: 'detail - sparse (minimal)',
                  child: const _TableFrame(
                    width: 920,
                    height: 420,
                    child: ContactDetail(contact: _contactDetailSparse),
                  ),
                ),
                GoldenTestScenario(
                  name: 'detail - mobile (stacked)',
                  child: const _TableFrame(
                    width: 380,
                    height: 1080,
                    child: ContactDetail(contact: _contactDetailFull),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  });

  group('master-detail scaffold goldens', () {
    for (final variant in _variants) {
      goldenTest(
        'renders ${variant.label}',
        fileName: 'master_detail_scaffold_${variant.fileSuffix}',
        // Width >= 1024 so the WidthClass is `expanded` and the reading pane is
        // actually shown (master + detail side-by-side), which is the layout
        // decision this scaffold owns.
        constraints: const BoxConstraints.tightFor(width: 1280, height: 560),
        pumpBeforeTest: pumpOnce,
        builder: () {
          LocaleSettings.setLocaleSync(variant.locale);
          return _GoldenApp(
            variant: variant,
            child: GoldenTestGroup(
              columns: 1,
              children: [
                GoldenTestScenario(
                  name: 'right pane (expanded)',
                  child: const SizedBox(
                    width: 1200,
                    height: 480,
                    child: MasterDetailScaffold(
                      mode: ReadingPaneMode.always,
                      master: _MasterDetailMasterSample(),
                      detail: _MasterDetailDetailSample(),
                      emptyState: _MasterDetailEmptySample(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  });

  group('file view goldens', () {
    for (final variant in _variants) {
      goldenTest(
        'renders ${variant.label}',
        fileName: 'file_view_${variant.fileSuffix}',
        constraints: const BoxConstraints.tightFor(width: 940, height: 1480),
        pumpBeforeTest: pumpOnce,
        builder: () {
          LocaleSettings.setLocaleSync(variant.locale);
          return _GoldenApp(
            variant: variant,
            child: GoldenTestGroup(
              columns: 2,
              scenarioConstraints: const BoxConstraints.tightFor(
                width: 420,
                height: 680,
              ),
              children: [
                for (final sample in _FileViewSample.values)
                  GoldenTestScenario(
                    name: sample.scenarioName,
                    child: _FileViewSampleWidget(sample: sample),
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

/// Golden for the owner-APPROVED Matome Details-panel scaffolding (#1458): the
/// public `lib/ui/matome_detail_panel.dart` section widgets the live screen AND
/// the Widgetbook "Detail panel" use case both render — one labeled, framed
/// section with a compact item row (leading icon · title · meta · trailing sync
/// chip) and the accent Add row.
class _MatomeDetailPanelSample extends StatelessWidget {
  const _MatomeDetailPanelSample();

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MatomePanelSection(
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
              // #1475: a SINGLE accent "Add item" affordance (the approved
              // proposal), not the old split "Add photo / Add file" header.
              MatomePanelAddRow(label: 'Add item'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Golden for the COMPLETE, assembled [MatomeDetailPanel] (#1478): the public
/// `lib/ui/matome_detail_panel.dart` widget that composes the section atoms into
/// the full owner-approved panel (Items · People · Space · Notes · Share). This
/// is the same widget the Widgetbook "Detail panel" use-cases render. Pins the
/// FILED state (folder + Refile); the inbox variant differs only in the Space
/// row and is covered by the catalog.
class _MatomeDetailPanelAssembledSample extends StatelessWidget {
  const _MatomeDetailPanelAssembledSample();

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
      child: const MatomeDetailPanel(
        data: MatomeDetailPanelData(
          items: [
            MatomeDetailPanelItem(
              mediaType: 'audio',
              title: 'Meeting audio',
              meta: '14:30 · 12:04',
              onCloud: true,
            ),
            MatomeDetailPanelItem(
              mediaType: 'document',
              title: 'Quarterly report',
              meta: '15:24',
              onCloud: false,
            ),
          ],
          contacts: [
            MatomeDetailPanelContact(
              initial: 'A',
              name: 'Ana',
              role: 'Organizer',
            ),
            MatomeDetailPanelContact(
              initial: 'K',
              name: 'Ken',
              role: 'Attendee',
            ),
          ],
          spaceName: 'Marketing',
          notes: 'Recap the decisions, owners, and next steps.',
        ),
      ),
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

class _FileTypeChipSample extends StatelessWidget {
  const _FileTypeChipSample();

  @override
  Widget build(BuildContext context) {
    // The doc media header across its three icon families: a known doc type
    // (.pdf), a markdown note (.md), and an unknown extension that falls back to
    // the generic file glyph — each with the DISABLED "Open" / "soon" affordance.
    return const Column(
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
    );
  }
}

/// Golden for the shared relationship atoms (#1460): the filled [MatomeChip]
/// vs the outlined [SpaceChip] (and their Unfiled / Inbox empty states), the
/// role-tinted [RoleChip] across organizer / speaker / attendee, and the
/// overlapping [PeopleCluster] with its "+N" overflow. One scenario pins the
/// whole convergence set the Files + Contact views graduate against.
class _RelationAtomsSample extends StatelessWidget {
  const _RelationAtomsSample();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MatomeChip(matome: 'Client X — weekly sync'),
            MatomeChip(),
            SpaceChip(space: 'Marketing'),
            SpaceChip(),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RoleChip(role: MatomeContactRole.organizer),
            RoleChip(role: MatomeContactRole.speaker),
            RoleChip(role: MatomeContactRole.attendee),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            PeopleCluster(names: ['Ana', 'Ken']),
            SizedBox(width: 16),
            PeopleCluster(names: ['Leo', 'Ana', 'Ken', 'Mika', 'Yui']),
          ],
        ),
      ],
    );
  }
}

/// The standard [RelationshipPicker] in its LINK variant — searchable,
/// multi-select, one already-linked candidate, a "Create new" action — framed
/// like the overlay it ships as. Same widget the catalog renders.
class _RelationshipPickerSample extends StatelessWidget {
  const _RelationshipPickerSample();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    // A fixed height so the GoldenTestGroup Table never queries the intrinsic
    // height of the picker's inner ListView (scrollables have none).
    return SizedBox(
      height: 470,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(radius.lg),
          border: Border.all(color: colors.border),
        ),
        child: const RelationshipPicker(
          maxListHeight: 200,
        data: RelationshipPickerData(
          title: 'Add people',
          mode: RelationshipSelectMode.multi,
          searchHint: 'Search contacts',
          actions: [
            RelationshipAction(
              id: 'create',
              label: 'Create new contact',
              icon: Icons.person_add_alt_1_outlined,
            ),
          ],
          candidates: [
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
          ],
          ),
        ),
      ),
    );
  }
}

/// The local-first spaces W0 widgets (plan #102): the sync chip (incl. the new
/// `local` state), inbox entry cards (loose + draft), the space tile with
/// promote + the create sync choice, and the files scope filter.
class _LocalFirstSpacesSample extends StatelessWidget {
  const _LocalFirstSpacesSample();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SpaceSyncChip(state: SpaceSyncState.local),
            SpaceSyncChip(state: SpaceSyncState.promoting),
            SpaceSyncChip(state: SpaceSyncState.cloud),
          ],
        ),
        const SizedBox(height: 12),
        const InboxItemCard(
          kind: InboxEntryKind.looseItem,
          icon: Icons.mic_none_rounded,
          title: 'Standup audio',
          meta: '2h · 12:04',
          tagLabel: 'Loose',
          fileLabel: 'File',
        ),
        const SizedBox(height: 12),
        const InboxItemCard(
          kind: InboxEntryKind.draftMatome,
          title: 'Client X — notes',
          meta: '3 items · 2h',
          tagLabel: 'Draft',
          fileLabel: 'Organize',
        ),
        const SizedBox(height: 12),
        SpaceSyncTile(
          name: 'Personal',
          meta: '4 matomes',
          state: SpaceSyncState.local,
          promoteLabel: 'Turn on sync',
          onPromote: () {},
        ),
        const SizedBox(height: 12),
        SpaceSyncChoice(
          isLocal: true,
          localLabel: 'Local',
          cloudLabel: 'Cloud',
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        FilesScopeFilter(
          value: FilesScope.loose,
          allLabel: 'All',
          looseLabel: 'Loose',
          inSpaceLabel: 'In a space',
          onChanged: (_) {},
        ),
      ],
    );
  }
}

/// The UNIFIED [RelationshipPicker] — cross-entity search (Contacts · Files ·
/// Spaces) with the type-filter chip row. The host's own type is omitted.
class _RelationshipPickerMixedSample extends StatelessWidget {
  const _RelationshipPickerMixedSample();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    return SizedBox(
      height: 520,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(radius.lg),
          border: Border.all(color: colors.border),
        ),
        child: const RelationshipPicker(
          maxListHeight: 220,
          data: RelationshipPickerData(
            title: 'Add to this matome',
            mode: RelationshipSelectMode.multi,
            searchHint: 'Search contacts, files, spaces',
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
                id: 'f1',
                typeId: 'file',
                title: 'Q3 roadmap.pdf',
                subtitle: 'File · PDF · 2.4 MB',
                icon: Icons.picture_as_pdf_outlined,
              ),
              RelationshipCandidate(
                id: 'marketing',
                typeId: 'space',
                title: 'Marketing',
                subtitle: 'Space',
                icon: Icons.folder_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sample rows for the [MatomeTable] goldens — the same fixture the Widgetbook
/// "Matome table" stories render so the catalog and the regression baseline
/// stay in lockstep.
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

/// Sample data for the graduated [ContactDetail] goldens (DR-004 / #1464) — the
/// same fixtures the Widgetbook "Contact detail" stories render so the catalog
/// and the regression baseline stay in lockstep. Copy reads `t.contacts.detail.*`,
/// so the Localization variants swap section labels between en and ja.
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

/// A fixed-size frame for a [MatomeTable] golden scenario. Pinning BOTH
/// dimensions stops alchemist's layout `Table` from querying the table's
/// internal `LayoutBuilder` for intrinsic dimensions (which it cannot provide),
/// and top-aligns the table inside the frame.
class _TableFrame extends StatelessWidget {
  const _TableFrame({
    required this.child,
    this.width = 900,
    required this.height,
  });

  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Align(alignment: Alignment.topCenter, child: child),
    );
  }
}

class _CalendarAppCardSample extends StatelessWidget {
  const _CalendarAppCardSample();

  @override
  Widget build(BuildContext context) {
    return AppCard.calendar(
      id: 'rec_calendar_golden',
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

/// The FileView state matrix pinned by the goldens. Mirrors the catalog use
/// cases in apps/flutter_widgetbook/lib/widgetbook.dart so the documented states
/// and the visual-regression baseline stay in lockstep.
enum _FileViewSample {
  audioReady('audio - ready (transcript)'),
  audioProcessing('audio - processing'),
  audioFailed('audio - failed'),
  audioEmpty('audio - empty'),
  imageReady('image - ready (description)'),
  imageEmpty('image - empty'),
  docChip('doc - file chip'),
  notesFilled('notes - filled'),
  notesEmpty('notes - empty');

  const _FileViewSample(this.scenarioName);

  final String scenarioName;
}

FileViewData _fileViewSampleData(_FileViewSample sample) {
  return switch (sample) {
    _FileViewSample.audioReady => FileViewData(
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
    _FileViewSample.audioFailed => FileViewData(
      title: 'Retry upload',
      mediaKind: FileMediaKind.audio,
      place: 'Personal',
      processingStatus: 'failed',
      contentsState: ContentsState.failed,
      onContentsRetry: () {},
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
      contentsState: ContentsState.empty,
    ),
    _FileViewSample.docChip => const FileViewData(
      title: 'Q3 roadmap.pdf',
      mediaKind: FileMediaKind.doc,
      place: 'Work',
      syncCoreId: 51,
      processingStatus: 'done',
      // The doc media header is supplied by the host as a FileTypeChip; preview
      // is deferred (#1455) and the stub summary converges on the empty state.
      mediaHeader: FileTypeChip(
        fileName: 'Q3 roadmap.pdf',
        extension: 'pdf',
        sizeLabel: '2.4 MB',
      ),
      contentsState: ContentsState.empty,
      notesText: 'Skim the funding section before Thursday.',
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
    ),
  };
}

class _FileViewSampleWidget extends StatelessWidget {
  const _FileViewSampleWidget({required this.sample});

  final _FileViewSample sample;

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
      child: FileView(data: _fileViewSampleData(sample)),
    );
  }
}

/// A short, scrollable list of cards standing in for the [MasterDetailScaffold]
/// master column — mirrors the Widgetbook "Master-detail scaffold" use case so
/// the catalog and the regression baseline stay in lockstep.
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
    return const SizedBox(
      height: 220,
      child: EmptyState(
        icon: Icons.list_alt_outlined,
        title: 'Nothing selected',
        message: 'Pick an item on the left to read it here.',
      ),
    );
  }
}
