import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/shell/widgets/matome_nav.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

// Sample destinations — mirrors what the shell would build from the visible
// ShellTabs (inbox · calendar · files · contacts · spaces; satori excluded by
// the caller, not the widget).
const _destinations = <NavDestinationSpec>[
  NavDestinationSpec(
    id: 'inbox',
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox,
    label: 'Inbox',
  ),
  NavDestinationSpec(
    id: 'calendar',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    label: 'Calendar',
  ),
  NavDestinationSpec(
    id: 'files',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
    label: 'Files',
  ),
  NavDestinationSpec(
    id: 'contacts',
    icon: Icons.contacts_outlined,
    selectedIcon: Icons.contacts,
    label: 'Contacts',
  ),
  NavDestinationSpec(
    id: 'spaces',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder,
    label: 'Spaces',
  ),
];

Future<void> _pump(WidgetTester tester, Widget child, {double width = 1024}) {
  return tester.pumpWidget(
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
            child: SizedBox(width: width, height: 720, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('MatomeBottomDock', () {
    testWidgets('renders one Semantics(button,selected,label) per destination', (
      tester,
    ) async {
      await _pump(
        tester,
        MatomeBottomDock(
          destinations: _destinations,
          selectedId: 'inbox',
          onSelect: (_) {},
        ),
      );

      for (final dest in _destinations) {
        // `find.bySemanticsLabel` already pins the labelled node; assert the
        // button + selected flags on the resolved SemanticsNode (passing the
        // node, not the finder, sidesteps a describeMismatch bug in the matcher).
        expect(
          tester.getSemantics(find.bySemanticsLabel(dest.label)),
          isSemantics(
            isButton: true,
            hasSelectedState: true,
            isSelected: dest.id == 'inbox',
          ),
          reason: '${dest.label} button + selected state',
        );
      }
    });

    testWidgets('tapping a destination fires onSelect with its id', (
      tester,
    ) async {
      String? picked;
      await _pump(
        tester,
        MatomeBottomDock(
          destinations: _destinations,
          selectedId: 'inbox',
          onSelect: (id) => picked = id,
        ),
      );

      await tester.tap(find.bySemanticsLabel('Files'));
      await tester.pumpAndSettle();
      expect(picked, 'files');
    });

    testWidgets('every destination clears the 48dp tap target', (tester) async {
      await _pump(
        tester,
        MatomeBottomDock(
          destinations: _destinations,
          selectedId: 'inbox',
          onSelect: (_) {},
        ),
      );

      final inkWells = find.descendant(
        of: find.byType(MatomeBottomDock),
        matching: find.byType(InkWell),
      );
      expect(inkWells, findsNWidgets(_destinations.length));
      for (final element in inkWells.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('MatomeAddFab', () {
    testWidgets('has an Add tooltip + button semantics and opens the menu', (
      tester,
    ) async {
      final fired = <NavAddOption>[];
      await _pump(tester, Center(child: MatomeAddFab(onAddOption: fired.add)));

      final t = await AppLocaleUtils.parse('en').build();
      expect(find.byTooltip(t.nav.add), findsOneWidget);

      // Open the add menu.
      await tester.tap(find.byType(MatomeAddFab));
      await tester.pumpAndSettle();

      // All add options are surfaced.
      expect(find.text(t.nav.recordAudio), findsOneWidget);
      expect(find.text(t.nav.addPhoto), findsOneWidget);
      expect(find.text(t.nav.addVideo), findsOneWidget);
      expect(find.text(t.nav.addFile), findsOneWidget);
      expect(find.text(t.nav.recordMeeting), findsOneWidget);

      await tester.tap(find.text(t.nav.addFile));
      await tester.pumpAndSettle();
      expect(fired, [NavAddOption.addFile]);
    });

    testWidgets('FAB clears the 48dp tap target', (tester) async {
      await _pump(tester, Center(child: MatomeAddFab(onAddOption: (_) {})));
      final size = tester.getSize(find.byType(MatomeAddFab));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('MatomeSidebar', () {
    Widget sidebar({
      String selectedId = 'inbox',
      bool expanded = true,
      ValueChanged<String>? onSelect,
      VoidCallback? onToggle,
      ValueChanged<NavAddOption>? onAddOption,
      VoidCallback? onSettings,
    }) {
      // Wrapped in a Row (mirroring the real shell: sidebar + content pane) so
      // the sidebar receives loose width constraints and sizes itself.
      return Row(
        children: [
          MatomeSidebar(
            destinations: _destinations,
            selectedId: selectedId,
            expanded: expanded,
            onSelect: onSelect ?? (_) {},
            onToggle: onToggle ?? () {},
            onAddOption: onAddOption,
            onSettings: onSettings,
            accountName: 'Mika Tanaka',
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      );
    }

    testWidgets('expanded: destination semantics + selection callback', (
      tester,
    ) async {
      String? picked;
      await _pump(tester, sidebar(onSelect: (id) => picked = id));
      await tester.pumpAndSettle();

      for (final dest in _destinations) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(dest.label)),
          isSemantics(
            isButton: true,
            hasSelectedState: true,
            isSelected: dest.id == 'inbox',
          ),
        );
      }

      await tester.tap(find.text('Spaces'));
      await tester.pumpAndSettle();
      expect(picked, 'spaces');
    });

    testWidgets('toggle button fires onToggle', (tester) async {
      var toggled = 0;
      await _pump(tester, sidebar(onToggle: () => toggled++));

      final t = await AppLocaleUtils.parse('en').build();
      await tester.tap(find.byTooltip(t.nav.collapse));
      await tester.pumpAndSettle();
      expect(toggled, 1);
    });

    testWidgets('collapsed rail: destinations + Add carry tooltips', (
      tester,
    ) async {
      await _pump(tester, sidebar(expanded: false));

      final t = await AppLocaleUtils.parse('en').build();
      // Add button tooltip.
      expect(find.byTooltip(t.nav.add), findsWidgets);
      // Each destination's label is its collapsed tooltip.
      expect(find.byTooltip('Inbox'), findsOneWidget);
      expect(find.byTooltip('Spaces'), findsOneWidget);
      // Settings tooltip on the collapsed rail.
      expect(find.byTooltip(t.settings.title), findsOneWidget);
      // Expand tooltip on the toggle.
      expect(find.byTooltip(t.nav.expand), findsOneWidget);
    });

    testWidgets('Add menu fires onAddOption (expanded)', (tester) async {
      final fired = <NavAddOption>[];
      await _pump(tester, sidebar(onAddOption: fired.add));

      final t = await AppLocaleUtils.parse('en').build();
      await tester.tap(find.text(t.nav.add));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.nav.recordMeeting));
      await tester.pumpAndSettle();
      expect(fired, [NavAddOption.recordMeeting]);
    });

    testWidgets('Settings fires onSettings', (tester) async {
      var hits = 0;
      await _pump(tester, sidebar(onSettings: () => hits++));

      final t = await AppLocaleUtils.parse('en').build();
      await tester.tap(find.text(t.settings.title));
      await tester.pumpAndSettle();
      expect(hits, 1);
    });

    testWidgets('expanded vs collapsed widths differ', (tester) async {
      await _pump(tester, sidebar(expanded: true));
      await tester.pumpAndSettle();
      final expandedW = tester.getSize(find.byType(MatomeSidebar)).width;

      await _pump(tester, sidebar(expanded: false));
      await tester.pumpAndSettle();
      final collapsedW = tester.getSize(find.byType(MatomeSidebar)).width;

      expect(expandedW, kSidebarExpandedWidth);
      expect(collapsedW, kSidebarRailWidth);
      expect(expandedW, greaterThan(collapsedW));
    });

    testWidgets('destinations clear the 48dp tap target', (tester) async {
      await _pump(tester, sidebar());
      await tester.pumpAndSettle();
      final inkWells = find.descendant(
        of: find.byType(MatomeSidebar),
        matching: find.byType(InkWell),
      );
      for (final dest in _destinations) {
        final hit = find.ancestor(
          of: find.text(dest.label),
          matching: inkWells,
        );
        expect(hit, findsOneWidget, reason: '${dest.label} tappable');
        expect(tester.getSize(hit).height, greaterThanOrEqualTo(48));
      }
    });
  });
}
