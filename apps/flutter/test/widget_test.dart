import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/main.dart';

void main() {
  testWidgets('Lab root boots and shows the wiring banner',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MatomeApp());
    await tester.pump();

    expect(find.textContaining('Flutter Lab'), findsWidgets);
    expect(find.textContaining('API base:'), findsOneWidget);
  });
}
