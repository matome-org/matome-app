import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/ui/master_detail_scaffold.dart';

void main() {
  // Stable keys to assert presence/absence of each region in the tree.
  const masterKey = Key('test-master');
  const detailKey = Key('test-detail');
  const emptyKey = Key('test-empty');

  Widget harness({Widget? detail, required ReadingPaneMode mode}) {
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
          mode: mode,
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

  // ── always ────────────────────────────────────────────────────────────────
  testWidgets(
    'always + expanded + detail non-null → master AND detail both render',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: detailWidget(), mode: ReadingPaneMode.always),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(detailKey), findsOneWidget);
      expect(find.byKey(emptyKey), findsNothing);
    },
  );

  testWidgets(
    'always + expanded + detail null → master + emptyState (detail absent)',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: null, mode: ReadingPaneMode.always),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(emptyKey), findsOneWidget);
      expect(find.byKey(detailKey), findsNothing);
    },
  );

  // ── onClick ─────────────────────────────────────────────────────────────--
  testWidgets(
    'onClick + expanded + no selection → master full-width (no pane/empty)',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: null, mode: ReadingPaneMode.onClick),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(emptyKey), findsNothing);
      expect(find.byKey(detailKey), findsNothing);
    },
  );

  testWidgets(
    'onClick + expanded + a selection → split (master + detail)',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: detailWidget(), mode: ReadingPaneMode.onClick),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(detailKey), findsOneWidget);
      expect(find.byKey(emptyKey), findsNothing);
    },
  );

  // ── off ─────────────────────────────────────────────────────────────────--
  testWidgets(
    'off + expanded → master only; pane/detail not in tree',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 1280);
      await tester.pumpWidget(
        harness(detail: detailWidget(), mode: ReadingPaneMode.off),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(detailKey), findsNothing);
      expect(find.byKey(emptyKey), findsNothing);
    },
  );

  // ── width degradation ─────────────────────────────────────────────────────
  testWidgets(
    'compact width + always → master only; pane not in tree',
    (tester) async {
      addTearDown(tester.view.reset);
      setWidth(tester, 400);
      await tester.pumpWidget(
        harness(detail: detailWidget(), mode: ReadingPaneMode.always),
      );

      expect(find.byKey(masterKey), findsOneWidget);
      expect(find.byKey(detailKey), findsNothing);
      expect(find.byKey(emptyKey), findsNothing);
    },
  );

  // ── selectsOnTap matrix ───────────────────────────────────────────────────
  testWidgets(
    'selectsOnTap: true for always/onClick at expanded, false for off; '
    'false at compact for every mode',
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
        MasterDetailScaffold.selectsOnTap(expandedCtx, ReadingPaneMode.always),
        isTrue,
      );
      expect(
        MasterDetailScaffold.selectsOnTap(expandedCtx, ReadingPaneMode.onClick),
        isTrue,
      );
      expect(
        MasterDetailScaffold.selectsOnTap(expandedCtx, ReadingPaneMode.off),
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
        MasterDetailScaffold.selectsOnTap(compactCtx, ReadingPaneMode.always),
        isFalse,
      );
      expect(
        MasterDetailScaffold.selectsOnTap(compactCtx, ReadingPaneMode.onClick),
        isFalse,
      );
      expect(
        MasterDetailScaffold.selectsOnTap(compactCtx, ReadingPaneMode.off),
        isFalse,
      );
    },
  );
}
