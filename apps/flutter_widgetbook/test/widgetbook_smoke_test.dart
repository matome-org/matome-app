import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/ui/avatar.dart';
import 'package:matome_widgetbook/widgetbook.dart';

void main() {
  testWidgets('Widgetbook shell renders without runtime errors', (tester) async {
    await tester.pumpWidget(const MatomeWidgetbook());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });

  testWidgets('Avatar use case renders without runtime errors', (tester) async {
    await tester.pumpWidget(
      const MatomeWidgetbook(
        initialRoute: '/?path=catalog%2Favatars%2Favatar%2Ficon-%2B-initials',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(Avatar), findsNWidgets(4));
  });
}
