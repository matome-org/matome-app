import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/app_database.dart';
import '../../core/theme/app_theme.dart';
import 'home_filters.dart' show formatTimestamp;
import 'inbox_controller.dart';
import 'inbox_grouping.dart';
import 'inbox_item.dart';
import 'inbox_upload.dart';
import 'widgets/inbox_recording_card.dart';

/// Width past which we treat the viewport as "wide" (desktop / web) and
/// constrain the content column instead of letting it stretch edge-to-edge.
const double _wideBreakpoint = 1000;
const double _contentMaxWidth = 720;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(inboxControllerProvider.notifier).refresh();

  void _openDetails(InboxItem item) {
    GoRouter.of(context).go('/inbox/${item.id}');
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
    // Fire-and-forget: the controller inserts the local row immediately and
    // updates it as the pipeline resolves; the list reflects each step.
    unawaited(ref.read(inboxUploaderProvider).upload(picked));
  }

  Future<void> _showMoveSheet(InboxItem item) async {
    final spaces = await ref.read(inboxControllerProvider.notifier).spaces();
    if (!mounted) return;
    final target = await showModalBottomSheet<WorkspaceRow>(
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
    final state = ref.watch(inboxControllerProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUpload,
        backgroundColor: AppColors.primary,
        tooltip: 'Upload a file',
        child: const Icon(Icons.upload_file, color: Colors.white),
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
                ),
                Expanded(
                  child: state.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (err, _) =>
                        _ErrorState(message: err.toString(), onRetry: _refresh),
                    data: (items) => _Body(
                      items: items,
                      search: _search,
                      onRefresh: _refresh,
                      onTap: _openDetails,
                      onLongPress: _showMoveSheet,
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
  });

  final int total;
  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
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
                    const Text(
                      'マトメ',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(
                      'Inbox',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (total > 0)
                      Text(
                        '$total recordings',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              _IconButton(icon: Icons.settings_outlined, onPressed: onSettings),
            ],
          ),
          const SizedBox(height: 12),
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
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search recordings',
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon:
            const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.cancel, size: 16),
                color: AppColors.textSecondary,
                onPressed: onCleared,
                tooltip: 'Clear search',
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
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
  });

  final List<InboxItem> items;
  final String search;
  final Future<void> Function() onRefresh;
  final ValueChanged<InboxItem> onTap;
  final ValueChanged<InboxItem> onLongPress;

  @override
  Widget build(BuildContext context) {
    final filtered = searchItems(items, search);
    final sections = groupByDate(
      filtered,
      todayLabel: 'Today',
      yesterdayLabel: 'Yesterday',
    );

    if (sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
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
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 20, bottom: 8),
                child: Row(
                  children: [
                    Text(
                      section.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${section.items.length}',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              ...section.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InboxRecordingCard(
                    card: item.card,
                    relativeTime: formatTimestamp(
                      DateTime.fromMillisecondsSinceEpoch(item.createdAt),
                    ),
                    onTap: () => onTap(item),
                    onLongPress: () => onLongPress(item),
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
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Move to space',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (spaces.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'No spaces yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...spaces.map(
              (ws) => ListTile(
                leading: const Icon(Icons.folder_outlined,
                    color: AppColors.textSecondary),
                title: Text(ws.name),
                onTap: () => Navigator.of(context).pop(ws),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off : Icons.inbox_outlined,
              size: 44,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No matching recordings' : 'No recordings yet',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              searching
                  ? 'Try a different search term.'
                  : 'Recordings you capture or upload will show up here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 44, color: AppColors.failed),
            const SizedBox(height: 12),
            const Text(
              "Couldn't load recordings",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(120, 44),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
