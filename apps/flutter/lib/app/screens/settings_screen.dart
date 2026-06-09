import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../features/auth/auth_controller.dart';
import '../../i18n/strings.g.dart';
import '../auth_state.dart';

/// Settings screen (route `/inbox/settings`). Surfaces the live theme-mode and
/// language toggles so the shell exercises both persisted controllers. Full
/// account / sign-out UI lands in later waves.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final user = ref.watch(authStateProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings.title)),
      body: ListView(
        children: [
          _SectionHeader(t.settings.appearance),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (m) {
              if (m != null) {
                ref.read(themeControllerProvider.notifier).setMode(m);
              }
            },
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text(t.settings.themeLight),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text(t.settings.themeDark),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text(t.settings.themeSystem),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(t.settings.language),
          RadioGroup<AppLocale>(
            groupValue: locale,
            onChanged: (l) {
              if (l != null) {
                ref.read(localeControllerProvider.notifier).setLocale(l);
              }
            },
            child: Column(
              children: [
                RadioListTile<AppLocale>(
                  value: AppLocale.en,
                  title: Text(t.settings.langEn),
                ),
                RadioListTile<AppLocale>(
                  value: AppLocale.ja,
                  title: Text(t.settings.langJa),
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(t.settings.account),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user.email),
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(t.settings.signOut),
            onTap: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
