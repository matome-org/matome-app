import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../ui/app_button.dart';
import '../../ui/app_text_field.dart';
import '../../ui/loading_indicator.dart';

/// Max width of the auth form column on wide (web/desktop) viewports.
const double authFormMaxWidth = 440;

/// Maps an [ApiException]-style auth error to a localized, user-facing message.
/// Resolution prefers the backend `code`, then the HTTP status.
String authErrorMessage({
  required int? statusCode,
  required String? code,
  required String invalidCredentials,
  required String requiredFields,
  required String emailTaken,
  required String generic,
}) {
  switch (code) {
    case 'invalid_credentials':
      return invalidCredentials;
    case 'email_and_password_required':
      return requiredFields;
    case 'email_taken':
      return emailTaken;
  }
  switch (statusCode) {
    case 401:
      return invalidCredentials;
    case 409:
      return emailTaken;
    case 422:
      return requiredFields;
    default:
      return generic;
  }
}

/// Responsive scaffold shared by the login/signup screens: a centered,
/// width-constrained, scrollable, keyboard-aware column with a back affordance.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onBack,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final elevation = context.elevation;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: elevation.level0,
        scrolledUnderElevation: elevation.level0,
        leading: onBack == null
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: onBack,
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: authFormMaxWidth),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                spacing.lg,
                spacing.xs,
                spacing.lg,
                spacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: typography.display.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Labeled text field matching the lab form styling.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      obscure: obscure,
      keyboardType: keyboardType,
      enabled: enabled,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
    );
  }
}

/// Inline error banner shown above the submit button on auth failure.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.failed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.failed.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: spacing.md + spacing.xs / spacing.xxs,
            color: colors.failed,
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              message,
              style: typography.label.copyWith(color: colors.failed),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width neutral/positive notice banner (e.g. "reset link sent"). Mirrors
/// [AuthErrorBanner] but in the brand/accent palette instead of the error one.
class AuthNoticeBanner extends StatelessWidget {
  const AuthNoticeBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: spacing.md + spacing.xs / spacing.xxs,
            color: colors.accent,
          ),
          SizedBox(width: spacing.xs),
          Expanded(
            child: Text(
              message,
              style: typography.label.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary submit button with a loading state.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final strokeWidth = spacing.xs / spacing.xxs;

    return PrimaryButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.textPrimary,
        foregroundColor: colors.onTextPrimary,
        disabledBackgroundColor: colors.textMuted,
        minimumSize: Size.fromHeight(spacing.xxl + spacing.xxs),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.lg),
        ),
      ),
      child: loading
          ? LoadingIndicator(
              size: spacing.md + spacing.xxs,
              strokeWidth: strokeWidth,
              color: colors.onTextPrimary,
            )
          : Text(
              label,
              style: typography.body.copyWith(fontWeight: FontWeight.w700),
            ),
    );
  }
}
