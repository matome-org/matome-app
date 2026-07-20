import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_repository.dart';
import '../features/contacts/contacts_repository.dart';
import '../features/documents/document_external_launcher.dart';
import '../features/documents/document_open_service.dart';
import '../features/matome/matomes_repository.dart';
import '../features/items/item_deletion_service.dart';
import '../features/recordings/recordings_repository.dart';
import '../features/recordings/upload_queue.dart';
import '../features/spaces/spaces_repository.dart';
import 'config/endpoint_controller.dart';
import 'config/system_policy.dart';
import 'db/app_database.dart';
import 'db/db_encryption.dart';
import 'http/api_client.dart';
import 'http/api_exception.dart';
import 'http/token_store.dart';
import 'settings/settings_store.dart';
import 'telemetry/product_event_reporter.dart';
import 'telemetry/device_queue_reporter.dart';
import 'vault/account_device_wrap_gateway.dart';
import 'vault/key_bundle_repository.dart';
import 'vault/media_ingest_service.dart';
import 'vault/vault_session_controller.dart';
import 'vault/vault_boot_coordinator.dart';
import 'vault/vault_retention_service.dart';
import 'vault/vault_export_service.dart';
import 'package:matome_vault/matome_vault.dart';

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

final keyBundleRepositoryProvider = Provider<KeyBundleGateway>((ref) {
  return KeyBundleRepository(apiClient: ref.watch(apiClientProvider));
});

final deviceWrapGatewayProvider = Provider<DeviceWrapGateway?>((ref) {
  if (kIsWeb) return null;
  return AccountDeviceWrapGateway(FlutterSecureKeyStore.deviceKek());
});

final vaultSessionProvider =
    StateNotifierProvider<VaultSessionController, VaultSessionSnapshot>((ref) {
      return VaultSessionController(
        keyBundles: ref.watch(keyBundleRepositoryProvider),
        deviceWraps: ref.watch(deviceWrapGatewayProvider),
        platform: kIsWeb ? VaultPlatform.web : VaultPlatform.native,
        openVault: ref.read(vaultBootCoordinatorProvider.notifier).open,
      );
    });

final systemPolicyProvider =
    StateNotifierProvider<SystemPolicyController, SystemPolicy>((ref) {
      return SystemPolicyController.reading(
        () => ref.read(apiClientProvider),
        ref.watch(settingsStoreProvider),
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
      await ref.read(authControllerProvider.notifier).signedOutByInterceptor();
    },
  );
  return repo;
});

final recordingsRepositoryProvider = Provider<RecordingsRepository>((ref) {
  return RecordingsRepository(apiClient: ref.watch(apiClientProvider));
});

final documentOpenServiceProvider = Provider<DocumentOpenService>((ref) {
  final repository = ref.watch(recordingsRepositoryProvider);
  return DocumentOpenService(
    descriptorSource: repository.documentOpenDescriptor,
    launcher: createExternalDocumentLauncher(),
    environment: currentDocumentOpenEnvironment(),
    blobStore: () => ref.read(mediaBlobStoreProvider),
  );
});

final productEventReporterProvider = Provider<ProductEventReporter>((ref) {
  return ProductEventReporter(
    apiClient: ref.watch(apiClientProvider),
    settingsStore: ref.watch(settingsStoreProvider),
  );
});

final deviceQueueReporterProvider = Provider<DeviceQueueReporter>((ref) {
  return DeviceQueueReporter(
    database: ref.watch(appDatabaseProvider),
    apiClient: ref.watch(apiClientProvider),
    settingsStore: ref.watch(settingsStoreProvider),
    appliedConfigRevision: () => ref.read(systemPolicyProvider).revision,
    reportingInterval: () => ref.read(systemPolicyProvider).reportingInterval,
  );
});

/// HTTP repository for space-scoped Matome sync (task #1377). Overridden in
/// tests with a fake/mock-adapter-backed repo (mirrors recordings).
final matomesRepositoryProvider = Provider<MatomesRepository>((ref) {
  return MatomesRepository(
    apiClient: ref.watch(apiClientProvider),
    productEvents: ref.watch(productEventReporterProvider),
  );
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

/// Ready-only account store. Authenticated screens are routed away until the
/// Vault boot coordinator has atomically published its validated resources.
/// Tests may still override this with [AppDatabase.forTesting].
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final boot = ref.watch(vaultBootCoordinatorProvider);
  final database = boot.stores?.database;
  if (boot.phase != VaultBootPhase.ready || database == null) {
    throw StateError('Account database requested before Vault boot is ready.');
  }
  return database;
});

final mediaBlobStoreProvider = Provider<MediaBlobStore>((ref) {
  final boot = ref.watch(vaultBootCoordinatorProvider);
  final blobs = boot.stores?.blobs;
  if (boot.phase != VaultBootPhase.ready || blobs == null) {
    throw StateError('Media Vault requested before boot is ready.');
  }
  return blobs;
});

final mediaIngestServiceProvider = Provider<MediaIngestService>(
  (ref) => MediaIngestService(ref.watch(mediaBlobStoreProvider)),
);

final vaultExportServiceProvider = Provider<VaultExportService>(
  (ref) => VaultExportService(ref.watch(mediaBlobStoreProvider)),
);

final vaultRetentionServiceProvider = Provider<VaultRetentionService>((ref) {
  return VaultRetentionService(
    ref.watch(appDatabaseProvider),
    ref.watch(mediaBlobStoreProvider),
  );
});

final vaultRetentionPolicyProvider = FutureProvider<VaultRetentionPolicy>((
  ref,
) {
  return ref.watch(vaultRetentionServiceProvider).readPolicy();
});

final itemDeletionServiceProvider = Provider<ItemDeletionService>((ref) {
  return ItemDeletionService(
    ref.watch(itemsDaoProvider),
    () => ref.read(uploadQueueProvider).drain(),
    configRevision: () => ref.read(systemPolicyProvider).revision,
  );
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
