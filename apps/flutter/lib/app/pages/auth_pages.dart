import 'package:flutter/material.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/welcome_screen.dart';

/// Canonical route target for `/`.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) => const WelcomeScreen();
}

/// Canonical route target for `/login`.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => const LoginScreen();
}

/// Canonical route target for `/signup`.
class SignupPage extends StatelessWidget {
  const SignupPage({super.key});

  @override
  Widget build(BuildContext context) => const SignupScreen();
}
