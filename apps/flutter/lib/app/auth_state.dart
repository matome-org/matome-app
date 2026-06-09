import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/auth_models.dart';

/// Resolved auth state consumed by the nav guard.
///
/// Derived from [authControllerProvider] (`AsyncValue<AuthSession?>`). A1
/// (#779) replaced the F1 seed-login bootstrap with real session restore +
/// login screens, but kept this `(isAuthenticated, isLoading)` shape so the
/// router redirect logic stays stable. `user` is exposed for the settings /
/// account UI.
@immutable
class AuthState {
  const AuthState({
    required this.isAuthenticated,
    required this.isLoading,
    this.user,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final AuthUser? user;

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.isAuthenticated == isAuthenticated &&
      other.isLoading == isLoading &&
      other.user?.id == user?.id;

  @override
  int get hashCode => Object.hash(isAuthenticated, isLoading, user?.id);
}

final authStateProvider = Provider<AuthState>((ref) {
  final session = ref.watch(authControllerProvider);
  return AuthState(
    isAuthenticated: session.valueOrNull != null,
    isLoading: session.isLoading,
    user: session.valueOrNull?.user,
  );
});
