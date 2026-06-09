import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/http/api_exception.dart';
import '../../i18n/strings.g.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

/// Login screen (route `/login`). Port of RN `Views/Login`: email + password,
/// a loading spinner on the submit button, and an inline error on 401/422.
/// On success the auth state flips to authenticated and the nav guard pushes
/// the user into the tabs.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = t.auth.errorRequiredFields);
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .login(email: email, password: password);
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      error: (err, _) => setState(() => _error = _messageFor(err)),
    );
  }

  String _messageFor(Object err) {
    if (err is ApiException) {
      return authErrorMessage(
        statusCode: err.statusCode,
        code: err.code,
        invalidCredentials: t.auth.errorInvalidCredentials,
        requiredFields: t.auth.errorRequiredFields,
        emailTaken: t.auth.errorEmailTaken,
        generic: t.auth.errorGeneric,
      );
    }
    return t.auth.errorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).isLoading;

    return AuthScaffold(
      title: t.welcome.signIn,
      onBack: () => context.go('/'),
      children: [
        AuthField(
          controller: _email,
          label: t.auth.email,
          hint: t.auth.emailPlaceholder,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          enabled: !loading,
        ),
        const SizedBox(height: 16),
        AuthField(
          controller: _password,
          label: t.auth.password,
          hint: t.auth.passwordPlaceholder,
          obscure: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          enabled: !loading,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          AuthErrorBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        AuthSubmitButton(
          label: t.welcome.signIn,
          loading: loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: loading ? null : () => context.go('/signup'),
            child: Text(t.auth.createAccount),
          ),
        ),
      ],
    );
  }
}
