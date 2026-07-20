import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/auth_state.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/vault/vault_session_controller.dart';
import '../../i18n/strings.g.dart';
import 'auth_widgets.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final ownerId = ref.read(authStateProvider).user?.id;
    if (ownerId == null || _password.text.isEmpty) {
      setState(() => _error = t.auth.unlockError);
      return;
    }
    setState(() => _error = null);
    try {
      await ref
          .read(vaultSessionProvider.notifier)
          .unlockAfterPasswordLogin(
            accountId: vaultAccountIdForOwner(ownerId),
            password: _password.text,
          );
    } on VaultUnlockException {
      if (mounted) setState(() => _error = t.auth.unlockError);
    } finally {
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultSessionProvider);
    final loading =
        vault.phase == VaultSessionPhase.unlocking ||
        vault.phase == VaultSessionPhase.opening;
    final spacing = context.spacing;
    return AuthScaffold(
      title: t.auth.unlockTitle,
      children: [
        Text(t.auth.unlockSubtitle),
        SizedBox(height: spacing.lg),
        AuthField(
          controller: _password,
          label: t.auth.password,
          hint: t.auth.passwordPlaceholder,
          obscure: true,
          enabled: !loading,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _unlock(),
        ),
        if (_error != null) ...[
          SizedBox(height: spacing.md),
          AuthErrorBanner(message: _error!),
        ],
        SizedBox(height: spacing.lg),
        AuthSubmitButton(
          label: t.auth.unlockSubmit,
          loading: loading,
          onPressed: _unlock,
        ),
      ],
    );
  }
}
