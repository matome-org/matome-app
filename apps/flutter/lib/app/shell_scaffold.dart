import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../i18n/strings.g.dart';

/// Bottom navigation shell mirroring the RN `NavBar`: four tabs split around a
/// raised center mic FAB (Inbox / Calendar — [mic] — Spaces / Satori). The FAB
/// pushes the `/recording` fullscreen modal; the tabs swap the inner
/// [StatefulNavigationShell] branch (preserving each tab's own stack).
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        heroTag: 'mic-fab',
        tooltip: t.recording.title,
        onPressed: () => context.push('/recording'),
        child: const Icon(Icons.mic),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _ShellBottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _goBranch,
      ),
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
