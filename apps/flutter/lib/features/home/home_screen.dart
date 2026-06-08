import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../recordings/recording.dart';
import '../recordings/recordings_controller.dart';
import 'home_filters.dart';
import 'widgets/recording_card.dart';

/// Width past which we treat the viewport as "wide" (desktop / web) and
/// constrain the content column instead of letting it stretch edge-to-edge.
const double _wideBreakpoint = 1000;

/// Max width of the content column on wide viewports.
const double _contentMaxWidth = 720;

/// Home / Today screen. Watches the existing [recordingsControllerProvider]
/// (`AsyncValue<List<Recording>>`) and renders loading / error / empty / list
/// states. Filtering and search are entirely client-side.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  HomeFilter _filter = HomeFilter.all;
  String _search = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      ref.read(recordingsControllerProvider.notifier).refresh();

  void _retry(Recording recording) {
    // Lab scope: a real retry endpoint is out of scope; re-fetch the list so
    // the gesture is wired and observable.
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingsControllerProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
                Expanded(
                  child: state.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (err, _) => _ErrorState(
                      message: err.toString(),
                      onRetry: _refresh,
                    ),
                    data: (recordings) => _Body(
                      recordings: recordings,
                      filter: _filter,
                      search: _search,
                      onRefresh: _refresh,
                      onRetry: _retry,
                      isWide: isWide,
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
  const _Header({
    required this.total,
    required this.searchController,
    required this.search,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.filter,
    required this.onFilterChanged,
  });

  final int total;
  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final HomeFilter filter;
  final ValueChanged<HomeFilter> onFilterChanged;

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
              _IconButton(icon: Icons.add, onPressed: () {}),
              const SizedBox(width: 8),
              _IconButton(icon: Icons.settings_outlined, onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          _SearchField(
            controller: searchController,
            value: search,
            onChanged: onSearchChanged,
            onCleared: onSearchCleared,
          ),
          const SizedBox(height: 12),
          _FilterChips(active: filter, onChanged: onFilterChanged),
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
        prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.active, required this.onChanged});

  final HomeFilter active;
  final ValueChanged<HomeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: HomeFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = HomeFilter.values[index];
          final selected = filter == active;
          return GestureDetector(
            onTap: () => onChanged(filter),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? AppColors.textPrimary : const Color(0x0A0E0F10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                filter.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.recordings,
    required this.filter,
    required this.search,
    required this.onRefresh,
    required this.onRetry,
    required this.isWide,
  });

  final List<Recording> recordings;
  final HomeFilter filter;
  final String search;
  final Future<void> Function() onRefresh;
  final ValueChanged<Recording> onRetry;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final filtered = applyFilters(
      recordings: recordings,
      filter: filter,
      search: search,
    );
    final sections = groupIntoSections(filtered);

    if (sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          // Needs to scroll so pull-to-refresh works even when empty.
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            _EmptyState(searching: search.trim().isNotEmpty || filter != HomeFilter.all),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                      '${section.recordings.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              ...section.recordings.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RecordingCard(
                    recording: r,
                    onTap: () {},
                    onRetry: onRetry,
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
                  ? 'Try a different filter or search term.'
                  : 'Recordings you capture will show up here.',
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
