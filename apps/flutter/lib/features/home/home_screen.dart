import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/feature_flags.dart';
import '../../core/db/matome_card.dart';
import '../../core/providers.dart';
import '../../core/settings/reading_pane.dart';
import '../../core/settings/settings_store.dart';
import '../../core/theme/app_theme.dart';
import '../../i18n/strings.g.dart';
import '../../ui/app_button.dart';
import '../../ui/app_card.dart';
import '../../ui/app_text_field.dart';
import '../../ui/empty_state.dart';
import '../../ui/loading_indicator.dart';
import '../../ui/master_detail_scaffold.dart';
import '../matome/matome_actions_menu.dart' show MatomeAction;
import '../matome/matome_detail_controller.dart';
import '../matome/matome_detail_screen.dart';
import '../matome/matome_row_actions.dart';
import '../matome/widgets/matome_table.dart';
import '../spaces/filing_spaces_provider.dart';
import 'home_filters.dart' show formatTimestamp;
import 'loose_inbox_controller.dart';
import 'loose_inbox_section.dart';
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

/// How the inbox/home list is presented — the **card** "letter" list (.docs/internal/architecture.md §11 (D5))
/// or the columnar [MatomeTable] (DR-001). A user-selectable view controlled
/// from Settings → "Default views" (#1468); the on-screen header toggle was
/// removed (#1474) so Settings is the single control. The screen still renders
/// whichever view [inboxViewProvider] holds, and the choice survives a restart.
enum InboxView { cards, table }

const _inboxViewKey = 'matome.inbox_view';

/// Persisted controller for [InboxView], hydrated from / written to the secure
/// [SettingsStore] (#1468). Mirrors [ThemeController] / [LocaleController]:
/// default is [InboxView.cards] until the stored value loads. The Settings radio
/// reads this provider and calls [setView] (#1474 removed the in-view header
/// toggle), so Settings is the single control.
class InboxViewController extends StateNotifier<InboxView> {
  InboxViewController(this._store) : super(InboxView.cards) {
    _hydrate();
  }

  final SettingsStore _store;

  Future<void> _hydrate() async {
    final view = _parse(await _store.read(_inboxViewKey));
    if (view != null && mounted) state = view;
  }

  Future<void> setView(InboxView view) async {
    state = view;
    await _store.write(_inboxViewKey, view.name);
  }

  static InboxView? _parse(String? raw) {
    for (final v in InboxView.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

final inboxViewProvider =
    StateNotifierProvider<InboxViewController, InboxView>(
  (ref) => InboxViewController(ref.watch(settingsStoreProvider)),
);

/// Inbox / Home screen (S1) under the matome-centric model (#1378): the
/// top-level managed unit is the **Matome**, so the list shows **inbox
/// matomes** (`MatomesDao.listInboxMatomeItems`, spaceId == null) rather than
/// individual recordings. Offline-first: the list is driven from Drift via
/// [matomeInboxControllerProvider], with a Core recording-sync underneath
/// (recordings still sync and land in matomes). Tap navigates to the matome hub
/// (`/matome/:id`). Upload now lives on the nav shell's hero "+" Add (same
/// `inboxUploaderProvider` pipeline) and Settings on the dock / sidebar, so the
/// inbox no longer carries its own upload FAB or header upload/settings
/// affordances (#1474 follow-up).
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

  /// Clear the reading-pane selection so it never points at a matome that is no
  /// longer in the loaded list (archived, deleted, or absent after a reload).
  /// Only meaningful behind the master-detail layout (where the pane is driven
  /// by [inboxSelectionProvider]); a no-op cost otherwise.
  void _clearInboxSelection() {
    if (ref.read(inboxSelectionProvider) != null) {
      ref.read(inboxSelectionProvider.notifier).state = null;
    }
  }

  void _openMatome(MatomeItem item) {
    if (FeatureFlags.masterDetailLayout) {
      // W2 (#1541): the unified [MasterDetailScaffold] owns the layout decision;
      // its [selectsOnTap] predicate is the single source of truth for whether a
      // tap selects in-pane (pane reality) or navigates full-screen.
      if (MasterDetailScaffold.selectsOnTap(
        context,
        ref.read(readingPaneModeProvider(ReadingPaneSurface.inbox)),
      )) {
        ref.read(inboxSelectionProvider.notifier).state = item.id;
      } else {
        GoRouter.of(context).push('/matome/${item.id}');
      }
      return;
    }
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    if (isWide) {
      // Two-pane: select in place, keep the list visible.
      ref.read(inboxSelectionProvider.notifier).state = item.id;
    } else {
      // PUSH (not go/replace) so the detail opens OVER the shell with a back
      // stack — the matome hub's AppBar back can pop straight to this list.
      GoRouter.of(context).push('/matome/${item.id}');
    }
  }

  /// Bulk / per-row table action wiring. Archive is local-first + recoverable
  /// (controller archive → Undo SnackBar that restores); delete is the
  /// permanent hard-delete (the table already gated it behind a confirm); move
  /// reuses the per-matome filing sheet. After any op the inbox re-reads from
  /// Drift so the rows drop out / return.
  Future<void> _handleTableBulk(
    MatomeTableAction action,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final inbox = ref.read(matomeInboxControllerProvider.notifier);

    switch (action) {
      case MatomeTableAction.open:
        break; // handled by onOpen
      case MatomeTableAction.moveToSpace:
        final spaces = ref.read(filingSpacesProvider).valueOrNull ?? const [];
        if (spaces.isEmpty) return;
        // Single-target move uses the existing per-row filing sheet; for a
        // multi-select we file each into the first chosen space.
        final first = ids.first;
        final firstItem = ref
            .read(matomeInboxControllerProvider)
            .valueOrNull
            ?.firstWhere((m) => m.id == first);
        if (firstItem == null) return;
        await MatomeRowActions(
          matome: firstItem,
          spaces: spaces,
          onOpen: () {},
        ).handle(context, ref, MatomeAction.moveToSpace);
        await inbox.reloadFromLocal();
      case MatomeTableAction.archive:
        for (final id in ids) {
          try {
            await ref
                .read(matomeDetailControllerProvider(id).notifier)
                .archive();
          } catch (_) {
            // Offline-first: local archive stands; next pull reconciles.
          }
        }
        await inbox.reloadFromLocal();
        if (!mounted) return;
        // Never leave the reading pane pointing at an archived matome.
        if (ids.contains(ref.read(inboxSelectionProvider))) {
          _clearInboxSelection();
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(t.matome.table.archivedMsg(n: ids.length)),
            action: SnackBarAction(
              label: t.matome.table.undo,
              onPressed: () async {
                for (final id in ids) {
                  try {
                    await ref
                        .read(matomeDetailControllerProvider(id).notifier)
                        .restore();
                  } catch (_) {}
                }
                await inbox.reloadFromLocal();
              },
            ),
          ),
        );
      case MatomeTableAction.delete:
        final dao = ref.read(matomesDaoProvider);
        for (final id in ids) {
          await dao.deleteMatome(id);
        }
        await inbox.reloadFromLocal();
        if (!mounted) return;
        // Never leave the reading pane pointing at a deleted matome.
        if (ids.contains(ref.read(inboxSelectionProvider))) {
          _clearInboxSelection();
        }
        messenger.showSnackBar(
          SnackBar(content: Text(t.matome.table.deletedMsg(n: ids.length))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(matomeInboxControllerProvider);
    final view = ref.watch(inboxViewProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    // Reading-pane selection: never point the pane at a matome that has left the
    // loaded list (deleted / filed / absent after a reload). Reconcile after the
    // frame so we don't mutate a provider mid-build.
    if (FeatureFlags.masterDetailLayout) {
      final selectedId = ref.watch(inboxSelectionProvider);
      final items = state.valueOrNull;
      if (selectedId != null &&
          items != null &&
          !items.any((m) => m.id == selectedId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _clearInboxSelection();
        });
      }
    }

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
              view: view,
              onRefresh: _refresh,
              onTap: _openMatome,
              onTableBulk: _handleTableBulk,
            ),
          ),
        ),
      ],
    );

    final Widget body;
    if (FeatureFlags.masterDetailLayout) {
      // W2 (#1541): the inbox renders through the unified [MasterDetailScaffold].
      // The scaffold owns the layout decision (master full-width vs master +
      // reading pane) from the per-surface [readingPaneModeProvider] and the
      // current width class; tap-vs-navigate is decided by the same
      // [selectsOnTap] predicate in [_openMatome], so the two can never drift.
      final selectedId = ref.watch(inboxSelectionProvider);
      body = MasterDetailScaffold(
        master: listColumn,
        detail: selectedId != null
            ? MatomeDetailScreen(
                key: ValueKey(selectedId),
                id: selectedId,
                embedded: true,
              )
            : null,
        emptyState: const _InboxPaneEmptyState(),
        mode: ref.watch(readingPaneModeProvider(ReadingPaneSurface.inbox)),
      );
    } else {
      // Shipped behaviour (flag OFF): the `_wideBreakpoint`=1000 two-pane Row.
      body = isWide
          ? Row(
              children: [
                Expanded(flex: 2, child: listColumn),
                VerticalDivider(width: 1, thickness: 1, color: colors.border),
                const Expanded(flex: 3, child: _InboxDetailPane()),
              ],
            )
          : listColumn;
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(bottom: false, child: body),
    );
  }
}

/// The "select a matome to read it here" teaching placeholder shown in the
/// reading pane when nothing is selected. Extracted from [_InboxDetailPane]'s
/// null branch so the [MasterDetailScaffold] `emptyState` and the legacy
/// two-pane share ONE placeholder (no drift between the flag-ON / flag-OFF
/// realities).
class _InboxPaneEmptyState extends StatelessWidget {
  const _InboxPaneEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

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
}

/// Right-hand pane of the desktop two-pane Inbox: the embedded
/// [MatomeDetailScreen] (the matome hub) for the selected matome, or a teaching
/// placeholder when nothing is selected yet.
class _InboxDetailPane extends ConsumerWidget {
  const _InboxDetailPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(inboxSelectionProvider);

    if (selectedId == null) {
      return const _InboxPaneEmptyState();
    }

    return MatomeDetailScreen(
      key: ValueKey(selectedId),
      id: selectedId,
      embedded: true,
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
  });

  final int total;
  final TextEditingController searchController;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;

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
          Column(
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
    required this.view,
    required this.onRefresh,
    required this.onTap,
    required this.onTableBulk,
  });

  final List<MatomeItem> items;
  final String search;
  final InboxView view;
  final Future<void> Function() onRefresh;
  final ValueChanged<MatomeItem> onTap;
  final Future<void> Function(MatomeTableAction, Set<String>) onTableBulk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    // Filing targets for each row's "Move to space" action — loaded once,
    // shared across rows (empty while loading, so the menu still opens).
    final spaces = ref.watch(filingSpacesProvider).valueOrNull ?? const [];
    final filtered = searchMatomes(items, search);

    // Local-first-spaces #102 W3: the Inbox is the VIEW over effective-space-NULL
    // — loose items AND draft matomes. With the flag ON the LOOSE half renders as
    // [InboxItemCard]s above the (draft-)matome list. The flag is a compile-time
    // const, so with it OFF this whole branch (and the loose-items watch) tree-
    // shakes out and the Inbox is byte-unchanged. A `LooseInboxSection` is a
    // ConsumerWidget that watches the loose controller itself; here we only need
    // to know whether any loose items exist so the empty-state doesn't show while
    // loose items are present.
    final hasLoose = FeatureFlags.localFirstSpaces &&
        (ref.watch(looseInboxControllerProvider).valueOrNull?.isNotEmpty ??
            false);
    const looseSection =
        FeatureFlags.localFirstSpaces ? LooseInboxSection() : SizedBox.shrink();

    // Table view — the columnar counterpart (DR-001). One flat, sortable list
    // (no date sections); selection + bulk actions + per-row menu + undo all
    // live in the widget. Open routes through the same [onTap] as the cards.
    if (view == InboxView.table) {
      final byId = {for (final m in filtered) m.id: m};
      final rows = [
        for (final m in filtered)
          matomeTableRowFromItem(
            m,
            relativeWhen: formatTimestamp(
              DateTime.fromMillisecondsSinceEpoch(m.happenedAt),
            ),
          ),
      ];
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.sm,
            spacing.md,
            spacing.xxl + spacing.xxl,
          ),
          children: [
            looseSection,
            MatomeTable(
              rows: rows,
              onOpen: (id) {
                final item = byId[id];
                if (item != null) onTap(item);
              },
              onBulk: onTableBulk,
            ),
          ],
        ),
      );
    }

    final sections = groupMatomesByDate(
      filtered,
      todayLabel: 'Today',
      yesterdayLabel: 'Yesterday',
    );

    if (sections.isEmpty && !hasLoose) {
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

    // No matomes but loose items present (flag ON): render just the loose list.
    if (sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: colors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            spacing.md,
            spacing.sm,
            spacing.md,
            spacing.xxl + spacing.xxl,
          ),
          children: const [looseSection],
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
        // +1 leading slot for the loose-items section (flag ON only); index 0
        // is the loose section, the matome date-sections follow it.
        itemCount: sections.length + (hasLoose ? 1 : 0),
        itemBuilder: (context, rawIndex) {
          if (hasLoose && rawIndex == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: looseSection,
            );
          }
          final index = hasLoose ? rawIndex - 1 : rawIndex;
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
                          GoRouter.of(context).push('/matome/${item.id}'),
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
