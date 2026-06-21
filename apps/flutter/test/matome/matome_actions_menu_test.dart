import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/matome/matome_actions_menu.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

Widget _host({
  required ValueChanged<MatomeAction> onAction,
  bool dense = false,
}) {
  return TranslationProvider(
    child: MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: Center(
          child: MatomeActionsMenu(onAction: onAction, dense: dense),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('opens the menu and lists all promoted actions', (tester) async {
    await tester.pumpWidget(_host(onAction: (_) {}));
    await tester.tap(find.byKey(const ValueKey('matome-actions-trigger')));
    await tester.pumpAndSettle();

    // The seven actions from the approved story are all present.
    expect(find.byKey(const ValueKey('matome-action-rename')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('matome-action-edit-datetime')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matome-action-regenerate')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('matome-action-move')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-action-share')), findsOneWidget);
    expect(find.byKey(const ValueKey('matome-action-copy')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('matome-action-archive')),
      findsOneWidget,
    );
  });

  testWidgets('archive item uses the neutral "Archive" label (not delete)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(onAction: (_) {}));
    await tester.tap(find.byKey(const ValueKey('matome-actions-trigger')));
    await tester.pumpAndSettle();

    expect(find.text(t.matome.actions.archive), findsOneWidget);
    // The destructive vocabulary is gone — it is a recoverable soft-delete.
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Delete matome'), findsNothing);
  });

  testWidgets('share is disabled with a "soon" affordance', (tester) async {
    MatomeAction? fired;
    await tester.pumpWidget(_host(onAction: (a) => fired = a));
    await tester.tap(find.byKey(const ValueKey('matome-actions-trigger')));
    await tester.pumpAndSettle();

    // The "soon" tag renders alongside the disabled Share item.
    expect(find.text(t.matome.actions.soon), findsOneWidget);

    // Tapping Share does nothing (onPressed == null).
    await tester.tap(find.byKey(const ValueKey('matome-action-share')));
    await tester.pumpAndSettle();
    expect(fired, isNull);
  });

  testWidgets('reports the tapped action through onAction', (tester) async {
    MatomeAction? fired;
    await tester.pumpWidget(_host(onAction: (a) => fired = a));
    await tester.tap(find.byKey(const ValueKey('matome-actions-trigger')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('matome-action-archive')));
    await tester.pumpAndSettle();
    expect(fired, MatomeAction.archive);
  });

  testWidgets('dense variant shrinks the trigger target to 32px', (
    tester,
  ) async {
    await tester.pumpWidget(_host(onAction: (_) {}, dense: true));

    final iconButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('matome-actions-trigger')),
    );
    expect(iconButton.constraints?.minWidth, 32);
    expect(iconButton.constraints?.minHeight, 32);

    // It still opens and lists items.
    await tester.tap(find.byKey(const ValueKey('matome-actions-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('matome-action-copy')), findsOneWidget);
  });
}
