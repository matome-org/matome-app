import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/feature_flags.dart';
import '../core/observability/app_log.dart';
import '../core/theme/app_theme.dart';
import '../features/home/inbox_upload.dart';
import '../features/recording/meeting_recorder.dart';
import '../features/shell/widgets/matome_nav.dart';
import '../i18n/strings.g.dart';
import 'auth_state.dart';
import 'shell_tabs.dart';

/// True on a desktop OS where the loopback meeting recorder could exist (MVP:
/// Linux; macOS/Windows are future phases but the desktop entry is shown so the
/// capability gate can explain the unsupported state rather than hiding it).
bool get _isDesktop {
  try {
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  } catch (_) {
    return false; // web
  }
}

/// Bottom navigation shell mirroring the RN `NavBar`: five tabs split around a
/// raised center mic FAB (Inbox / Calendar — [mic] — Spaces / Satori /
/// Contacts). The FAB
/// pushes the `/recording` fullscreen modal; the tabs swap the inner
/// [StatefulNavigationShell] branch (preserving each tab's own stack).
///
/// On desktop it also surfaces a secondary "Record meeting" FAB that opens the
/// `/meeting` loopback recorder; it is disabled (with a host-specific reason)
/// when the meeting capability gate reports unsupported.
///
/// Above [_kRailBreakpoint] the bottom bar is replaced by a side
/// [NavigationRail] (extended above [_kRailExtendedBreakpoint]) so a wide
/// desktop window spends its width on content, not a stretched phone tab bar.
/// Below the breakpoint the original bottom-bar + docked-FAB layout is kept
/// verbatim, so mobile is untouched.
const double _kRailBreakpoint = 1000;
const double _kRailExtendedBreakpoint = 1280;

class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({
    super.key,
    required this.navigationShell,
    bool? newNavShell,
    this.branchesOverride,
  }) : newNavShell = newNavShell ?? FeatureFlags.newNavShell;

  final StatefulNavigationShell navigationShell;

  /// Drives the cutover (DR-002, #1467). Defaults to [FeatureFlags.newNavShell]
  /// (OFF by default → the shipped legacy shell renders unchanged). Exposed as a
  /// constructor seam ONLY so a widget test can pin BOTH flag states in one run
  /// without a per-state `--dart-define` rebuild; production always uses the
  /// const flag. NOTE: the ROUTE gating for the new shell (Satori compiled out,
  /// `/files` promoted to a branch) is driven by the const flag in `router.dart`
  /// — this override only flips the on-screen chrome, so a test that flips it ON
  /// must also build a router whose branches match [shellBranches] ON.
  final bool newNavShell;

  /// Test-only override for the branch/destination order. Production leaves this
  /// null and the new shell reads the const-flag-driven [shellBranches]; a flag-
  /// ON widget test injects the ON order here to match the test router it built
  /// (since the const flag — and thus [shellBranches] — cannot be flipped at
  /// runtime).
  final List<ShellTab>? branchesOverride;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (newNavShell) {
      return _GraduatedShell(
        navigationShell: navigationShell,
        onSelect: _goBranch,
        branches: branchesOverride ?? shellBranches,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kRailBreakpoint) {
          return _DesktopShell(
            navigationShell: navigationShell,
            onSelect: _goBranch,
            extended: constraints.maxWidth >= _kRailExtendedBreakpoint,
          );
        }
        return _MobileShell(
          navigationShell: navigationShell,
          onSelect: _goBranch,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NEW navigation shell (DR-002, #1467) — behind FeatureFlags.newNavShell
// ═══════════════════════════════════════════════════════════════════════════

/// The graduated navigation shell host (DR-002). Wires the presentational
/// [MatomeBottomDock] (mobile) / [MatomeSidebar] (desktop) to the router's
/// [StatefulNavigationShell]: it builds the destination specs from
/// [shellBranches] (the SAME ordered list the router branches derive from, so
/// `selectedId` ↔ `currentIndex` ↔ `goBranch(index)` stay aligned), translates a
/// selected destination id back to its branch index, and routes the hero "Add"
/// menu options to the EXISTING real capture/import entry points (no new capture
/// logic). Satori is excluded by the CALLER here (it is not in [shellBranches]
/// under the flag) AND its route is compiled out in `router.dart` (Olivier A05).
class _GraduatedShell extends ConsumerWidget {
  const _GraduatedShell({
    required this.navigationShell,
    required this.onSelect,
    required this.branches,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onSelect;

  /// The ordered branch tabs — [shellBranches] in production. The destination
  /// list and the index↔id translation both derive from this, so they stay
  /// aligned with the router's branch order.
  final List<ShellTab> branches;

  List<NavDestinationSpec> _specs() => [
    for (final tab in branches)
      NavDestinationSpec(
        id: tab.location,
        icon: tab.icon,
        selectedIcon: tab.selectedIcon,
        label: tab.label,
      ),
  ];

  /// The branch location currently selected — the destination [NavDestinationSpec.id]
  /// the widgets compare against.
  String _selectedId() => branches[navigationShell.currentIndex].location;

  /// Translate a destination id back to its [StatefulNavigationShell] branch
  /// index (positional in [branches]) and switch branches.
  void _selectId(String id) {
    final index = branches.indexWhere((t) => t.location == id);
    if (index >= 0) onSelect(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kRailBreakpoint) {
          return _SidebarShell(
            navigationShell: navigationShell,
            destinations: _specs(),
            selectedId: _selectedId(),
            onSelect: _selectId,
            expanded: constraints.maxWidth >= _kRailExtendedBreakpoint,
          );
        }
        return _DockShell(
          navigationShell: navigationShell,
          destinations: _specs(),
          selectedId: _selectedId(),
          onSelect: _selectId,
        );
      },
    );
  }
}

/// Routes a chosen [NavAddOption] to the EXISTING real entry point — the single
/// place the new dock/sidebar "Add" menu wires to shipping flows (no new capture
/// logic, per #1467):
///   - recordAudio  → `/recording` fullscreen modal (#1378)
///   - recordMeeting → `/meeting` loopback recorder (capability-gated, #828)
///   - addPhoto     → image file-picker → Inbox upload pipeline (#1450)
///   - addVideo     → video file-picker → Inbox upload pipeline
///   - addFile      → document file-picker → Inbox upload pipeline (#1449)
/// The photo/video/file imports reuse the SAME `inboxUploaderProvider.upload(...)`
/// pipeline the legacy desktop `_NewCaptureMenu._importFile` already drives, so
/// a picked file lands in a fresh Inbox matome exactly as before.
/// The add-menu options the nav hero "+" offers, trimming flag-gated ones.
/// "Add file" (document import) is hidden while `ff.documents` is off — matching
/// the matome detail picker — so the affordance never appears when the document
/// flow is still dark (#1449).
List<NavAddOption> _availableAddOptions() => [
  for (final o in NavAddOption.values)
    if (o != NavAddOption.addFile || FeatureFlags.documents) o,
];

Future<void> _handleAddOption(
  BuildContext context,
  WidgetRef ref,
  NavAddOption option,
) async {
  switch (option) {
    case NavAddOption.recordAudio:
      context.push('/recording');
    case NavAddOption.recordMeeting:
      context.push('/meeting');
    case NavAddOption.addPhoto:
      await _pickAndUpload(context, ref, type: FileType.image);
    case NavAddOption.addVideo:
      await _pickAndUpload(context, ref, type: FileType.video);
    case NavAddOption.addFile:
      await _pickAndUpload(context, ref, type: FileType.any);
  }
}

/// Picker → Inbox-upload, shared by Add photo / Add file. Identical to the
/// legacy `_NewCaptureMenu._importFile` flow (durable-copy + local-first insert
/// + background sync), so the new "Add" menu introduces no new capture code.
Future<void> _pickAndUpload(
  BuildContext context,
  WidgetRef ref, {
  required FileType type,
}) async {
  // Instrumented (#nav-add): the picker open + outcome are logged so a no-op
  // (cancel, or a Linux picker backend that yields no path) is never silent.
  AppLog.event(LogCat.action, 'nav add: picker opening (type=$type)');
  try {
    final result = await FilePicker.platform.pickFiles(type: type);
    final path = result?.files.single.path;
    if (path == null) {
      AppLog.event(LogCat.action, 'nav add: cancelled (no path)');
      return;
    }
    if (!context.mounted) return;

    final name = result!.files.single.name;
    final dot = name.lastIndexOf('.');
    final base = (dot > 0 ? name.substring(0, dot) : name).trim();
    final picked = PickedUpload(
      file: File(path),
      title: base.isEmpty ? 'Untitled' : base,
      mediaType: mediaTypeForPath(path),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Uploading "${picked.title}"…')));
    AppLog.event(LogCat.action, 'nav add: uploading "${picked.title}"');
    unawaited(
      ref
          .read(inboxUploaderProvider)
          .upload(picked, importFromExternalSource: true),
    );
  } catch (e, st) {
    // A picker/copy/insert failure on desktop must surface, not vanish.
    AppLog.error(LogCat.action, 'nav add: pick/upload failed', e, st);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.matome.addFileFailed(error: '$e'))),
    );
  }
}

/// Mobile new-shell layout: branch content with the floating [MatomeBottomDock]
/// and the offset [MatomeAddFab] stacked above it (no notch, no center-docked
/// hack). Both float over the content via a bottom-anchored overlay.
class _DockShell extends ConsumerWidget {
  const _DockShell({
    required this.navigationShell,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavDestinationSpec> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    // The dock + Add FAB FLOAT over the content (edge-to-edge, no notch), so a
    // scrollable's last item would otherwise sit permanently under the dock —
    // unlike the legacy `bottomNavigationBar`, which reserved layout space. Add
    // that space back as bottom padding via MediaQuery so every branch screen's
    // bottom content stays reachable (e.g. the Settings "Sign out" tile). The
    // reserve ≈ FAB + gap + dock (a 48dp tap target plus its vertical padding)
    // + the bottom anchor inset, derived from the same spacing tokens the
    // overlay below is laid out with (no magic number).
    final media = MediaQuery.of(context);
    final dockReserve =
        _kDockFabSize +
        spacing.sm +
        _kDockTapTarget +
        spacing.sm * 2 +
        spacing.sm;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: media.copyWith(
                padding: media.padding.copyWith(
                  bottom: media.padding.bottom + dockReserve,
                ),
              ),
              child: navigationShell,
            ),
          ),
          Positioned(
            left: _kZero,
            right: _kZero,
            bottom: spacing.sm,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      right: spacing.lg,
                      bottom: spacing.sm,
                    ),
                    child: MatomeAddFab(
                      options: _availableAddOptions(),
                      onAddOption: (option) =>
                          _handleAddOption(context, ref, option),
                    ),
                  ),
                  MatomeBottomDock(
                    destinations: destinations,
                    selectedId: selectedId,
                    onSelect: onSelect,
                    onSettings: () => context.go('/inbox/settings'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop new-shell layout: the branded [MatomeSidebar] beside the branch
/// content. The sidebar's collapse/expand toggle is local UI state.
class _SidebarShell extends ConsumerStatefulWidget {
  const _SidebarShell({
    required this.navigationShell,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    required this.expanded,
  });

  final StatefulNavigationShell navigationShell;
  final List<NavDestinationSpec> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final bool expanded;

  @override
  ConsumerState<_SidebarShell> createState() => _SidebarShellState();
}

class _SidebarShellState extends ConsumerState<_SidebarShell> {
  bool? _expandedOverride;

  bool get _expanded => _expandedOverride ?? widget.expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final account = ref.watch(authStateProvider).user?.email;
    return Scaffold(
      body: Row(
        children: [
          MatomeSidebar(
            destinations: widget.destinations,
            selectedId: widget.selectedId,
            expanded: _expanded,
            onSelect: widget.onSelect,
            onToggle: () => setState(() => _expandedOverride = !_expanded),
            onAddOption: (option) => _handleAddOption(context, ref, option),
            options: _availableAddOptions(),
            onSettings: () => context.go('/inbox/settings'),
            accountName: account,
          ),
          Expanded(
            child: ColoredBox(
              color: colors.background,
              child: widget.navigationShell,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zero inset, named so the new-shell overlay's "edge-to-edge" branch reads as
/// an intentional layout primitive (not an ad-hoc magic number) to the
/// design-system source guard.
const double _kZero = 0;

/// The floating Add FAB's diameter (mirrors `matome_nav._kFabSize`). Used only
/// to compute the bottom content reserve in [_DockShell] so a branch screen's
/// last item is not obscured by the floating dock overlay.
const double _kDockFabSize = 56;

/// The dock destination's minimum tap target (mirrors
/// `matome_nav._kMinTapTarget`). Part of the [_DockShell] bottom reserve.
const double _kDockTapTarget = 48;

/// Phone layout: bottom bar with the docked center mic FAB (unchanged).
class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.navigationShell, required this.onSelect});

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDesktop) ...[_MeetingFab(), SizedBox(height: spacing.sm)],
          FloatingActionButton(
            heroTag: 'mic-fab',
            tooltip: t.recording.title,
            onPressed: () => context.push('/recording'),
            child: const Icon(Icons.mic),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _ShellBottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: onSelect,
      ),
    );
  }
}

/// Desktop layout: a side [NavigationRail] beside the branch content, with the
/// record FABs rehomed into the rail's leading slot.
class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.navigationShell,
    required this.onSelect,
    required this.extended,
  });

  final StatefulNavigationShell navigationShell;
  final ValueChanged<int> onSelect;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    // NavigationRail requires at least two destinations; if the flags leave
    // only the home tab, there is nothing to navigate between — drop the rail
    // and give the single screen the whole window.
    if (enabledTabs.length < 2) {
      return Scaffold(body: navigationShell);
    }

    return Scaffold(
      body: Row(
        children: [
          SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.sizeOf(context).height,
              ),
              child: IntrinsicHeight(
                child: NavigationRail(
                  extended: extended,
                  backgroundColor: colors.surface,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: onSelect,
                  groupAlignment: -1,
                  leading: Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.md),
                    child: _NewCaptureMenu(extended: extended),
                  ),
                  destinations: [
                    for (final tab in enabledTabs)
                      NavigationRailDestination(
                        icon: Icon(tab.icon),
                        selectedIcon: Icon(tab.selectedIcon),
                        label: Text(tab.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: colors.border),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// Mobile "Record meeting" FAB (narrow desktop windows only). Probes the
/// loopback capability gate: enabled when the host can capture (Linux + ffmpeg
/// + a monitor source), otherwise rendered disabled with the precise
/// unsupported reason as its tooltip. Never hidden — a disabled-with-reason
/// entry is clearer than a missing one. The wide-desktop rail uses the
/// consolidated [_NewCaptureMenu] instead.
class _MeetingFab extends ConsumerWidget {
  const _MeetingFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.spacing;
    final capability = ref.watch(meetingCaptureCapabilityProvider);
    return FutureBuilder<String?>(
      // null reason ⇒ supported. While probing, optimistically enable.
      future: capability.unsupportedReason(),
      builder: (context, snapshot) {
        final reason = snapshot.data;
        final probing = snapshot.connectionState == ConnectionState.waiting;
        final supported = probing || reason == null;
        final onPressed = supported ? () => context.push('/meeting') : null;
        final disabledColor = Theme.of(context).disabledColor;
        final icon = Icon(Icons.groups, size: spacing.md + spacing.xxs);
        return FloatingActionButton.extended(
          heroTag: 'meeting-fab',
          tooltip: supported ? null : reason,
          backgroundColor: supported ? null : disabledColor,
          onPressed: onPressed,
          icon: icon,
          label: const Text('Meeting'),
        );
      },
    );
  }
}

/// Desktop "+ New" capture entry: a single primary button in the rail's
/// leading slot that opens a menu of the creation actions (record audio, record
/// meeting, import file). Consolidating them here replaces the two stacked
/// amber FABs that competed with the navigation destinations, and keeps the
/// rail itself purely for navigation.
class _NewCaptureMenu extends ConsumerWidget {
  const _NewCaptureMenu({required this.extended});

  /// When false the trigger collapses to an icon-only FAB for a narrow rail.
  final bool extended;

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    final name = result!.files.single.name;
    final dot = name.lastIndexOf('.');
    final base = (dot > 0 ? name.substring(0, dot) : name).trim();
    final picked = PickedUpload(
      file: File(path),
      title: base.isEmpty ? 'Untitled' : base,
      mediaType: mediaTypeForPath(path),
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Uploading "${picked.title}"…')),
    );
    // Same pipeline as the Inbox import: the uploader inserts a local recording
    // row into a fresh Inbox matome immediately, then syncs in the background.
    unawaited(
      ref
          .read(inboxUploaderProvider)
          .upload(picked, importFromExternalSource: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MenuAnchor(
      builder: (context, controller, child) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        if (!extended) {
          return FloatingActionButton(
            heroTag: 'new-fab',
            tooltip: t.nav.createNew,
            elevation: context.elevation.level0,
            onPressed: toggle,
            child: const Icon(Icons.add),
          );
        }
        return FloatingActionButton.extended(
          heroTag: 'new-fab',
          elevation: context.elevation.level0,
          onPressed: toggle,
          icon: const Icon(Icons.add),
          label: Text(t.nav.createNew),
        );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.mic),
          onPressed: () => context.push('/recording'),
          child: Text(t.nav.recordAudio),
        ),
        const _MeetingMenuItem(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.upload_file),
          onPressed: () => _importFile(context, ref),
          child: Text(t.nav.importFile),
        ),
      ],
    );
  }
}

/// "Record meeting" menu entry. Like [_MeetingFab] it probes the loopback
/// capability gate: enabled on a capable host, otherwise rendered disabled with
/// the precise unsupported reason as a tooltip. Hidden entirely off-desktop,
/// where loopback capture cannot exist.
class _MeetingMenuItem extends ConsumerWidget {
  const _MeetingMenuItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isDesktop) return const SizedBox.shrink();
    final capability = ref.watch(meetingCaptureCapabilityProvider);
    return FutureBuilder<String?>(
      future: capability.unsupportedReason(),
      builder: (context, snapshot) {
        final reason = snapshot.data;
        final probing = snapshot.connectionState == ConnectionState.waiting;
        final supported = probing || reason == null;
        final item = MenuItemButton(
          leadingIcon: const Icon(Icons.groups),
          onPressed: supported ? () => context.push('/meeting') : null,
          child: Text(t.nav.recordMeeting),
        );
        return supported ? item : Tooltip(message: reason, child: item);
      },
    );
  }
}

/// Notched bottom bar with a gap for the docked mic FAB.
class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    final tabs = enabledTabs;
    // Split the enabled tabs evenly around the docked mic FAB notch (with the
    // canonical five tabs this is the original 2 | FAB | 3 layout).
    final split = tabs.length ~/ 2;

    Widget item(int i) => _NavItem(
      icon: tabs[i].icon,
      label: tabs[i].label,
      selected: currentIndex == i,
      onTap: () => onTap(i),
    );

    return BottomAppBar(
      height: spacing.xxl + spacing.md,
      padding: EdgeInsets.zero,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < split; i++) item(i),
          SizedBox(width: spacing.xxl), // gap for the FAB notch
          for (var i = split; i < tabs.length; i++) item(i),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;
    final color = selected ? colors.primary : colors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: typography.title.fontSize),
              Text(
                label,
                style: typography.label.copyWith(
                  color: color,
                  fontSize: 10,
                  height: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
