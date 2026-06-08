import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'auth_models.dart';

/// Session state machine exposing `AsyncValue<AuthSession?>`.
///
/// * `data(null)`  -> signed out.
/// * `data(session)` -> signed in.
/// * `loading`     -> a login/refresh is in flight.
/// * `error`       -> last auth attempt failed (login screen surfaces it).
class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  bool get isAuthenticated => state.valueOrNull != null;

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
  }

  Future<void> logout() async {
    await _ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>(
  (ref) => AuthController(ref),
);
