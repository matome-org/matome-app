import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/recordings/recording.dart';
import 'package:matome_flutter/features/recordings/recordings_controller.dart';

/// A controller seeded with a fixed list — no HTTP, no live backend.
/// Subclasses the real [RecordingsController] so it satisfies the provider's
/// override type, but replaces [load]/[refresh] so nothing hits the network.
class _FakeRecordingsController extends RecordingsController {
  _FakeRecordingsController(super.ref, this._seed) {
    state = _seed;
  }

  final AsyncValue<List<Recording>> _seed;

  @override
  Future<void> load() async {
    state = _seed;
  }

  @override
  Future<void> refresh() async {
    state = _seed;
  }
}

Recording _rec({
  required int id,
  required String title,
  String? summary,
  String? badge,
  RecordingStatus status = RecordingStatus.done,
  DateTime? insertedAt,
}) {
  return Recording(
    id: id,
    ownerId: 1,
    title: title,
    status: status,
    summary: summary,
    badge: badge,
    insertedAt: insertedAt ?? DateTime.now(),
  );
}

Widget _pumpHome(AsyncValue<List<Recording>> state) {
  return ProviderScope(
    overrides: [
      recordingsControllerProvider.overrideWith(
        (ref) => _FakeRecordingsController(ref, state),
      ),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
  );
}

void main() {
  testWidgets('Home renders header, chips and a list of recordings',
      (tester) async {
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([
          _rec(id: 1, title: 'Standup notes', badge: 'work', summary: 'sync'),
          _rec(id: 2, title: 'Idea dump', badge: 'ideas'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unresolved'), findsOneWidget);
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsOneWidget);
  });

  testWidgets('Filter chip narrows the visible recordings', (tester) async {
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([
          _rec(id: 1, title: 'Standup notes', badge: 'work'),
          _rec(id: 2, title: 'Idea dump', badge: 'ideas'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // Both visible under "All".
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsOneWidget);

    // Tap "Work" -> only the work-badged recording remains.
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsNothing);
  });

  testWidgets('Empty data shows the empty state', (tester) async {
    await tester.pumpWidget(_pumpHome(const AsyncValue.data([])));
    await tester.pumpAndSettle();

    expect(find.text('No recordings yet'), findsOneWidget);
  });

  testWidgets('Loading state shows a spinner', (tester) async {
    await tester.pumpWidget(_pumpHome(const AsyncValue.loading()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
