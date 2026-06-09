import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_repository.dart';
import '../features/recordings/recordings_repository.dart';
import 'http/api_client.dart';
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
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final recordingsRepositoryProvider = Provider<RecordingsRepository>((ref) {
  return RecordingsRepository(apiClient: ref.watch(apiClientProvider));
});
