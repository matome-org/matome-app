import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/http/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_text_field.dart';
import 'auth_widgets.dart';

/// Forgot-password screen (route `/forgot-password`): collects an email and
/// asks the backend to send a reset code. The backend never reveals whether the
/// email exists, so on success we always show the same neutral confirmation.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = t.auth.errorRequiredFields);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException {
      if (!mounted) return;
      setState(() => _error = t.auth.errorGeneric);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return AuthScaffold(
      title: t.auth.forgotPasswordTitle,
      onBack: () => context.go('/login'),
      children: _sent
          ? [
              AuthNoticeBanner(message: t.auth.forgotPasswordSent),
              SizedBox(height: spacing.lg),
              AuthSubmitButton(
                label: t.auth.backToSignIn,
                loading: false,
                onPressed: () => context.go('/login'),
              ),
            ]
          : [
              Text(
                t.auth.forgotPasswordSubtitle,
                style: context.typography.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                controller: _email,
                label: t.auth.email,
                hint: t.auth.emailPlaceholder,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                enabled: !_loading,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                SizedBox(height: spacing.md),
                AuthErrorBanner(message: _error!),
              ],
              SizedBox(height: spacing.lg),
              AuthSubmitButton(
                label: t.auth.forgotPasswordSubmit,
                loading: _loading,
                onPressed: _submit,
              ),
              SizedBox(height: spacing.sm),
              Center(
                child: AppTextButton(
                  onPressed: _loading ? null : () => context.go('/reset-password'),
                  child: Text(t.auth.resetPasswordSubmit),
                ),
              ),
            ],
    );
  }
}
