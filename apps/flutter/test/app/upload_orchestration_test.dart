import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/app/auth_state.dart';
import 'package:matome_flutter/app/router.dart';
import 'package:matome_flutter/core/config/endpoint_controller.dart';
import 'package:matome_flutter/core/config/system_policy.dart';
import 'package:matome_flutter/core/db/app_database.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/core/vault/vault_boot_coordinator.dart';
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/recordings/upload_retry_service.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/main.dart' show MatomeApp;
import 'package:matome_vault/matome_vault.dart';

void main() {
  testWidgets(
    'app root starts uploads only when Vault is ready and retriggers safely',
    (tester) async {
      final auth = StateProvider<AuthState>(
        (ref) => const AuthState(isAuthenticated: false, isLoading: false),
      );
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);

      final retry = _RecordingRetryService(_NullRef());
      final policy = _RecordingPolicyController();
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final boot = VaultBootCoordinator(
        openStores: (material) async => VaultOpenedStores(
          database: database,
          blobs: _FakeBlobStore(material.accountId),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          routerProvider.overrideWithValue(router),
          authStateProvider.overrideWith((ref) => ref.watch(auth)),
          systemPolicyProvider.overrideWith((ref) => policy),
          uploadRetryServiceProvider.overrideWithValue(retry),
          vaultBootCoordinatorProvider.overrideWith((ref) => boot),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(child: const MatomeApp()),
        ),
      );
      await tester.pump();
      expect(retry.starts, 0, reason: 'queue cannot start before Vault ready');
      expect(retry.drains, 0);
      expect(policy.refreshes, 1, reason: 'app start fetches policy');

      container.read(auth.notifier).state = const AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: AuthUser(id: 1, email: 'owner@example.test'),
      );
      await tester.pump();
      expect(
        retry.drains,
        0,
        reason: 'JWT alone cannot drain the account database',
      );
      expect(policy.refreshes, 2, reason: 'auth success refreshes policy');

      await boot.open(_FakeKeyMaterial());
      await tester.pump();
      expect(retry.starts, 1, reason: 'ready account boot starts the queue');

      await container
          .read(endpointConfigProvider.notifier)
          .setBaseUrl('http://127.0.0.1:7999');
      await tester.pump();
      expect(
        retry.drains,
        1,
        reason: 'runtime endpoint changes retrigger work',
      );
      expect(policy.refreshes, 3, reason: 'endpoint change refreshes policy');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(retry.drains, 2, reason: 'foreground resume retriggers work');
      expect(policy.refreshes, 4, reason: 'foreground resume refreshes policy');

      await boot.close();
      await tester.pump();
      expect(retry.stops, 1, reason: 'locking closes queue ownership');
    },
  );
}

class _RecordingPolicyController extends SystemPolicyController {
  _RecordingPolicyController()
    : super(
        ApiClient(tokenStore: InMemoryTokenStore()),
        InMemorySettingsStore(),
      );

  int refreshes = 0;

  @override
  Future<void> initialize() async {
    refreshes++;
  }

  @override
  Future<bool> refresh() async {
    refreshes++;
    return true;
  }
}

class _RecordingRetryService extends UploadRetryService {
  _RecordingRetryService(super.ref);

  int starts = 0;
  int drains = 0;
  int stops = 0;

  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> drainNow() async {
    drains++;
  }

  @override
  void stop() {
    stops++;
  }
}

class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the recording retry service never reads Ref');
}

final class _FakeKeyMaterial implements VaultKeyMaterial {
  @override
  final accountId = VaultAccountId('test-account');

  @override
  Future<void> dispose() async {}

  @override
  Future<T> use<T>(FutureOr<T> Function(Uint8List accountDek) operation) =>
      Future.sync(() => operation(Uint8List(32)));
}

final class _FakeBlobStore implements MediaBlobStore {
  _FakeBlobStore(this.accountId);

  @override
  final VaultAccountId accountId;

  @override
  Future<VaultReconciliationReport> reconcile() async =>
      VaultReconciliationReport(const []);

  @override
  Future<Set<VaultBlobId>> readyBlobIds() async => {};

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('blob operations are outside this test');
}
