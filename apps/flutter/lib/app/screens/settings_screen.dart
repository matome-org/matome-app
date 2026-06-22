import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/files/files_screen.dart';
import '../../features/home/home_screen.dart';
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
    final inboxView = ref.watch(inboxViewProvider);
    final filesView = ref.watch(filesViewProvider);
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
          _SectionHeader(t.settings.views),
          _SubHeader(t.settings.viewsMatome),
          RadioGroup<InboxView>(
            groupValue: inboxView,
            onChanged: (v) {
              if (v != null) {
                ref.read(inboxViewProvider.notifier).setView(v);
              }
            },
            child: Column(
              children: [
                RadioListTile<InboxView>(
                  value: InboxView.cards,
                  title: Text(t.settings.viewCards),
                ),
                RadioListTile<InboxView>(
                  value: InboxView.table,
                  title: Text(t.settings.viewTableMatome),
                ),
              ],
            ),
          ),
          _SubHeader(t.settings.viewsFiles),
          RadioGroup<FilesView>(
            groupValue: filesView,
            onChanged: (v) {
              if (v != null) {
                ref.read(filesViewProvider.notifier).setView(v);
              }
            },
            child: Column(
              children: [
                RadioListTile<FilesView>(
                  value: FilesView.grid,
                  title: Text(t.settings.viewGrid),
                ),
                RadioListTile<FilesView>(
                  value: FilesView.table,
                  title: Text(t.settings.viewTableFiles),
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
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
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
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.md,
        spacing.md,
        spacing.xs,
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Sub-label inside a section — used to group the two view radio sets (Matome /
/// Files) under the single "Default views" header.
class _SubHeader extends StatelessWidget {
  const _SubHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.xxs,
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
