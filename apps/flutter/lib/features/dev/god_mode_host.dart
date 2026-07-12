import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/endpoint_controller.dart';
import '../../core/config/feature_flags.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_text_field.dart';
import '../auth/auth_controller.dart';

/// God-mode developer host switching (gated by [FeatureFlags.godMode]).
///
/// Lets a dev point the whole client at a custom Core backend — Bitwarden-style
/// self-host — from the welcome screen (before login) or Settings. Applying a
/// host rewrites [endpointConfigProvider], which rebuilds the [ApiClient] and
/// every repo, and drops the current session so the user re-authenticates
/// against the new host (the old host's tokens are meaningless there).
///
/// All widgets here render nothing when the flag is OFF, so a release build
/// tree-shakes the affordance out.

/// Compact icon button for the welcome screen. Renders `SizedBox.shrink()` when
/// god mode is off.
class GodModeHostButton extends ConsumerWidget {
  const GodModeHostButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.godMode) return const SizedBox.shrink();
    final overridden = ref.watch(endpointConfigProvider) !=
        ref.read(endpointConfigProvider.notifier).defaultBaseUrl;
    return IconButton(
      tooltip: 'God mode · custom host',
      icon: Icon(overridden ? Icons.dns : Icons.dns_outlined),
      color: overridden ? context.colors.accentDark : null,
      onPressed: () => showGodModeHostDialog(context, ref),
    );
  }
}

/// Settings-screen row. Shows the active base URL and opens the editor.
/// Renders nothing when god mode is off.
class GodModeHostTile extends ConsumerWidget {
  const GodModeHostTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!FeatureFlags.godMode) return const SizedBox.shrink();
    final baseUrl = ref.watch(endpointConfigProvider);
    final overridden =
        baseUrl != ref.read(endpointConfigProvider.notifier).defaultBaseUrl;
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: const Text('Backend host'),
      subtitle: Text(overridden ? '$baseUrl (custom)' : '$baseUrl (default)'),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => showGodModeHostDialog(context, ref),
    );
  }
}

/// Opens the host editor and, on apply/reset, drops the session so the next
/// request authenticates against the chosen host.
Future<void> showGodModeHostDialog(BuildContext context, WidgetRef ref) async {
  final endpoint = ref.read(endpointConfigProvider.notifier);
  final applied = await showDialog<String>(
    context: context,
    builder: (_) => _GodModeHostDialog(
      current: ref.read(endpointConfigProvider),
      defaultUrl: endpoint.defaultBaseUrl,
    ),
  );
  if (applied == null) return; // cancelled

  if (applied.isEmpty) {
    await endpoint.reset();
  } else {
    await endpoint.setBaseUrl(applied);
  }
  // New host ⇒ old session invalid. Clear tokens + flip to signed-out locally
  // (no network) so the nav guard bounces to welcome for a fresh login.
  await ref.read(tokenStoreProvider).clear();
  ref.read(authControllerProvider.notifier).signedOutByInterceptor();

  if (context.mounted) {
    final label = applied.isEmpty ? endpoint.defaultBaseUrl : applied;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Backend host set to $label — sign in again.')),
    );
  }
}

class _GodModeHostDialog extends StatefulWidget {
  const _GodModeHostDialog({required this.current, required this.defaultUrl});

  final String current;
  final String defaultUrl;

  @override
  State<_GodModeHostDialog> createState() => _GodModeHostDialogState();
}

class _GodModeHostDialogState extends State<_GodModeHostDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final normalized = EndpointController.normalizeBaseUrl(_controller.text);
    if (normalized == null) {
      setState(() => _error =
          'Enter an absolute http(s) URL (e.g. http://192.168.1.9:7001).');
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final colors = context.colors;
    return AppDialog(
      title: const Text('Custom backend host'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _controller,
            label: 'Base URL',
            hint: widget.defaultUrl,
            keyboardType: TextInputType.url,
            autofocus: true,
            prefixIcon: const Icon(Icons.dns_outlined),
            onSubmitted: (_) => _apply(),
          ),
          if (_error != null) ...[
            SizedBox(height: spacing.xs),
            Text(
              _error!,
              style: typography.label.copyWith(color: colors.accentDark),
            ),
          ],
          SizedBox(height: spacing.xs),
          Text(
            'Default: ${widget.defaultUrl}',
            style: typography.label.copyWith(color: colors.textMuted),
          ),
        ],
      ),
      actions: [
        // Reset to the platform default (returns empty sentinel).
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: const Text('Reset to default'),
        ),
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}
