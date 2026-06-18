import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import 'space_card.dart';
import 'spaces_controller.dart';

/// Width past which we constrain the content column (desktop / web), matching
/// the Inbox screen's behaviour.
const double _wideBreakpoint = 1000;
const double _contentMaxWidth = 720;

/// Spaces tab (S5, #784). Offline-first list of workspaces with their recording
/// counts, driven from Drift via [spacesControllerProvider]. The FAB opens a
/// create-space modal; long-press confirms deletion (which returns the space's
/// recordings to the Inbox). Tapping a space opens its detail at
/// `/spaces/:spaceId`.
class SpacesScreen extends ConsumerWidget {
  const SpacesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateSpaceDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(spacesControllerProvider.notifier).createSpace(name);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SpaceCard space,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteSpaceDialog(name: space.name),
    );
    if (confirmed != true) return;
    await ref.read(spacesControllerProvider.notifier).deleteSpace(space.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spacesControllerProvider);
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        backgroundColor: colors.primary,
        tooltip: t.spaces.createTitle,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? _contentMaxWidth : double.infinity,
            ),
            child: Column(
              children: [
                _Header(total: state.valueOrNull?.length ?? 0),
                Expanded(
                  child: state.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.textMuted),
                        ),
                      ),
                    ),
                    data: (spaces) => _Body(
                      spaces: spaces,
                      onRefresh: () =>
                          ref.read(spacesControllerProvider.notifier).load(),
                      onTap: (s) => GoRouter.of(context).go('/spaces/${s.id}'),
                      onLongPress: (s) => _confirmDelete(context, ref, s),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'マトメ',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: colors.textSecondary,
            ),
          ),
          Text(
            t.spaces.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          if (total > 0)
            Text(
              t.spaces.count(n: total),
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.spaces,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
  });

  final List<SpaceCard> spaces;
  final Future<void> Function() onRefresh;
  final ValueChanged<SpaceCard> onTap;
  final ValueChanged<SpaceCard> onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    if (spaces.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            const _EmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: spaces.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final space = spaces[index];
          return _SpaceTile(
            space: space,
            color: colors.spaceColor(index),
            onTap: () => onTap(space),
            onLongPress: () => onLongPress(space),
          );
        },
      ),
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({
    required this.space,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  final SpaceCard space;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Semantics(
      button: true,
      label: 'Space: ${space.name}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('space-tile-${space.id}'),
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.folder_outlined, size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        space.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.spaces.count(n: space.count),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateSpaceDialog extends StatefulWidget {
  const _CreateSpaceDialog();

  @override
  State<_CreateSpaceDialog> createState() => _CreateSpaceDialogState();
}

class _CreateSpaceDialogState extends State<_CreateSpaceDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(t.spaces.createTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: t.spaces.createHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.spaces.cancel),
        ),
        FilledButton(
          key: const ValueKey('create-space-confirm'),
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: colors.primary),
          child: Text(t.spaces.create),
        ),
      ],
    );
  }
}

class _DeleteSpaceDialog extends StatelessWidget {
  const _DeleteSpaceDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(t.spaces.deleteTitle),
      content: Text('$name\n\n${t.spaces.deleteBody}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.spaces.cancel),
        ),
        FilledButton(
          key: const ValueKey('delete-space-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.failed),
          child: Text(t.spaces.delete),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).extension<MatomeColors>() ?? MatomeColors.light;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 44, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              t.spaces.empty,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.spaces.emptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
