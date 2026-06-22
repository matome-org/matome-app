import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/db/matome_card.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/home/inbox_controller.dart';
import 'package:matome_flutter/features/home/matome_inbox_controller.dart';
import 'package:matome_flutter/features/matome/widgets/matome_table.dart';
import 'package:matome_flutter/features/recordings/upload_retry_service.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import 'support/fake_inbox.dart';

/// Builds a display [MatomeItem] for the Inbox list (#1378). The Inbox now lists
/// **inbox matomes** (spaceId == null), each with a title and item count.
MatomeItem _matome({
  required String id,
  required String title,
  int itemCount = 1,
  DateTime? happenedAt,
}) {
  final at = happenedAt ?? DateTime.now();
  return MatomeItem(
    id: id,
    spaceId: null,
    title: title,
    happenedAt: at.millisecondsSinceEpoch,
    createdAt: at.millisecondsSinceEpoch,
    summaryStale: false,
    recordingCount: itemCount,
    recordings: const [],
  );
}

Widget _pumpHome(AsyncValue<List<MatomeItem>> state, {SettingsStore? store}) {
  return ProviderScope(
    overrides: [
      if (store != null) settingsStoreProvider.overrideWithValue(store),
      matomeInboxControllerProvider.overrideWith(
        (ref) => FakeMatomeInboxController(ref, state),
      ),
      // The matome controller listens to the recording-level inbox controller;
      // stub it so the listen target never builds a real Drift/Core controller.
      inboxControllerProvider.overrideWith(
        (ref) => FakeInboxController(ref, const AsyncValue.data([])),
      ),
      // HomeScreen starts the W4 auto-retry service on first frame; stub it so
      // this widget test doesn't spin up a real reachability probe / periodic
      // timer (which would leave a pending Timer at teardown).
      uploadRetryServiceProvider.overrideWith((ref) => _NoopRetryService(ref)),
    ],
    child: TranslationProvider(
      child: MaterialApp(theme: buildAppTheme(), home: const HomeScreen()),
    ),
  );
}

/// No-op retry service: `start()` is inert so the widget test never spins up a
/// reachability probe or a pending periodic timer.
class _NoopRetryService extends UploadRetryService {
  _NoopRetryService(super.ref);

  @override
  Future<void> start() async {}
}

void main() {
  testWidgets('Inbox renders header and grouped matomes from Drift', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([
          _matome(id: '1', title: 'Standup notes', happenedAt: now),
          _matome(
            id: '2',
            title: 'Idea dump',
            happenedAt: now.subtract(const Duration(days: 2)),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    // Header title is the large "Inbox" heading. (Each inbox matome row now
    // also carries an "Inbox" place chip — #1412 — so scope to the heading.)
    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.text('Inbox'),
      ),
      findsWidgets,
    );
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsOneWidget);
    // Grouped by date: today's item lands under the "TODAY" header.
    expect(find.text('TODAY'), findsOneWidget);
  });

  testWidgets('Search filters matomes by title', (tester) async {
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([
          _matome(id: '1', title: 'Standup notes'),
          _matome(id: '2', title: 'Idea dump'),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsOneWidget);

    // Search by a token that only appears in the first matome's title.
    await tester.enterText(find.byType(TextField), 'standup');
    await tester.pumpAndSettle();
    expect(find.text('Standup notes'), findsOneWidget);
    expect(find.text('Idea dump'), findsNothing);

    // Search by a token that only appears in the second matome's title.
    await tester.enterText(find.byType(TextField), 'idea');
    await tester.pumpAndSettle();
    expect(find.text('Standup notes'), findsNothing);
    expect(find.text('Idea dump'), findsOneWidget);
  });

  testWidgets('Empty data shows the empty state', (tester) async {
    await tester.pumpWidget(_pumpHome(const AsyncValue.data([])));
    await tester.pumpAndSettle();

    expect(find.text(t.inbox.empty), findsOneWidget);
  });

  testWidgets('Loading state shows a spinner', (tester) async {
    await tester.pumpWidget(_pumpHome(const AsyncValue.loading()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // The on-screen inbox view toggle was removed (#1474): Settings is now the
  // single control. The header no longer carries the cards↔table segments.
  testWidgets('no on-screen inbox view toggle in the header', (tester) async {
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([_matome(id: '1', title: 'Standup notes')]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('inbox-view-cards')), findsNothing);
    expect(find.byKey(const ValueKey('inbox-view-table')), findsNothing);
  });

  // The screen still renders whatever view the provider holds, just without an
  // on-screen toggle to change it: a stored "table" preference shows the table.
  testWidgets('renders the table when the provider holds InboxView.table', (
    tester,
  ) async {
    // A wide surface so the columnar MatomeTable lays out without overflowing.
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([_matome(id: '1', title: 'Standup notes')]),
        store: InMemorySettingsStore({'matome.inbox_view': 'table'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatomeTable), findsOneWidget);
    // No on-screen toggle even in table view.
    expect(find.byKey(const ValueKey('inbox-view-table')), findsNothing);
  });

  // The redundant upload + settings affordances were removed from the Inbox
  // (#1474 follow-up): the nav shell's hero "+" Add covers upload (same
  // inboxUploaderProvider pipeline) and the dock/sidebar cover Settings, so the
  // inbox FAB, header upload button, and header settings gear are gone.
  testWidgets('no redundant upload FAB / header upload + settings on Inbox', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([_matome(id: '1', title: 'Standup notes')]),
      ),
    );
    await tester.pumpAndSettle();

    // No upload FloatingActionButton on the inbox (nav shell provides "+").
    expect(find.byType(FloatingActionButton), findsNothing);
    // No header upload affordance.
    expect(find.byTooltip('Upload a file'), findsNothing);
    expect(find.byIcon(Icons.upload_file), findsNothing);
    // No header settings gear (reachable from dock / sidebar instead).
    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byIcon(Icons.settings_outlined),
      ),
      findsNothing,
    );
    expect(find.byTooltip(t.a11y.openSettings), findsNothing);

    // The search field + list stay intact.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Standup notes'), findsOneWidget);
  });

  // The default (cards) view keeps rendering the grouped card list.
  testWidgets('renders the card list when the provider holds InboxView.cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pumpHome(
        AsyncValue.data([_matome(id: '1', title: 'Standup notes')]),
        store: InMemorySettingsStore({'matome.inbox_view': 'cards'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MatomeTable), findsNothing);
    expect(find.text('Standup notes'), findsOneWidget);
  });
}
