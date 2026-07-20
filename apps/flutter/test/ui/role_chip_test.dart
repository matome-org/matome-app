import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/ui/role_chip.dart';

Future<void> _pump(WidgetTester tester, MatomeContactRole role) async {
  LocaleSettings.setLocaleSync(AppLocale.en);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: TranslationProvider(
          child: Center(child: RoleChip(role: role)),
        ),
      ),
    ),
  );
}

Color _tintOf(WidgetTester tester, MatomeContactRole role) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey('role-chip-${role.name}')),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  group('RoleChip', () {
    testWidgets('renders the organizer label tinted by accentDark', (
      tester,
    ) async {
      await _pump(tester, MatomeContactRole.organizer);

      expect(find.text(t.matome.roleOrganizer), findsOneWidget);
      expect(
        _tintOf(tester, MatomeContactRole.organizer),
        MatomeColors.light.accentDark.withValues(alpha: 0.12),
      );
    });

    testWidgets('renders the speaker label tinted by badgeIdeas', (
      tester,
    ) async {
      await _pump(tester, MatomeContactRole.speaker);

      expect(find.text(t.matome.roleSpeaker), findsOneWidget);
      expect(
        _tintOf(tester, MatomeContactRole.speaker),
        MatomeColors.light.badgeIdeas.withValues(alpha: 0.12),
      );
    });

    testWidgets('renders the attendee label tinted by textSecondary', (
      tester,
    ) async {
      await _pump(tester, MatomeContactRole.attendee);

      expect(find.text(t.matome.roleAttendee), findsOneWidget);
      expect(
        _tintOf(tester, MatomeContactRole.attendee),
        MatomeColors.light.textSecondary.withValues(alpha: 0.12),
      );
    });

    test('fromString parses known roles and defaults unknown to attendee', () {
      expect(
        MatomeContactRole.fromString('organizer'),
        MatomeContactRole.organizer,
      );
      expect(
        MatomeContactRole.fromString('SPEAKER'),
        MatomeContactRole.speaker,
      );
      expect(
        MatomeContactRole.fromString('attendee'),
        MatomeContactRole.attendee,
      );
      expect(MatomeContactRole.fromString(null), MatomeContactRole.attendee);
      expect(
        MatomeContactRole.fromString('something-else'),
        MatomeContactRole.attendee,
      );
    });
  });
}
