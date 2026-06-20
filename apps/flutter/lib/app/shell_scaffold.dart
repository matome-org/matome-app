import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/home/inbox_upload.dart';
import '../features/recording/meeting_recorder.dart';
import '../i18n/strings.g.dart';
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
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
