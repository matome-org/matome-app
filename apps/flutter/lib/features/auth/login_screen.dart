import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/http/api_exception.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_text_field.dart';
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
    final authState = ref.watch(authControllerProvider);
    final loading = authState.isLoading;
    // Surface the controller's last error reactively too, not only the local
    // validation error set after `_submit()`. Keeps the banner in sync when the
    // auth state fails from anywhere, and makes the error state renderable.
    final error =
        _error ?? authState.whenOrNull(error: (err, _) => _messageFor(err));
    final spacing = context.spacing;

    return AuthScaffold(
      title: t.welcome.signIn,
      onBack: () => context.go('/'),
      children: [
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
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          enabled: !loading,
          onSubmitted: (_) => _submit(),
        ),
        if (error != null) ...[
          SizedBox(height: spacing.md),
          AuthErrorBanner(message: error),
        ],
        SizedBox(height: spacing.lg),
        AuthSubmitButton(
          label: t.welcome.signIn,
          loading: loading,
          onPressed: _submit,
        ),
        SizedBox(height: spacing.sm),
        Center(
          child: AppTextButton(
            onPressed: loading ? null : () => context.go('/forgot-password'),
            child: Text(t.auth.forgotPassword),
          ),
        ),
        Center(
          child: AppTextButton(
            onPressed: loading ? null : () => context.go('/signup'),
            child: Text(t.auth.createAccount),
          ),
        ),
      ],
    );
  }
}
