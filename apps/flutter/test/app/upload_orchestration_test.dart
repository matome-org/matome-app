import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:matome_flutter/app/auth_state.dart';
import 'package:matome_flutter/app/router.dart';
import 'package:matome_flutter/core/config/endpoint_controller.dart';
import 'package:matome_flutter/core/config/system_policy.dart';
import 'package:matome_flutter/core/http/api_client.dart';
import 'package:matome_flutter/core/http/token_store.dart';
import 'package:matome_flutter/core/providers.dart';
import 'package:matome_flutter/core/settings/settings_store.dart';
import 'package:matome_flutter/features/auth/auth_models.dart';
import 'package:matome_flutter/features/recordings/upload_retry_service.dart';
import 'package:matome_flutter/i18n/strings.g.dart';
import 'package:matome_flutter/main.dart' show MatomeApp;

void main() {
  testWidgets(
    'app root starts uploads and retriggers on auth, endpoint, and resume',
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
      final container = ProviderContainer(
        overrides: [
          settingsStoreProvider.overrideWithValue(InMemorySettingsStore()),
          routerProvider.overrideWithValue(router),
          authStateProvider.overrideWith((ref) => ref.watch(auth)),
          systemPolicyProvider.overrideWith((ref) => policy),
          uploadRetryServiceProvider.overrideWithValue(retry),
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
      expect(retry.starts, 1, reason: 'app start is owned by the app root');
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
        1,
        reason: 'auth success immediately retriggers work',
      );
      expect(policy.refreshes, 2, reason: 'auth success refreshes policy');

      await container
          .read(endpointConfigProvider.notifier)
          .setBaseUrl('http://127.0.0.1:7999');
      await tester.pump();
      expect(
        retry.drains,
        2,
        reason: 'runtime endpoint changes retrigger work',
      );
      expect(policy.refreshes, 3, reason: 'endpoint change refreshes policy');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(retry.drains, 3, reason: 'foreground resume retriggers work');
      expect(policy.refreshes, 4, reason: 'foreground resume refreshes policy');
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

  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> drainNow() async {
    drains++;
  }
}

class _NullRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('the recording retry service never reads Ref');
}
