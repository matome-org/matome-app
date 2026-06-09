import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';

/// Resolved auth state consumed by the nav guard.
///
/// Scaffold for F1: derived from the existing [authControllerProvider]
/// (`AsyncValue<AuthSession?>`). A1 (#779) replaces the seed-login bootstrap
/// with real auth, but keeps this `(isAuthenticated, isLoading)` shape so the
/// router redirect logic stays stable.
@immutable
class AuthState {
  const AuthState({required this.isAuthenticated, required this.isLoading});

  final bool isAuthenticated;
  final bool isLoading;

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.isAuthenticated == isAuthenticated &&
      other.isLoading == isLoading;

  @override
  int get hashCode => Object.hash(isAuthenticated, isLoading);
}

final authStateProvider = Provider<AuthState>((ref) {
  final session = ref.watch(authControllerProvider);
  return AuthState(
    isAuthenticated: session.valueOrNull != null,
    isLoading: session.isLoading,
  );
});

/// Lab bootstrap: signs in once with the dev seed account so the Bearer
/// interceptor has a token before the shell mounts. Replaces the old
/// `AuthGate` widget. A1 (#779) swaps this for a real login flow.
///
/// Credentials overridable at build time:
///   --dart-define=SEED_EMAIL=... --dart-define=SEED_PASSWORD=...
class AuthBootstrap {
  static const seedEmail = String.fromEnvironment(
    'SEED_EMAIL',
    defaultValue: 'dev@matome.test',
  );
  static const seedPassword = String.fromEnvironment(
    'SEED_PASSWORD',
    defaultValue: 'devpassword123',
  );

  static void signInSeed(Ref ref) {
    ref.read(authControllerProvider.notifier).login(
          email: seedEmail,
          password: seedPassword,
        );
  }
}
