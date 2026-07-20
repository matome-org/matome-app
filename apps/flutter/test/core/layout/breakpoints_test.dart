import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matome_flutter/core/layout/breakpoints.dart';

void main() {
  group('widthClassFor', () {
    test('width below the medium boundary is compact', () {
      expect(widthClassFor(0), WidthClass.compact);
      expect(widthClassFor(320), WidthClass.compact);
      expect(widthClassFor(599), WidthClass.compact);
    });

    test('exactly the medium boundary (600) is medium', () {
      expect(widthClassFor(kBreakpointMedium), WidthClass.medium);
      expect(widthClassFor(600), WidthClass.medium);
    });

    test('inside the medium band is medium', () {
      expect(widthClassFor(768), WidthClass.medium);
      expect(widthClassFor(1023), WidthClass.medium);
    });

    test('exactly the expanded boundary (1024) is expanded', () {
      expect(widthClassFor(kBreakpointExpanded), WidthClass.expanded);
      expect(widthClassFor(1024), WidthClass.expanded);
    });

    test('above the expanded boundary is expanded', () {
      expect(widthClassFor(1440), WidthClass.expanded);
      expect(widthClassFor(2560), WidthClass.expanded);
    });
  });

  group('BuildContext.widthClass', () {
    Future<WidthClass> resolve(WidgetTester tester, double width) async {
      late WidthClass observed;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Builder(
            builder: (context) {
              observed = context.widthClass;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return observed;
    }

    testWidgets('reads MediaQuery width and classifies it', (tester) async {
      expect(await resolve(tester, 400), WidthClass.compact);
      expect(await resolve(tester, 600), WidthClass.medium);
      expect(await resolve(tester, 1280), WidthClass.expanded);
    });
  });
}
