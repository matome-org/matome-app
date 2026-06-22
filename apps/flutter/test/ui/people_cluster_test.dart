import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/people_cluster.dart';

Future<void> _pump(WidgetTester tester, List<String> names) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(body: Center(child: PeopleCluster(names: names))),
    ),
  );
}

void main() {
  group('PeopleCluster', () {
    testWidgets('renders one initial avatar per name (within the cap)', (
      tester,
    ) async {
      await _pump(tester, ['Ana', 'Ken']);

      expect(find.text('A'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
      // No overflow chip when under the cap.
      expect(
        find.byKey(const ValueKey('people-cluster-overflow')),
        findsNothing,
      );
      expect(find.byTooltip('Ana, Ken'), findsOneWidget);
    });

    testWidgets('collapses extra names into a "+N" overflow chip', (
      tester,
    ) async {
      await _pump(tester, ['Leo', 'Ana', 'Ken', 'Mika', 'Yui']);

      // Shows the first maxShown initials + a "+2" overflow (5 - 3 = 2).
      expect(find.text('L'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('people-cluster-overflow')),
        findsOneWidget,
      );
      // The tooltip still lists every name, including the overflowed ones.
      expect(find.byTooltip('Leo, Ana, Ken, Mika, Yui'), findsOneWidget);
    });

    testWidgets('renders nothing for an empty list', (tester) async {
      await _pump(tester, const []);

      expect(find.byKey(const ValueKey('people-cluster')), findsNothing);
      expect(find.byType(Tooltip), findsNothing);
    });
  });
}
