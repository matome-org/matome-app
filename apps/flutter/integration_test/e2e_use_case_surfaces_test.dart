import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:matome_flutter/app/screens/settings_screen.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/vault/vault_retention_service.dart';
import 'package:matome_flutter/features/calendar/calendar_screen.dart';
import 'package:matome_flutter/features/contacts/contacts_screen.dart';
import 'package:matome_flutter/features/details/file_detail_screen.dart';
import 'package:matome_flutter/features/files/files_screen.dart';
import 'package:matome_flutter/features/home/home_screen.dart';
import 'package:matome_flutter/features/items/text_item_host.dart';
import 'package:matome_flutter/features/spaces/spaces_screen.dart';
import 'package:matome_flutter/i18n/strings.g.dart';

import '../test/support/fake_media_blob_store.dart';
import '../test/support/item_fixtures.dart';
import 'support/e2e_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late InMemoryTokenStore tokens;
  late FakeMediaBlobStore blobs;

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.en);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tokens = InMemoryTokenStore();
    blobs = FakeMediaBlobStore();
    await tokens.saveTokens(
      accessToken: kE2ESession.accessToken,
      refreshToken: kE2ESession.refreshToken!,
    );
  });

  tearDown(() async {
    await blobs.close();
    await db.close();
  });

  List<Override> overrides() => [
    appDatabaseProvider.overrideWithValue(db),
    mediaBlobStoreProvider.overrideWithValue(blobs),
    tokenStoreProvider.overrideWithValue(tokens),
    settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
    authRepositoryProvider.overrideWithValue(FakeE2EAuthRepository(tokens)),
    vaultSessionProvider.overrideWith(
      (ref) => buildE2EVaultSession(restoreReady: true),
    ),
  ];

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(buildE2EApp(overrides: overrides()));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  }

  testWidgets(
    'UC-06/07: create and open Spaces and Contacts through the shell',
    (tester) async {
      await boot(tester);
      GoRouter.of(tester.element(find.byType(HomeScreen))).go('/spaces');
      await tester.pumpAndSettle();
      expect(find.byType(SpacesScreen), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Research');
      await tester.tap(find.byKey(const ValueKey('create-space-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Research'), findsOneWidget);
      expect(
        (await db.workspacesDao.getWorkspaces()).any(
          (row) => row.name == 'Research',
        ),
        isTrue,
      );

      GoRouter.of(tester.element(find.byType(SpacesScreen))).go('/contacts');
      await tester.pumpAndSettle();
      expect(find.byType(ContactsScreen), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ada Lovelace');
      await tester.tap(find.byKey(const ValueKey('save-contact-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Ada Lovelace'), findsOneWidget);
      final contact = (await db.contactsDao.listContactsForOwner('1')).single;

      await tester.tap(find.byKey(ValueKey('contact-tile-${contact.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('contact-detail-name')), findsOneWidget);
    },
  );

  testWidgets('UC-08/09: Calendar and Files expose persisted user content', (
    tester,
  ) async {
    final now = DateTime.now();
    final timestamp = DateTime(
      now.year,
      now.month,
      now.day,
      9,
    ).millisecondsSinceEpoch;
    await db.matomesDao.create(
      MatomesCompanion.insert(
        id: 'calendar-matome',
        title: 'Today planning',
        happenedAt: timestamp,
        createdAt: timestamp,
      ),
    );
    await insertTestFileItem(
      db,
      id: 'library-video',
      title: 'Launch clip',
      filename: 'launch.mp4',
      mediaType: 'video',
      blobId: null,
      createdAt: timestamp,
    );

    await boot(tester);
    GoRouter.of(tester.element(find.byType(HomeScreen))).go('/calendar');
    await tester.pumpAndSettle();
    expect(find.byType(CalendarScreen), findsOneWidget);
    expect(find.text('Today planning'), findsOneWidget);

    GoRouter.of(tester.element(find.byType(CalendarScreen))).go('/files');
    await tester.pumpAndSettle();
    expect(find.byType(FilesScreen), findsOneWidget);
    expect(find.text('Launch clip'), findsWidgets);
  });

  testWidgets('UC-10: every active Item route dispatches to its typed host', (
    tester,
  ) async {
    for (final media in ['audio', 'image', 'document', 'video']) {
      await insertTestFileItem(
        db,
        id: media,
        title: '$media item',
        filename: media == 'document' ? 'brief.pdf' : '$media.bin',
        mediaType: media,
        blobId: null,
      );
    }
    await insertTestTextItem(db, id: 'text', body: 'Original note');

    await boot(tester);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));

    router.go('/items/audio/audio');
    await tester.pumpAndSettle();
    expect(find.byType(FileDetailScreen), findsOneWidget);
    expect(find.text('audio item'), findsWidgets);

    router.go('/items/image/image');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('file-detail-image-header')),
      findsOneWidget,
    );

    router.go('/items/document/document');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('file-type-chip')), findsOneWidget);

    router.go('/items/video/video');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('file-detail-video-header')),
      findsOneWidget,
    );

    router.go('/items/text/text');
    await tester.pumpAndSettle();
    expect(find.byType(TextItemHost), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('text-item-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('text-item-field')),
      'Updated note',
    );
    await tester.tap(find.byKey(const ValueKey('text-item-save')));
    await tester.pumpAndSettle();
    expect(
      (await db.itemsDao.getById('text', '1'))?.text?.body,
      'Updated note',
    );
  });

  testWidgets(
    'UC-11/12: Settings persist retention and Satori redirects safely',
    (tester) async {
      await boot(tester);
      GoRouter.of(
        tester.element(find.byType(HomeScreen)),
      ).go('/inbox/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      final expire = find.text(t.settings.retentionThirtyDays);
      await tester.scrollUntilVisible(expire, 300);
      await tester.ensureVisible(expire);
      await tester.pumpAndSettle();
      await tester.tap(expire);
      await tester.pumpAndSettle();
      final policy = await ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(vaultRetentionServiceProvider).readPolicy();
      expect(policy.mode, VaultRetentionMode.expireAfterUpload);
      expect(policy.expiryDays, 30);

      GoRouter.of(tester.element(find.byType(SettingsScreen))).go('/satori');
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
}
