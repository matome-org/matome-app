import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../features/recording/meeting_recorder.dart';
import '../i18n/strings.g.dart';

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

/// Bottom navigation shell mirroring the RN `NavBar`: four tabs split around a
/// raised center mic FAB (Inbox / Calendar — [mic] — Spaces / Satori). The FAB
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
                    child: Column(
                      children: [
                        FloatingActionButton(
                          heroTag: 'mic-fab',
                          tooltip: t.recording.title,
                          elevation: context.elevation.level0,
                          onPressed: () => context.push('/recording'),
                          child: const Icon(Icons.mic),
                        ),
                        if (_isDesktop) ...[
                          SizedBox(height: spacing.sm),
                          _MeetingFab(extended: extended),
                        ],
                      ],
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.inbox_outlined),
                      selectedIcon: const Icon(Icons.inbox),
                      label: Text(t.inbox.title),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.calendar_today_outlined),
                      selectedIcon: const Icon(Icons.calendar_today),
                      label: Text(t.calendar.title),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.folder_outlined),
                      selectedIcon: const Icon(Icons.folder),
                      label: Text(t.spaces.title),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.auto_awesome_outlined),
                      selectedIcon: const Icon(Icons.auto_awesome),
                      label: Text(t.satori.title),
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

/// Desktop "Record meeting" FAB. Probes the loopback capability gate: enabled
/// when the host can capture (Linux + ffmpeg + a monitor source), otherwise
/// rendered disabled with the precise unsupported reason as its tooltip. Never
/// hidden — a disabled-with-reason entry is clearer than a missing one.
class _MeetingFab extends ConsumerWidget {
  const _MeetingFab({this.extended = true});

  /// When false, renders an icon-only FAB so it fits a collapsed rail.
  final bool extended;

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
        if (!extended) {
          return FloatingActionButton(
            heroTag: 'meeting-fab',
            tooltip: supported ? 'Meeting' : reason,
            elevation: context.elevation.level0,
            backgroundColor: supported ? null : disabledColor,
            onPressed: onPressed,
            child: icon,
          );
        }
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

/// Notched bottom bar with a gap for the docked mic FAB.
class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return BottomAppBar(
      height: spacing.xxl + spacing.md,
      padding: EdgeInsets.zero,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.inbox_outlined,
            label: t.inbox.title,
            selected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.calendar_today_outlined,
            label: t.calendar.title,
            selected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          SizedBox(width: spacing.xxl), // gap for the FAB notch
          _NavItem(
            icon: Icons.folder_outlined,
            label: t.spaces.title,
            selected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: Icons.auto_awesome_outlined,
            label: t.satori.title,
            selected: currentIndex == 3,
            onTap: () => onTap(3),
          ),
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
