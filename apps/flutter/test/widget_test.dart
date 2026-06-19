import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/recording_card.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/inbox_item.dart';
import 'package:matome_flutter/features/recordings/upload_retry_service.dart';

import 'support/fake_inbox.dart';

InboxItem _item({
  required String id,
  required String title,
  String? summary,
  String? notes,
  String badge = 'Inbox',
  bool processing = false,
  DateTime? createdAt,
}) {
  final at = createdAt ?? DateTime.now();
  return InboxItem(
    card: RecordingItem(
      id: id,
      title: title,
      summary: summary,
      timestamp: '9:00 AM',
      duration: '0:30',
      badge: badge,
      notes: notes,
      isProcessing: processing,
      mediaType: 'audio',
      processingStatus: processing ? 'processing' : 'done',
    ),
    createdAt: at.millisecondsSinceEpoch,
  );
}

Widget _pumpHome(AsyncValue<List<InboxItem>> state) {
  return ProviderScope(
    overrides: [
      inboxControllerProvider.overrideWith(
        (ref) => FakeInboxController(ref, state),
      ),
      // HomeScreen starts the W4 auto-retry service on first frame; stub it so
      // this widget test doesn't spin up a real reachability probe / periodic
      // timer (which would leave a pending Timer at teardown).
      uploadRetryServiceProvider.overrideWith((ref) => _NoopRetryService(ref)),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
  );
}

/// No-op retry service: `start()` is inert so the widget test never spins up a
/// reachability probe or a pending periodic timer (which would trip the
/// "Timer still pending after teardown" invariant).
class _NoopRetryService extends UploadRetryService {
  _NoopRetryService(super.ref);

  @override
  Future<void> start() async {}
}

void main() {
  testWidgets('Inbox renders header and grouped recordings from Drift', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([
          _item(
            id: '1',
            title: 'Standup notes',
            summary: 'sync',
            badge: 'Work',
            createdAt: now,
          ),
          _item(
            id: '2',
            title: 'Idea dump',
            badge: 'Ideas',
            createdAt: now.subtract(const Duration(days: 2)),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // Header title is the large "Inbox" heading.
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsOneWidget);
    // Grouped by date: today's item lands under the "TODAY" header.
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('Search filters by title / summary / notes', (tester) async {
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([
          _item(id: '1', title: 'Standup notes', summary: 'weekly sync'),
          _item(id: '2', title: 'Idea dump', notes: 'rocket ideas'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsOneWidget);

    // Search by a token that only appears in the first item's summary.
    await tester.enterText(find.byType(TextField), 'sync');
    await tester.pumpAndSettle();
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsNothing);

    // Search by a token that only appears in the second item's notes.
    await tester.enterText(find.byType(TextField), 'rocket');
    await tester.pumpAndSettle();
    expect(find.text('Standup notes'), findsNothing);
    expect(find.text('Idea dump'), findsOneWidget);
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
