import 'package:flutter/material.dart';

import '../../i18n/strings.g.dart';

/// Unauthenticated landing screen (route `/`). Mirrors RN `app/index.tsx`
/// welcome. Real sign-in/sign-up wiring lands in A1 (#779); for now the
/// buttons are placeholders so the shell boots and the guard has a target.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t.welcome.title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {},
                child: Text(t.welcome.signIn),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {},
                child: Text(t.welcome.signUp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
