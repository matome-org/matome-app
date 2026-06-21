import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/matome_card.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_card.dart';
import '../../ui/app_text_field.dart';
import '../../ui/empty_state.dart';
import '../../ui/loading_indicator.dart';
import '../matome/matome_detail_screen.dart';
import '../matome/matome_row_actions.dart';
import 'home_filters.dart' show formatTimestamp;
import 'inbox_upload.dart';
import 'matome_inbox_controller.dart';
import 'matome_inbox_grouping.dart';
import '../recordings/upload_retry_service.dart';

/// Width past which we treat the viewport as "wide" (desktop / web) and
/// constrain the content column instead of letting it stretch edge-to-edge.
const double _wideBreakpoint = 1000;

/// Selected Inbox matome for the desktop two-pane layout. On wide viewports
/// tapping a row sets this instead of navigating, so the list stays visible
/// beside the [MatomeDetailScreen] detail pane. Narrow viewports ignore it and
/// route to `/matome/:id` as before.
final inboxSelectionProvider = StateProvider<String?>((ref) => null);

/// Inbox / Home screen (S1) under the matome-centric model (#1378): the
/// top-level managed unit is the **Matome**, so the list shows **inbox
/// matomes** (`MatomesDao.listInboxMatomeItems`, spaceId == null) rather than
/// individual recordings. Offline-first: the list is driven from Drift via
/// [matomeInboxControllerProvider], with a Core recording-sync underneath
/// (recordings still sync and land in matomes). Tap navigates to the matome hub
/// (`/matome/:id`); the FAB uploads a file (which creates a recording → an
/// inbox matome).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // App-start trigger (plan #43, W4): kick the auto-retry queue so any
    // `pending_upload` rows left by a prior session (Core was unreachable) drain
    // now, and start the connectivity-regained watcher. Best-effort; idempotent.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(uploadRetryServiceProvider).start();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(matomeInboxControllerProvider.notifier).refresh();

  void _openMatome(MatomeItem item) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    if (isWide) {
      // Two-pane: select in place, keep the list visible.
      ref.read(inboxSelectionProvider.notifier).state = item.id;
    } else {
      GoRouter.of(context).go('/matome/${item.id}');
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withReadStream: false,
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    final name = result!.files.single.name;
    final picked = PickedUpload(
      file: File(path),
      title: _titleFromName(name),
      mediaType: mediaTypeForPath(path),
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Uploading "${picked.title}"…')),
    );
    // Fire-and-forget: the upload inserts the local recording row immediately
    // (into a fresh Inbox matome via upsertRecordingWithMatome); the matome
    // controller listens to the recording inbox and re-reads the list.
    unawaited(
      ref
          .read(inboxUploaderProvider)
          .upload(picked, importFromExternalSource: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(matomeInboxControllerProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    final listColumn = Column(
      children: [
        _Header(
          total: state.valueOrNull?.length ?? 0,
          searchController: _searchController,
          search: _search,
          onSearchChanged: (v) => setState(() => _search = v),
          onSearchCleared: () {
            _searchController.clear();
            setState(() => _search = '');
          },
          onSettings: () => GoRouter.of(context).go('/inbox/settings'),
          // On wide there is no FAB; surface upload in the header instead.
          onUpload: isWide ? _pickAndUpload : null,
        ),
        Expanded(
          child: state.when(
            loading: () =>
                Center(child: LoadingIndicator(color: colors.primary)),
            error: (err, _) =>
                _ErrorState(message: err.toString(), onRetry: _refresh),
            data: (items) => _Body(
              items: items,
              search: _search,
              onRefresh: _refresh,
              onTap: _openMatome,
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: isWide
          ? null
          : FloatingActionButton(
              onPressed: _pickAndUpload,
              backgroundColor: colors.primary,
              tooltip: 'Upload a file',
              child: Icon(Icons.upload_file, color: colors.onAccent),
            ),
      body: SafeArea(
        bottom: false,
        child: isWide
            ? Row(
                children: [
                  Expanded(flex: 2, child: listColumn),
                  VerticalDivider(width: 1, thickness: 1, color: colors.border),
                  const Expanded(flex: 3, child: _InboxDetailPane()),
                ],
              )
            : listColumn,
      ),
    );
  }
}

/// Right-hand pane of the desktop two-pane Inbox: the embedded
/// [MatomeDetailScreen] (the matome hub) for the selected matome, or a teaching
/// placeholder when nothing is selected yet.
class _InboxDetailPane extends ConsumerWidget {
  const _InboxDetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final selectedId = ref.watch(inboxSelectionProvider);

    if (selectedId == null) {
      return ColoredBox(
        color: colors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: spacing.xxl,
                color: colors.textMuted,
              ),
              SizedBox(height: spacing.sm),
              Text(
                t.inbox.selectHint,
                style: typography.bodySmall.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return MatomeDetailScreen(
      key: ValueKey(selectedId),
      id: selectedId,
      embedded: true,
    );
  }
}

String _titleFromName(String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final trimmed = base.trim();
  return trimmed.isEmpty ? 'Untitled' : trimmed;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.total,
    required this.searchController,
    required this.search,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onSettings,
    this.onUpload,
  });

  final int total;
  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onSettings;

  /// Desktop-only upload entry (the FAB is dropped in the two-pane layout).
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.sm,
        spacing.md,
        spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
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
                      t.inbox.title,
                      style: typography.display.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        t.inbox.matomeCount(n: total),
                        style: typography.label.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (onUpload != null) ...[
                _IconButton(
                  icon: Icons.upload_file,
                  onPressed: onUpload!,
                  semanticLabel: 'Upload a file',
                ),
                SizedBox(width: spacing.xs),
              ],
              _IconButton(
                icon: Icons.settings_outlined,
                onPressed: onSettings,
                semanticLabel: t.a11y.openSettings,
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          _SearchField(
            controller: searchController,
            value: search,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Screen-reader label + tooltip for this icon-only control (plan #45, W3).
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;

    // 48×48 minimum tap target (WCAG 2.5.5 / Material).
    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: SizedBox(
          width: spacing.xxl,
          height: spacing.xxl,
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.md),
              side: BorderSide(color: colors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius.md),
              onTap: onPressed,
              child: Icon(
                icon,
                size: spacing.md + spacing.xxs,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.value,
    required this.onChanged,
    required this.onCleared,
  });

  final TextEditingController controller;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return AppTextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      hint: t.inbox.searchHint,
      isDense: true,
      prefixIcon: Icon(
        Icons.search,
        size: spacing.md,
        color: colors.textSecondary,
      ),
      suffixIcon: value.isEmpty
          ? null
          : IconButton(
              icon: Icon(Icons.cancel, size: spacing.md),
              color: colors.textSecondary,
              onPressed: onCleared,
              tooltip: 'Clear search',
            ),
      contentPadding: EdgeInsets.symmetric(vertical: spacing.sm),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.items,
    required this.search,
    required this.onRefresh,
    required this.onTap,
  });

  final List<MatomeItem> items;
  final String search;
  final Future<void> Function() onRefresh;
  final ValueChanged<MatomeItem> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    // Filing targets for each row's "Move to space" action — loaded once,
    // shared across rows (empty while loading, so the menu still opens).
    final spaces = ref.watch(matomeFilingSpacesProvider).valueOrNull ?? const [];
    final filtered = searchMatomes(items, search);
    final sections = groupMatomesByDate(
      filtered,
      todayLabel: 'Today',
      yesterdayLabel: 'Yesterday',
    );

    if (sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            _EmptyState(searching: search.trim().isNotEmpty),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          spacing.md,
          spacing.sm,
          spacing.md,
          spacing.xxl + spacing.xxl,
        ),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          final sectionTopPadding = index == 0
              ? spacing.xxs - spacing.xxs
              : spacing.lg - spacing.xxs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: sectionTopPadding,
                  bottom: spacing.xs,
                ),
                child: Row(
                  children: [
                    Text(
                      section.title.toUpperCase(),
                      style: typography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: colors.textSecondary,
                      ),
                    ),
                    SizedBox(width: spacing.xs),
                    Text(
                      '${section.items.length}',
                      style: typography.label.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              ...section.items.map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: spacing.sm),
                  child: AppCard.matome(
                    matome: item,
                    relativeTime: formatTimestamp(
                      DateTime.fromMillisecondsSinceEpoch(item.happenedAt),
                    ),
                    onTap: () => onTap(item),
                    onAction: (action) => MatomeRowActions(
                      matome: item,
                      spaces: spaces,
                      // Rename / Edit date & time open the matome hub.
                      onOpen: () =>
                          GoRouter.of(context).go('/matome/${item.id}'),
                    ).handle(context, ref, action),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: searching ? Icons.search_off : Icons.inbox_outlined,
      title: searching ? t.inbox.noMatches : t.inbox.empty,
      message: searching ? t.inbox.noMatchesHint : t.inbox.emptyHint,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: spacing.xl + spacing.sm,
              color: colors.failed,
            ),
            SizedBox(height: spacing.sm),
            Text(
              t.inbox.loadFailed,
              style: typography.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: spacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: typography.label.copyWith(color: colors.textMuted),
            ),
            SizedBox(height: spacing.md),
            PrimaryButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                minimumSize: Size(
                  spacing.xxl + spacing.xxl + spacing.lg,
                  spacing.xl + spacing.sm,
                ),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
