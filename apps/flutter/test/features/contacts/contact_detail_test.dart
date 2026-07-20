import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/contacts/widgets/contact_detail.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/role_chip.dart';
import 'package:matome_flutter/ui/space_chip.dart';

const _full = ContactDetailData(
  id: 'c1',
  name: 'Ana Ribeiro',
  avatarIndex: 2,
  sync: ContactSyncState.synced,
  company: 'Acme Inc.',
  title: 'Product Lead',
  email: 'ana.ribeiro@acme.com',
  phone: '+55 11 99876-5432',
  notes: 'Met at the Q2 offsite. Owns the billing roadmap.',
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
    ),
    ContactMatomeRef(
      id: 'm3',
      title: 'Roadmap review',
      role: MatomeContactRole.speaker,
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
  ],
);

const _sparse = ContactDetailData(
  id: 'c2',
  name: 'Leo',
  avatarIndex: 5,
  sync: ContactSyncState.onDevice,
);

Future<void> _pump(
  WidgetTester tester, {
  ContactDetailData contact = _full,
  double width = 920,
  VoidCallback? onEdit,
  ValueChanged<ContactDetailAction>? onAction,
  ValueChanged<String>? onOpenMatome,
  ValueChanged<String>? onOpenFile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: TranslationProvider(
          child: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: ContactDetail(
                  contact: contact,
                  onEdit: onEdit,
                  onAction: onAction,
                  onOpenMatome: onOpenMatome,
                  onOpenFile: onOpenFile,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  group('ContactDetail structure', () {
    testWidgets('renders the header: name, subtitle, ⋯ actions', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('contact-detail-name')), findsOneWidget);
      expect(find.text('Ana Ribeiro'), findsOneWidget);
      // company · title subtitle.
      expect(find.text('Product Lead · Acme Inc.'), findsOneWidget);
      // Edit is inside the ⋯ menu now — no standalone Edit button up front.
      expect(find.byKey(const ValueKey('contact-detail-edit')), findsNothing);
      expect(
        find.byKey(const ValueKey('contact-detail-actions')),
        findsOneWidget,
      );
    });

    testWidgets('renders identity rows from the Core fields', (tester) async {
      await _pump(tester);
      expect(find.text('ana.ribeiro@acme.com'), findsOneWidget);
      expect(find.text('+55 11 99876-5432'), findsOneWidget);
      expect(find.text('Acme Inc.'), findsWidgets);
    });

    testWidgets('renders all three relationship sections', (tester) async {
      await _pump(tester);
      expect(
        find.byKey(const ValueKey('contact-detail-matomes-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('contact-detail-spaces-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('contact-detail-files-section')),
        findsOneWidget,
      );
    });

    testWidgets('renders a RoleChip per matome with the right role', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(RoleChip), findsNWidgets(3));
      expect(find.byKey(const ValueKey('role-chip-organizer')), findsOneWidget);
      expect(find.byKey(const ValueKey('role-chip-attendee')), findsOneWidget);
      expect(find.byKey(const ValueKey('role-chip-speaker')), findsOneWidget);
    });

    testWidgets('renders a SpaceChip per space', (tester) async {
      await _pump(tester);
      expect(find.byType(SpaceChip), findsNWidgets(2));
      expect(find.text('Marketing'), findsOneWidget);
      expect(find.text('Sales'), findsOneWidget);
    });

    testWidgets(
      'renders the linked files (direct edge ∪ matome-mediated, #1472)',
      (tester) async {
        await _pump(tester);
        expect(find.text('Q3 roadmap.pdf'), findsOneWidget);
        expect(find.text('Design sync.m4a'), findsOneWidget);
      },
    );
  });

  group('ContactDetail callbacks', () {
    testWidgets('Edit (in the ⋯ menu) fires onEdit', (tester) async {
      var edited = 0;
      await _pump(tester, onEdit: () => edited++);
      await tester.tap(find.byKey(const ValueKey('contact-detail-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contact-detail-edit')));
      await tester.pump();
      expect(edited, 1);
    });

    testWidgets('tapping a matome fires onOpenMatome with its id', (
      tester,
    ) async {
      String? opened;
      await _pump(tester, onOpenMatome: (id) => opened = id);
      await tester.tap(find.byKey(const ValueKey('contact-detail-matome-m2')));
      await tester.pump();
      expect(opened, 'm2');
    });

    testWidgets('tapping a file fires onOpenFile with its id', (tester) async {
      String? opened;
      await _pump(tester, onOpenFile: (id) => opened = id);
      await tester.tap(find.byKey(const ValueKey('contact-detail-file-f1')));
      await tester.pump();
      expect(opened, 'f1');
    });

    testWidgets('delete action fires onAction(delete)', (tester) async {
      ContactDetailAction? action;
      await _pump(tester, onAction: (a) => action = a);
      await tester.tap(find.byKey(const ValueKey('contact-detail-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.contacts.detail.delete).last);
      await tester.pump();
      expect(action, ContactDetailAction.delete);
    });
  });

  group('ContactDetail sparse / empty states', () {
    testWidgets('no identity fields shows the Add affordance', (tester) async {
      await _pump(tester, contact: _sparse);
      expect(find.text(t.contacts.detail.addInfo), findsOneWidget);
      expect(find.text('ana.ribeiro@acme.com'), findsNothing);
    });

    testWidgets('no notes shows the empty notes line', (tester) async {
      await _pump(tester, contact: _sparse);
      expect(find.text(t.contacts.detail.notesEmpty), findsOneWidget);
    });

    testWidgets('no relations renders empty dashes, no chips', (tester) async {
      await _pump(tester, contact: _sparse);
      expect(find.byType(RoleChip), findsNothing);
      expect(find.byType(SpaceChip), findsNothing);
      // Three sections each show the muted em-dash placeholder.
      expect(find.text(t.contacts.detail.empty), findsNWidgets(3));
    });

    testWidgets('on-device contact still renders its name', (tester) async {
      await _pump(tester, contact: _sparse);
      expect(find.text('Leo'), findsOneWidget);
    });
  });

  group('ContactDetail responsive', () {
    testWidgets('stacks into one column below the breakpoint', (tester) async {
      await _pump(tester, width: 380);
      // Both columns' sections still render when stacked.
      expect(
        find.byKey(const ValueKey('contact-detail-info-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('contact-detail-files-section')),
        findsOneWidget,
      );
    });
  });
}
