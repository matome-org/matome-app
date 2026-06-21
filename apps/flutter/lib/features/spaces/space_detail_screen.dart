import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/matome_card.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_card.dart';
import '../../ui/empty_state.dart';
import '../../ui/loading_indicator.dart';
import '../home/home_filters.dart' show formatTimestamp;
import '../matome/matome_row_actions.dart';
import 'filing_spaces_provider.dart';
import 'space_detail_controller.dart';

/// Wide-viewport reading clamp so the matome rows don't sprawl across a desktop
/// window (this screen is a pushed route with its own app bar).
const double _wideBreakpoint = 1000;
const double _contentMaxWidth = 720;

/// Space detail screen (S5, #784) under the matome-centric model (#1378),
/// reachable as `/spaces/:spaceId`. Lists the **matomes** filed into the
/// workspace (Drift `listMatomeItemsInSpace`); tapping a matome routes to the
/// matome hub (`/matome/:id`).
class SpaceDetailScreen extends ConsumerWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spaceDetailControllerProvider(spaceId));
    final colors = context.colors;
    final title = state.valueOrNull?.name ?? t.spaces.title;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/spaces'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: state.when(
          loading: () => Center(child: LoadingIndicator(color: colors.primary)),
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
          data: (detail) => _List(
            items: detail.items,
            isWide: MediaQuery.sizeOf(context).width >= _wideBreakpoint,
            onRefresh: () => ref
                .read(spaceDetailControllerProvider(spaceId).notifier)
                .load(),
            onTap: (item) => GoRouter.of(context).go('/matome/${item.id}'),
          ),
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({
    required this.items,
    required this.isWide,
    required this.onRefresh,
    required this.onTap,
  });

  final List<MatomeItem> items;
  final bool isWide;
  final Future<void> Function() onRefresh;
  final ValueChanged<MatomeItem> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final spaces =
        ref.watch(filingSpacesProvider).valueOrNull ?? const [];

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            EmptyState(
              icon: Icons.inbox_outlined,
              title: t.spaces.detailEmptyMatomes,
              titleStyle: typography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final list = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.xxl + spacing.xxl,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: EdgeInsets.only(bottom: spacing.sm),
          child: AppCard.matome(
            key: ValueKey('space-matome-${item.id}'),
            matome: item,
            relativeTime: formatTimestamp(
              DateTime.fromMillisecondsSinceEpoch(item.happenedAt),
            ),
            onTap: () => onTap(item),
            onAction: (action) => MatomeRowActions(
              matome: item,
              spaces: spaces,
              onOpen: () => GoRouter.of(context).go('/matome/${item.id}'),
            ).handle(context, ref, action),
          ),
        );
      },
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      child: isWide
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: list,
              ),
            )
          : list,
    );
  }
}
