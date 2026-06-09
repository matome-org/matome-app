import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import '../features/recordings/recordings_repository.dart';
import 'db/app_database.dart';
import 'http/api_client.dart';
import 'http/api_exception.dart';
import 'http/token_store.dart';
import 'settings/settings_store.dart';

/// Secure token store. Overridden in tests with an in-memory implementation.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Persisted UI preferences store (theme mode + language).
/// Overridden in tests with an in-memory implementation.
final settingsStoreProvider =
    Provider<SettingsStore>((ref) => SecureSettingsStore());

/// Configured dio-backed API client (with the Bearer interceptor).
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStore: ref.watch(tokenStoreProvider));
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
final recordingsDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).recordingsDao);
final workspacesDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).workspacesDao);
final recordingDraftsDaoProvider =
    Provider((ref) => ref.watch(appDatabaseProvider).recordingDraftsDao);
