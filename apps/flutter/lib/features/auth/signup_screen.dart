import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/http/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_text_field.dart';
import 'auth_controller.dart';
import 'auth_widgets.dart';

/// Signup screen (route `/signup`). Port of RN `Views/Signup`: name + email +
/// password (+ confirm). The display name is collected for UX parity with the
/// RN flow but, like `processes/auth.ts`, only email + password are sent to
/// `/api/auth/register` (the Guardian `AuthCredentials` payload). On success
/// the auth state flips to authenticated and the guard lands the user in tabs.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
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
    if (password != _confirm.text) {
      setState(() => _error = t.auth.errorPasswordMismatch);
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .register(email: email, password: password);
    if (!mounted) return;
    ref
        .read(authControllerProvider)
        .whenOrNull(
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
    final spacing = context.spacing;

    return AuthScaffold(
      title: t.auth.createAccount,
      onBack: () => context.go('/'),
      children: [
        AppTextField(
          controller: _name,
          label: t.auth.name,
          hint: t.auth.namePlaceholder,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          enabled: !loading,
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          controller: _email,
          label: t.auth.email,
          hint: t.auth.emailPlaceholder,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          enabled: !loading,
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          controller: _password,
          label: t.auth.password,
          hint: t.auth.passwordPlaceholder,
          obscure: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !loading,
        ),
        SizedBox(height: spacing.md),
        AppTextField(
          controller: _confirm,
          label: t.auth.confirmPassword,
          hint: t.auth.confirmPasswordPlaceholder,
          obscure: true,
          textInputAction: TextInputAction.done,
          enabled: !loading,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          SizedBox(height: spacing.md),
          AuthErrorBanner(message: _error!),
        ],
        SizedBox(height: spacing.lg),
        AuthSubmitButton(
          label: t.welcome.signUp,
          loading: loading,
          onPressed: _submit,
        ),
        SizedBox(height: spacing.sm),
        Center(
          child: AppTextButton(
            onPressed: loading ? null : () => context.go('/login'),
            child: Text(t.auth.alreadyHaveAccount),
          ),
        ),
      ],
    );
  }
}
