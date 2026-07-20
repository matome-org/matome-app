import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/inbox_item_card.dart';
import 'package:matome_flutter/ui/relationship_picker.dart';

/// Hero-tag-collision CLASS regression (live bug fixed in c522a42 / a0ebcf3:
/// two default-tagged Heroes coexisting in one navigator threw
/// `multiple heroes share the same tag <…>` on the NEXT hero transition,
/// silently aborting the picker/upload mid-open).
///
/// The bug ONLY manifests when two Heroes share a tag in the SAME tree — so a
/// per-widget golden does not catch it. This file pumps the W3 Inbox card
/// variants (loose item + draft matome) and the triage surface (the shared
/// relationship picker) TOGETHER inside ONE Navigator so any two heroes coexist,
/// then drives a hero transition (open a dialog/route) and asserts NO Hero
/// collision is thrown. It covers the CLASS (every inbox card variant), not a
/// single instance.
void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));

  /// Pump a screen that renders BOTH inbox card variants and (under one
  /// navigator) the triage picker surface for each, so their heroes — and any
  /// FAB/dialog heroes — coexist in a single tree.
  Future<void> pumpInboxWithBothVariants(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        // Two Scaffolds, each with its OWN default-tagged FloatingActionButton,
        // kept ALIVE together (the production bug shape: the nav shell keeps
        // every visited branch alive in an IndexedStack). If the FABs collide on
        // a hero transition this throws — exactly the class we guard.
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              floatingActionButton: FloatingActionButton(
                heroTag: 'inbox-hero-test-fab',
                onPressed: () {},
                child: const Icon(Icons.add),
              ),
              body: ListView(
                children: [
                  // Variant 1 — a LOOSE item card.
                  InboxItemCard(
                    key: const ValueKey('hero-loose'),
                    kind: InboxEntryKind.looseItem,
                    title: 'Loose note',
                    meta: 'Audio · 2h',
                    tagLabel: t.inbox.looseTag,
                    fileLabel: t.inbox.fileAction,
                    onFile: () => showRelationshipPicker(
                      context: context,
                      data: RelationshipPickerData(
                        title: t.inbox.fileIntoSpaceTitle,
                        candidates: const [
                          RelationshipCandidate(id: 'ws_1', title: 'Work'),
                        ],
                      ),
                    ),
                  ),
                  // Variant 2 — a DRAFT matome card.
                  InboxItemCard(
                    key: const ValueKey('hero-draft'),
                    kind: InboxEntryKind.draftMatome,
                    title: 'Draft matome',
                    meta: '3 items',
                    tagLabel: t.inbox.draftTag,
                    fileLabel: t.inbox.organizeAction,
                    onFile: () => showRelationshipPicker(
                      context: context,
                      data: RelationshipPickerData(
                        title: t.inbox.groupIntoMatomeTitle,
                        candidates: const [
                          RelationshipCandidate(id: 'm_1', title: 'Q3 sync'),
                        ],
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
    await tester.pumpAndSettle();
  }

  testWidgets(
    'both inbox card variants coexist in one navigator without a Hero collision',
    (tester) async {
      await pumpInboxWithBothVariants(tester);

      // Both variants are present in the SAME tree.
      expect(find.byKey(const ValueKey('hero-loose')), findsOneWidget);
      expect(find.byKey(const ValueKey('hero-draft')), findsOneWidget);

      // Pumping a tree with two coexisting default-FAB heroes must not throw.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening the triage picker for EACH variant (a hero transition) throws no '
    'Hero collision — the CLASS, not one instance',
    (tester) async {
      await pumpInboxWithBothVariants(tester);

      // Open the LOOSE variant's triage surface — a route push (hero transition)
      // while the draft card + FAB heroes are alive in the same navigator.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('hero-loose')),
          matching: find.text(t.inbox.fileAction),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'loose-variant triage open must not collide on a hero tag',
      );
      // Dismiss the picker.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Open the DRAFT variant's triage surface — another hero transition.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('hero-draft')),
          matching: find.text(t.inbox.organizeAction),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'draft-variant triage open must not collide on a hero tag',
      );
    },
  );
}
