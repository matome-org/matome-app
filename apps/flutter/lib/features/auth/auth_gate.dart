import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_screen.dart';
import 'auth_controller.dart';

/// Lab-only auth bootstrap.
///
/// The lab has no login UI (out of scope for #765). To let the Home screen
/// load real recordings, this gate signs in once with the dev seed account
/// before mounting Home, so the Bearer interceptor has a token. Credentials
/// are overridable at build time:
///   --dart-define=SEED_EMAIL=... --dart-define=SEED_PASSWORD=...
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  static const _seedEmail = String.fromEnvironment(
    'SEED_EMAIL',
    defaultValue: 'dev@matome.test',
  );
  static const _seedPassword = String.fromEnvironment(
    'SEED_PASSWORD',
    defaultValue: 'devpassword123',
  );

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _signIn());
  }

  void _signIn() {
    ref.read(authControllerProvider.notifier).login(
          email: AuthGate._seedEmail,
          password: AuthGate._seedPassword,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      data: (session) =>
          session != null ? const HomeScreen() : _Splash(onRetry: _signIn),
      loading: () => const _Splash(),
      error: (_, _) => _Splash(onRetry: _signIn, failed: true),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.onRetry, this.failed = false});

  final VoidCallback? onRetry;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (failed) ...[
              const Icon(Icons.cloud_off, size: 40),
              const SizedBox(height: 12),
              const Text('Could not reach the backend.'),
              const SizedBox(height: 12),
              if (onRetry != null)
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ] else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
