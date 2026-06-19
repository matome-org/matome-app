import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/features/spaces/space_detail_controller.dart';

/// Lifecycle test for the Space detail family (#814): the family is
/// `autoDispose`, so the per-workspaceId notifier is torn down once nothing
/// watches it — no leak of one notifier per visited space.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('family is autoDispose: notifier disposes when no longer watched',
      () async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final work = await db.workspacesDao.createWorkspace('Work');
    final provider = spaceDetailControllerProvider(work.id);

    // Subscribe (so the autoDispose provider is created + kept alive) and grab
    // the concrete notifier instance.
    final sub = container.listen(provider, (_, _) {});
    final notifier = container.read(provider.notifier);
    expect(notifier.mounted, isTrue);

    // Drop the only listener: an autoDispose family must tear the notifier
    // down. A plain `.family` (the pre-fix bug) would keep it mounted for the
    // container's lifetime, leaking one notifier per visited workspaceId.
    sub.close();
    await Future<void>.delayed(Duration.zero);

    expect(
      notifier.mounted,
      isFalse,
      reason: 'autoDispose family should dispose the notifier when unwatched',
    );
  });
}
