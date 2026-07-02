import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/http/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_text_field.dart';
import 'auth_widgets.dart';

/// Reset-password screen (route `/reset-password`): the user pastes the reset
/// code from their email and chooses a new password. On success they return to
/// the login screen to sign in with the new credentials.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken});

  /// Optional reset code, e.g. supplied via a deep link `?token=`.
  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _token =
      TextEditingController(text: widget.initialToken ?? '');
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final token = _token.text.trim();
    final password = _password.text;
    if (token.isEmpty || password.isEmpty) {
      setState(() => _error = t.auth.errorRequiredFields);
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = t.auth.errorPasswordMismatch);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: token, password: password);
      if (!mounted) return;
      setState(() => _done = true);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _error = _messageFor(err));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(ApiException err) {
    if (err.code == 'invalid_reset_token' || err.statusCode == 422) {
      return t.auth.errorResetTokenInvalid;
    }
    return t.auth.errorGeneric;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return AuthScaffold(
      title: t.auth.resetPasswordTitle,
      onBack: () => context.go('/login'),
      children: _done
          ? [
              AuthNoticeBanner(message: t.auth.resetPasswordSuccess),
              SizedBox(height: spacing.lg),
              AuthSubmitButton(
                label: t.auth.backToSignIn,
                loading: false,
                onPressed: () => context.go('/login'),
              ),
            ]
          : [
              Text(
                t.auth.resetPasswordSubtitle,
                style: context.typography.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                controller: _token,
                label: t.auth.resetToken,
                hint: t.auth.resetTokenPlaceholder,
                textInputAction: TextInputAction.next,
                enabled: !_loading,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                controller: _password,
                label: t.auth.newPassword,
                hint: t.auth.passwordPlaceholder,
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                enabled: !_loading,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                controller: _confirm,
                label: t.auth.confirmPassword,
                hint: t.auth.confirmPasswordPlaceholder,
                obscure: true,
                textInputAction: TextInputAction.done,
                enabled: !_loading,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                SizedBox(height: spacing.md),
                AuthErrorBanner(message: _error!),
              ],
              SizedBox(height: spacing.lg),
              AuthSubmitButton(
                label: t.auth.resetPasswordSubmit,
                loading: _loading,
                onPressed: _submit,
              ),
            ],
    );
  }
}
