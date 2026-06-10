import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      body: navigationShell,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDesktop) ...[
            _MeetingFab(),
            const SizedBox(height: 12),
          ],
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
        onTap: _goBranch,
      ),
    );
  }
}

/// Desktop "Record meeting" FAB. Probes the loopback capability gate: enabled
/// when the host can capture (Linux + ffmpeg + a monitor source), otherwise
/// rendered disabled with the precise unsupported reason as its tooltip. Never
/// hidden — a disabled-with-reason entry is clearer than a missing one.
class _MeetingFab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(meetingCaptureCapabilityProvider);
    return FutureBuilder<String?>(
      // null reason ⇒ supported. While probing, optimistically enable.
      future: capability.unsupportedReason(),
      builder: (context, snapshot) {
        final reason = snapshot.data;
        final probing = snapshot.connectionState == ConnectionState.waiting;
        final supported = probing || reason == null;
        return FloatingActionButton.extended(
          heroTag: 'meeting-fab',
          tooltip: supported ? null : reason,
          backgroundColor: supported ? null : Theme.of(context).disabledColor,
          onPressed: supported ? () => context.push('/meeting') : null,
          icon: const Icon(Icons.groups, size: 20),
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
    return BottomAppBar(
      height: 64,
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
          const SizedBox(width: 48), // gap for the FAB notch
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
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 10, height: 1.1),
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
