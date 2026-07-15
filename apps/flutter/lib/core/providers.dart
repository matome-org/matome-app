import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import '../features/contacts/contacts_repository.dart';
import '../features/matome/matomes_repository.dart';
import '../features/recordings/recordings_repository.dart';
import '../features/spaces/spaces_repository.dart';
import 'config/endpoint_controller.dart';
import 'db/app_database.dart';
import 'http/api_client.dart';
import 'http/api_exception.dart';
import 'http/token_store.dart';
import 'settings/settings_store.dart';

export '../features/auth/current_owner.dart' show currentOwnerIdProvider;

/// Secure token store. Overridden in tests with an in-memory implementation.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Persisted UI preferences store (theme mode + language).
/// Overridden in tests with an in-memory implementation.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SecureSettingsStore(),
);

/// Configured dio-backed API client (with the Bearer interceptor).
///
/// Watches [endpointConfigProvider] so a god-mode host switch rebuilds the
/// client (and every repo watching it) against the new base URL at runtime.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStore: ref.watch(tokenStoreProvider),
    baseUrl: ref.watch(endpointConfigProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final repo = AuthRepository(
    apiClient: apiClient,
    tokenStore: ref.watch(tokenStoreProvider),
  );
  // F4 (#777) follow-up: install the 401-retry interceptor now that the repo
  // (which owns refresh()) exists. On a 401 to any authed call, it refreshes
  // once and retries; on refresh failure it signs the session out so the nav
  // guard bounces the user back to welcome.
  apiClient.attachRefreshInterceptor(
    onRefresh: () async {
      try {
        await repo.refresh();
        return true;
      } on ApiException {
        return false;
      }
    },
    onSignOut: () async {
      ref.read(authControllerProvider.notifier).signedOutByInterceptor();
    },
  );
  return repo;
});

final recordingsRepositoryProvider = Provider<RecordingsRepository>((ref) {
  return RecordingsRepository(apiClient: ref.watch(apiClientProvider));
});

/// HTTP repository for space-scoped Matome sync (task #1377). Overridden in
/// tests with a fake/mock-adapter-backed repo (mirrors recordings).
final matomesRepositoryProvider = Provider<MatomesRepository>((ref) {
  return MatomesRepository(apiClient: ref.watch(apiClientProvider));
});

/// HTTP repository for Contact sync (task #1377). Overridable in tests.
final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(apiClient: ref.watch(apiClientProvider));
});

/// HTTP repository for Space (workspace) Core writes — the `POST /api/spaces`
/// create used by local→cloud promotion (plan #102 W4 / #1499). Overridable in
/// tests with a fake counting repo.
final spacesRepositoryProvider = Provider<SpacesRepository>((ref) {
  return SpacesRepository(apiClient: ref.watch(apiClientProvider));
});

/// Offline-first local store (Drift). Opened once and disposed with the
/// container. Overridable in tests with [AppDatabase.forTesting] over an
/// in-memory NativeDatabase.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Typed DAO providers for the local store — the plain-Dart persistence
/// surface the UI/sync layer (Wave 3) drives.
final itemsDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).itemsDao,
);
final workQueueDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).workQueueDao,
);
final workspacesDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).workspacesDao,
);
final matomesDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).matomesDao,
);
final spacesDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).spacesDao,
);
final recordingDraftsDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).recordingDraftsDao,
);
final contactsDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).contactsDao,
);
