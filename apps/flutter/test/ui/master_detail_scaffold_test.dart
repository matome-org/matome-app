import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

void main() {
  // Stable keys to assert presence/absence of each region in the tree.
  const masterKey = Key('test-master');
  const detailKey = Key('test-detail');
  const emptyKey = Key('test-empty');

  Widget harness({Widget? detail, required ReadingPanePosition pane}) {
    return MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: MasterDetailScaffold(
          master: const ColoredBox(
            key: masterKey,
            color: Color(0xFF112233),
            child: SizedBox.expand(),
          ),
          detail: detail,
          emptyState: const ColoredBox(
            key: emptyKey,
            color: Color(0xFF445566),
            child: SizedBox.expand(),
          ),
          pane: pane,
        ),
      ),
    );
  }

  Widget detailWidget() => const ColoredBox(
        key: detailKey,
        color: Color(0xFF778899),
        child: SizedBox.expand(),
      );

  /// Drives the logical width by setting the physical size at dpr 1.
  void setWidth(WidgetTester tester, double width, [double height = 800]) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, height);
  }

  tearDown(() {
    // tester.view is reset per-test via addTearDown below; this is a safety net.
  });

  testWidgets(
    'Right + expanded + detail non-null → master AND detail both render',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: detailWidget(), pane: ReadingPanePosition.right),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(detailKey), findsOneWidget);
      expect(find.byKey(emptyKey), findsNothing);
    },
  );

  testWidgets(
    'Right + expanded + detail null → master + emptyState (detail absent)',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: null, pane: ReadingPanePosition.right),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(emptyKey), findsOneWidget);
      expect(find.byKey(detailKey), findsNothing);
    },
  );

  testWidgets(
    'Off + expanded → master only; pane/detail not in tree',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: detailWidget(), pane: ReadingPanePosition.off),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(detailKey), findsNothing);
      expect(find.byKey(emptyKey), findsNothing);
    },
  );

  testWidgets(
    'compact width + Right → master only; pane not in tree',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 400);
      await tester.pumpWidget(
        harness(detail: detailWidget(), pane: ReadingPanePosition.right),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(detailKey), findsNothing);
      expect(find.byKey(emptyKey), findsNothing);
    },
  );

  testWidgets(
    'showsPane returns true only for Right + expanded',
    (tester) async {
      addTearDown(tester.view.reset);
      late BuildContext expandedCtx;
      late BuildContext compactCtx;

      setWidth(tester, 1280);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) {
              expandedCtx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        MasterDetailScaffold.showsPane(expandedCtx, ReadingPanePosition.right),
        isTrue,
      );
      expect(
        MasterDetailScaffold.showsPane(expandedCtx, ReadingPanePosition.off),
        isFalse,
      );

      setWidth(tester, 400);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Builder(
            builder: (context) {
              compactCtx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        MasterDetailScaffold.showsPane(compactCtx, ReadingPanePosition.right),
        isFalse,
      );
    },
  );
}
