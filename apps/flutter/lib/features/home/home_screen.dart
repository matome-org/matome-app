import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../details/details_screen.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_bottom_sheet.dart';
import '../../ui/app_button.dart';
import '../../ui/app_card.dart';
import '../../ui/app_text_field.dart';
import '../../ui/empty_state.dart';
import '../../ui/loading_indicator.dart';
import 'home_filters.dart' show formatTimestamp;
import 'inbox_controller.dart';
import 'inbox_grouping.dart';
import 'inbox_item.dart';
import 'inbox_upload.dart';
import '../recordings/upload_retry_service.dart';

/// Width past which we treat the viewport as "wide" (desktop / web) and
/// constrain the content column instead of letting it stretch edge-to-edge.
const double _wideBreakpoint = 1000;

/// Selected Inbox recording for the desktop two-pane layout. On wide viewports
/// tapping a row sets this instead of navigating, so the list stays visible
/// beside the detail pane. Narrow viewports ignore it and route as before.
final inboxSelectionProvider = StateProvider<String?>((ref) => null);

/// Inbox / Home screen (S1, #780). Offline-first: the list is driven from
/// Drift (`getInboxRecordings`) via [inboxControllerProvider], with a Core sync
/// on load / pull-to-refresh. Search is client-side. Tap navigates to Details
/// (S2 route), long-press opens the move-to-space sheet, the FAB uploads a file.
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
      ref.read(inboxControllerProvider.notifier).refresh();

  void _openDetails(InboxItem item) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    if (isWide) {
      // Two-pane: select in place, keep the list visible.
      ref.read(inboxSelectionProvider.notifier).state = item.id;
    } else {
      GoRouter.of(context).go('/inbox/${item.id}');
    }
  }

  /// Manual retry from a `failed` Inbox card — re-enqueues via the auto-retry
  /// upload queue (plan #43, W5). Fire-and-forget: the controller flips the row
  /// to `pending_upload` and re-renders before the drain runs.
  Future<void> _retryUpload(InboxItem item) =>
      ref.read(inboxControllerProvider.notifier).retryUpload(item.id);

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
    // Fire-and-forget: the controller inserts the local row immediately and
    // updates it as the pipeline resolves; the list reflects each step.
    unawaited(
      ref
          .read(inboxUploaderProvider)
          .upload(picked, importFromExternalSource: true),
    );
  }

  Future<void> _showMoveSheet(InboxItem item) async {
    final spaces = await ref.read(inboxControllerProvider.notifier).spaces();
    if (!mounted) return;
    final target = await showAppBottomSheet<WorkspaceRow>(
      context: context,
      builder: (context) => _MoveToSpaceSheet(spaces: spaces),
    );
    if (target == null) return;
    await ref
        .read(inboxControllerProvider.notifier)
        .moveToSpace(item.id, target.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(inboxControllerProvider);
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
              onTap: _openDetails,
              onLongPress: _showMoveSheet,
              onRetry: _retryUpload,
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

/// Right-hand pane of the desktop two-pane Inbox: the embedded [DetailsScreen]
/// for the selected recording, or a teaching placeholder when nothing is
/// selected yet.
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
                'Select a recording to preview',
                style: typography.bodySmall.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return DetailsScreen(
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
                      'Inbox',
                      style: typography.display.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '$total recordings',
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
      hint: 'Search recordings',
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

class _Body extends StatelessWidget {
  const _Body({
    required this.items,
    required this.search,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
    required this.onRetry,
  });

  final List<InboxItem> items;
  final String search;
  final Future<void> Function() onRefresh;
  final ValueChanged<InboxItem> onTap;
  final ValueChanged<InboxItem> onLongPress;
  final ValueChanged<InboxItem> onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final filtered = searchItems(items, search);
    final sections = groupByDate(
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
                  child: AppCard.recording(
                    card: item.card,
                    relativeTime: formatTimestamp(
                      DateTime.fromMillisecondsSinceEpoch(item.createdAt),
                    ),
                    onTap: () => onTap(item),
                    onLongPress: () => onLongPress(item),
                    onRetry: () => onRetry(item),
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

class _MoveToSpaceSheet extends StatelessWidget {
  const _MoveToSpaceSheet({required this.spaces});

  final List<WorkspaceRow> spaces;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return AppBottomSheet(
      title: Text(
        'Move to space',
        style: typography.body.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
      ),
      children: [
        if (spaces.isEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.xs,
              spacing.lg,
              spacing.lg,
            ),
            child: Text(
              'No spaces yet.',
              style: typography.bodySmall.copyWith(color: colors.textSecondary),
            ),
          )
        else
          ...spaces.map(
            (ws) => ListTile(
              leading: Icon(Icons.folder_outlined, color: colors.textSecondary),
              title: Text(ws.name),
              onTap: () => Navigator.of(context).pop(ws),
            ),
          ),
      ],
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
      title: searching ? 'No matching recordings' : 'No recordings yet',
      message: searching
          ? 'Try a different search term.'
          : 'Recordings you capture or upload will show up here.',
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
              "Couldn't load recordings",
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
