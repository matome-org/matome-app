import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../home/home_filters.dart' show formatTimestamp;
import '../home/inbox_item.dart';
import '../home/widgets/inbox_recording_card.dart';
import 'space_detail_controller.dart';

/// Space detail screen (S5, #784), reachable as `/spaces/:spaceId`. Lists the
/// recordings assigned to the workspace (Drift `getRecordingsInWorkspace`);
/// tapping a recording routes to `/spaces/recording/:id` (the shared
/// DetailsScreen wired by S2). Mirrors `app/(tabs)/explore/[spaceId].tsx`.
class SpaceDetailScreen extends ConsumerWidget {
  const SpaceDetailScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spaceDetailControllerProvider(spaceId));
    final title = state.valueOrNull?.name ?? t.spaces.title;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).go('/spaces'),
        ),
      ),
      body: SafeArea(
        top: false,
        child: state.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
          data: (detail) => _List(
            items: detail.items,
            onRefresh: () => ref
                .read(spaceDetailControllerProvider(spaceId).notifier)
                .load(),
            onTap: (item) =>
                GoRouter.of(context).go('/spaces/recording/${item.id}'),
          ),
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.items,
    required this.onRefresh,
    required this.onTap,
  });

  final List<InboxItem> items;
  final Future<void> Function() onRefresh;
  final ValueChanged<InboxItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox_outlined,
                        size: 44, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      t.spaces.detailEmpty,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InboxRecordingCard(
              key: ValueKey('space-recording-${item.id}'),
              card: item.card,
              relativeTime: formatTimestamp(
                DateTime.fromMillisecondsSinceEpoch(item.createdAt),
              ),
              onTap: () => onTap(item),
            ),
          );
        },
      ),
    );
  }
}
