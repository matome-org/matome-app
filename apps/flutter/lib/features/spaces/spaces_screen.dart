import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_text_field.dart';
import '../../ui/empty_state.dart';
import '../../ui/loading_indicator.dart';
import 'space_card.dart';
import 'spaces_controller.dart';

/// Width past which the space list reflows into a multi-column grid (desktop /
/// web) so a wide window shows several spaces per row instead of one tall list.
const double _wideBreakpoint = 1000;

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
    final colors = context.colors;
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _create(context, ref),
        backgroundColor: colors.primary,
        tooltip: t.spaces.createTitle,
        child: Icon(Icons.add, color: colors.onAccent),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(total: state.valueOrNull?.length ?? 0),
            Expanded(
              child: state.when(
                loading: () =>
                    Center(child: LoadingIndicator(color: colors.primary)),
                error: (err, _) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.spacing.lg),
                    child: Text(
                      err.toString(),
                      textAlign: TextAlign.center,
                      style: context.typography.bodySmall.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
                data: (spaces) => _Body(
                  spaces: spaces,
                  isWide: isWide,
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'マトメ',
            style: typography.label.copyWith(
              letterSpacing: 2,
              color: colors.textSecondary,
            ),
          ),
          Text(
            t.spaces.title,
            style: typography.display.copyWith(
              color: colors.textPrimary,
            ),
          ),
          if (total > 0)
            Text(
              t.spaces.count(n: total),
              style: typography.label.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.spaces,
    required this.isWide,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
  });

  final List<SpaceCard> spaces;
  final bool isWide;
  final Future<void> Function() onRefresh;
  final ValueChanged<SpaceCard> onTap;
  final ValueChanged<SpaceCard> onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    if (spaces.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            EmptyState(
              icon: Icons.folder_outlined,
              title: t.spaces.empty,
              message: t.spaces.emptyHint,
            ),
          ],
        ),
      );
    }

    final padding = EdgeInsets.fromLTRB(
      spacing.md,
      spacing.sm,
      spacing.md,
      spacing.xxl + spacing.xxl,
    );

    Widget tile(int index) {
      final space = spaces[index];
      return _SpaceTile(
        space: space,
        color: colors.spaceColor(index),
        onTap: () => onTap(space),
        onLongPress: () => onLongPress(space),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      child: isWide
          ? GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: spacing.xxl + spacing.lg,
                crossAxisSpacing: spacing.sm,
                mainAxisSpacing: spacing.sm,
              ),
              itemCount: spaces.length,
              itemBuilder: (context, index) => tile(index),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              itemCount: spaces.length,
              separatorBuilder: (_, _) => SizedBox(height: spacing.xs),
              itemBuilder: (context, index) => tile(index),
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
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Semantics(
      button: true,
      label: 'Space: ${space.name}',
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.lg),
        child: InkWell(
          key: ValueKey('space-tile-${space.id}'),
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(radius.lg),
          child: Container(
            padding: EdgeInsets.all(spacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius.lg),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: spacing.xl + spacing.xs,
                  height: spacing.xl + spacing.xs,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(radius.md),
                  ),
                  child: Icon(
                    Icons.folder_outlined,
                    size: typography.title.fontSize,
                    color: color,
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        space.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: spacing.xxs),
                      Text(
                        t.spaces.count(n: space.count),
                        style: typography.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: spacing.md + spacing.xxs,
                  color: colors.textMuted,
                ),
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
    final colors = context.colors;

    return AppDialog(
      backgroundColor: colors.surface,
      title: Text(t.spaces.createTitle),
      content: AppTextField(
        controller: _controller,
        hint: t.spaces.createHint,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.spaces.cancel),
        ),
        PrimaryButton(
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
    final colors = context.colors;

    return AppDialog(
      backgroundColor: colors.surface,
      title: Text(t.spaces.deleteTitle),
      content: Text('$name\n\n${t.spaces.deleteBody}'),
      actions: [
        AppTextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.spaces.cancel),
        ),
        PrimaryButton(
          key: const ValueKey('delete-space-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: colors.failed),
          child: Text(t.spaces.delete),
        ),
      ],
    );
  }
}
