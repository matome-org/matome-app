// Proposal use-cases for a reworked primary navigation — mobile + desktop.
//
// Replaces what we ship today (a notched BottomAppBar with a docked mic FAB on
// mobile, and Material's default NavigationRail on desktop) with one branded,
// warm-editorial navigation language:
//
//   * Mobile → a floating rounded "dock". The active destination expands into a
//     gold-tinted pill that shows its label; the rest stay icon-only. Capture is
//     a clean offset gold FAB — no notch cut-out, no center-docked hack.
//   * Desktop → a branded left sidebar: wordmark, a prominent gold Capture
//     button with a caret for record / meeting / add-file, the destination list
//     (active = a soft rounded tint, never a colored left-stripe), and a footer
//     with Settings + the account avatar. Collapses to an icon-only rail.
//
// Same five destinations the router already drives (Inbox · Calendar · Spaces ·
// Satori · Contacts, feature-flag gated upstream). Static, provider-free mockup
// for design validation — selection is local widget state; Capture / taps are
// no-ops. Copy switches with the Widgetbook Localization addon (en / ja).

import 'package:flutter/material.dart';
import 'package:matome_flutter/core/theme/app_theme.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

// ─── Destinations ────────────────────────────────────────────────────────────

enum NavDest { inbox, calendar, files, contacts, spaces, satori }

/// Destinations shown in the nav, in order. Satori is intentionally hidden for
/// now (kept in the enum / specs so it can be re-enabled without rework).
const _visibleDests = <NavDest>[
  NavDest.inbox,
  NavDest.calendar,
  NavDest.files,
  NavDest.contacts,
  NavDest.spaces,
];

class _DestSpec {
  const _DestSpec(this.icon, this.selectedIcon, this.en, this.ja);
  final IconData icon;
  final IconData selectedIcon;
  final String en;
  final String ja;
}

const _specs = <NavDest, _DestSpec>{
  NavDest.inbox: _DestSpec(Icons.inbox_outlined, Icons.inbox, 'Inbox', '受信箱'),
  NavDest.calendar: _DestSpec(
      Icons.calendar_today_outlined, Icons.calendar_today, 'Calendar', 'カレンダー'),
  NavDest.files: _DestSpec(
      Icons.description_outlined, Icons.description, 'Files', 'ファイル'),
  NavDest.contacts:
      _DestSpec(Icons.contacts_outlined, Icons.contacts, 'Contacts', '連絡先'),
  NavDest.spaces:
      _DestSpec(Icons.folder_outlined, Icons.folder, 'Spaces', 'スペース'),
  NavDest.satori: _DestSpec(
      Icons.auto_awesome_outlined, Icons.auto_awesome, 'Satori', 'さとり'),
};

bool _isJa(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ja';

String _label(BuildContext context, NavDest d) =>
    _isJa(context) ? _specs[d]!.ja : _specs[d]!.en;

String _addLabel(BuildContext context) => _isJa(context) ? '追加' : 'Add';
String _settingsLabel(BuildContext context) => _isJa(context) ? '設定' : 'Settings';
String _accountName(BuildContext context) => _isJa(context) ? '田中 美香' : 'Mika Tanaka';

/// The hero "Add" action's menu — the one entry point for everything you can
/// bring into a matome: start a recording, add a photo, attach a file, capture
/// a meeting. (Not a record-only button.)
List<(IconData, String)> _addOptions(BuildContext context) {
  final ja = _isJa(context);
  return [
    (Icons.mic_none_rounded, ja ? '録音する' : 'Record audio'),
    (Icons.photo_camera_outlined, ja ? '写真を追加' : 'Add photo'),
    (Icons.upload_file, ja ? 'ファイルを追加' : 'Add file'),
    (Icons.groups_outlined, ja ? '会議を録音' : 'Record meeting'),
  ];
}

List<Widget> _addMenuChildren(BuildContext context) {
  final colors = context.colors;
  final typography = context.typography;
  return [
    for (final (icon, label) in _addOptions(context))
      MenuItemButton(
        leadingIcon: Icon(icon, size: 18, color: colors.textSecondary),
        onPressed: () {}, // mock — host wires record / picker / upload
        child: Text(
          label,
          style: typography.bodySmall.copyWith(color: colors.textPrimary),
        ),
      ),
  ];
}

MenuStyle _addMenuStyle(BuildContext context) {
  final colors = context.colors;
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(colors.surface),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(context.radius.md),
        side: BorderSide(color: colors.border),
      ),
    ),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(vertical: context.spacing.xs),
    ),
  );
}

// ─── Use cases: mobile ───────────────────────────────────────────────────────

@widgetbook.UseCase(
  name: 'Mobile dock — in context',
  type: MatomeBottomDock,
  path: '[Proposals]/Navigation',
)
Widget mobileDockInContextUseCase(BuildContext context) {
  return const _PhoneFrame(child: _MobileNavDemo());
}

@widgetbook.UseCase(
  name: 'Mobile dock — bare',
  type: MatomeBottomDock,
  path: '[Proposals]/Navigation',
)
Widget mobileDockBareUseCase(BuildContext context) {
  return const _Surface(
    width: 400,
    child: _BareDock(),
  );
}

// ─── Use cases: desktop ──────────────────────────────────────────────────────

@widgetbook.UseCase(
  name: 'Desktop sidebar — expanded',
  type: MatomeSidebar,
  path: '[Proposals]/Navigation',
)
Widget desktopSidebarExpandedUseCase(BuildContext context) {
  return const _WindowFrame(expanded: true);
}

@widgetbook.UseCase(
  name: 'Desktop sidebar — collapsed (rail)',
  type: MatomeSidebar,
  path: '[Proposals]/Navigation',
)
Widget desktopSidebarCollapsedUseCase(BuildContext context) {
  return const _WindowFrame(expanded: false);
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE — floating dock
// ═══════════════════════════════════════════════════════════════════════════

/// The floating bottom navigation dock. Active destination expands into a
/// gold-tinted label pill; the rest are icon-only targets.
class MatomeBottomDock extends StatelessWidget {
  const MatomeBottomDock({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final NavDest selected;
  final ValueChanged<NavDest> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: spacing.md),
      padding:
          EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(radius.xl),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final d in _visibleDests)
            _DockItem(
              dest: d,
              active: d == selected,
              onTap: () => onSelect(d),
            ),
        ],
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.dest,
    required this.active,
    required this.onTap,
  });

  final NavDest dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final spec = _specs[dest]!;
    final label = _label(context, dest);

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: active ? spacing.sm : spacing.sm,
            vertical: spacing.sm,
          ),
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(radius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? spec.selectedIcon : spec.icon,
                size: 22,
                color: active ? colors.accentDark : colors.textMuted,
              ),
              // Label only on the active pill — kept out of the layout when
              // inactive so the dock stays compact.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: active
                    ? Padding(
                        padding: EdgeInsets.only(left: spacing.xs),
                        child: Text(
                          label,
                          style: typography.label.copyWith(
                            color: colors.accentDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The offset gold "Add" FAB — the single entry point for adding anything to a
/// matome (record / photo / file / meeting). Tapping opens the add menu; it is
/// NOT a record-only button.
class _AddFab extends StatelessWidget {
  const _AddFab();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MenuAnchor(
      style: _addMenuStyle(context),
      alignmentOffset: const Offset(0, 8),
      menuChildren: _addMenuChildren(context),
      builder: (context, controller, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.accentDark.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: Tooltip(
                message: _addLabel(context),
                child: Icon(Icons.add, color: colors.onAccent, size: 28),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Interactive mobile preview: faux content + the dock + the capture FAB.
class _MobileNavDemo extends StatefulWidget {
  const _MobileNavDemo();

  @override
  State<_MobileNavDemo> createState() => _MobileNavDemoState();
}

class _MobileNavDemoState extends State<_MobileNavDemo> {
  NavDest _selected = NavDest.inbox;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return Stack(
      children: [
        // Faux screen content behind the dock.
        Positioned.fill(child: _FauxContent(title: _label(context, _selected))),
        // Capture FAB, sitting just above the dock on the trailing side.
        Positioned(
          right: spacing.lg,
          bottom: 84 + spacing.sm,
          child: const _AddFab(),
        ),
        // The dock.
        Positioned(
          left: 0,
          right: 0,
          bottom: spacing.md,
          child: SafeArea(
            top: false,
            child: MatomeBottomDock(
              selected: _selected,
              onSelect: (d) => setState(() => _selected = d),
            ),
          ),
        ),
        // Subtle gradient so the dock reads as floating over scrollable content.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 96,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colors.background.withValues(alpha: 0),
                    colors.background.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The dock on its own surface (no phone frame) for tweaking spacing / states.
class _BareDock extends StatefulWidget {
  const _BareDock();

  @override
  State<_BareDock> createState() => _BareDockState();
}

class _BareDockState extends State<_BareDock> {
  NavDest _selected = NavDest.inbox;

  @override
  Widget build(BuildContext context) {
    return MatomeBottomDock(
      selected: _selected,
      onSelect: (d) => setState(() => _selected = d),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DESKTOP — sidebar
// ═══════════════════════════════════════════════════════════════════════════

/// The desktop primary navigation sidebar. [expanded] shows the wordmark, the
/// full Capture button, and destination labels; collapsed is an icon-only rail.
class MatomeSidebar extends StatelessWidget {
  const MatomeSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.expanded,
    required this.onToggle,
  });

  final NavDest selected;
  final ValueChanged<NavDest> onSelect;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? 248 : 76,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(expanded: expanded, onToggle: onToggle),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.sm,
              spacing.xs,
              spacing.sm,
              spacing.md,
            ),
            child: _AddButton(expanded: expanded),
          ),
          // Destinations.
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              children: [
                for (final d in _visibleDests)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.xxs),
                    child: _SidebarItem(
                      dest: d,
                      active: d == selected,
                      expanded: expanded,
                      onTap: () => onSelect(d),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          _SidebarFooter(expanded: expanded),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.md,
        spacing.xs,
        spacing.sm,
      ),
      child: Row(
        children: [
          if (expanded) ...[
            // Wordmark — display type, the one place the brand voice speaks.
            Expanded(
              child: Text(
                'matome',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 22,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.menu_open, size: 20, color: colors.textMuted),
              tooltip: 'Collapse',
              onPressed: onToggle,
            ),
          ] else
            Expanded(
              child: Center(
                child: IconButton(
                  icon: Icon(Icons.menu, size: 22, color: colors.textMuted),
                  tooltip: 'Expand',
                  onPressed: onToggle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The primary "Add" button — opens the add menu (record / photo / file /
/// meeting). Collapsed it's a gold `+` tile; expanded it's a labelled button
/// with a caret. Not a record-only button.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return MenuAnchor(
      style: _addMenuStyle(context),
      alignmentOffset: const Offset(0, 6),
      menuChildren: _addMenuChildren(context),
      builder: (context, controller, child) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();

        if (!expanded) {
          return Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(radius.md),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius.md),
                  onTap: toggle,
                  child: Tooltip(
                    message: _addLabel(context),
                    child: Icon(Icons.add, color: colors.onAccent, size: 24),
                  ),
                ),
              ),
            ),
          );
        }

        return Material(
          color: colors.accent,
          borderRadius: BorderRadius.circular(radius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius.md),
            onTap: toggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.add, color: colors.onAccent, size: 20),
                  SizedBox(width: spacing.xs),
                  Expanded(
                    child: Text(
                      _addLabel(context),
                      style: typography.label.copyWith(
                        color: colors.onAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more, color: colors.onAccent, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.dest,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  final NavDest dest;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final spec = _specs[dest]!;
    final label = _label(context, dest);

    // Active state = a soft rounded tint with a bolder icon/label — no colored
    // left-stripe (an overused, templated accent we deliberately avoid).
    final fg = active ? colors.accentDark : colors.textSecondary;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? spacing.sm : 0,
        vertical: spacing.sm,
      ),
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(active ? spec.selectedIcon : spec.icon, size: 22, color: fg),
          if (expanded) ...[
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.bodySmall.copyWith(
                  color: fg,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Tooltip(
        message: expanded ? '' : label,
        child: Material(
          color: active ? colors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(radius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius.md),
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    final settings = _settingsLabel(context);

    return Padding(
      padding: EdgeInsets.all(spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings.
          Tooltip(
            message: expanded ? '' : settings,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(radius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(radius.md),
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: expanded ? spacing.sm : 0,
                    vertical: spacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: expanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings_outlined,
                          size: 22, color: colors.textSecondary),
                      if (expanded) ...[
                        SizedBox(width: spacing.sm),
                        Expanded(
                          child: Text(
                            settings,
                            style: typography.bodySmall
                                .copyWith(color: colors.textSecondary),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: spacing.xxs),
          // Account.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? spacing.sm : 0,
              vertical: spacing.xs,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: colors.textPrimary,
                  child: Text(
                    'M',
                    style: typography.label.copyWith(
                      color: colors.onTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (expanded) ...[
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      _accountName(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall
                          .copyWith(color: colors.textPrimary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop preview: the sidebar beside a faux content pane, with a working
/// collapse toggle and destination selection.
class _WindowFrame extends StatefulWidget {
  const _WindowFrame({required this.expanded});

  final bool expanded;

  @override
  State<_WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<_WindowFrame> {
  late bool _expanded = widget.expanded;
  NavDest _selected = NavDest.inbox;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(radius.lg),
                border: Border.all(color: colors.border),
              ),
              child: SizedBox(
                height: 560,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MatomeSidebar(
                      selected: _selected,
                      onSelect: (d) => setState(() => _selected = d),
                      expanded: _expanded,
                      onToggle: () => setState(() => _expanded = !_expanded),
                    ),
                    Expanded(
                      child: _FauxContent(title: _label(context, _selected)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared scaffolding
// ═══════════════════════════════════════════════════════════════════════════

/// A neutral faux screen body so the nav can be validated in context without
/// pulling in real screens.
class _FauxContent extends StatelessWidget {
  const _FauxContent({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final typography = context.typography;

    return Container(
      color: colors.background,
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: spacing.sm),
          Text(
            title,
            style: typography.title.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.lg),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: EdgeInsets.only(bottom: spacing.sm),
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(context.radius.md),
                  border: Border.all(color: colors.border),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A phone-ish frame for the mobile dock preview.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: 360,
            height: 720,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: colors.border, width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.width = 400});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: child,
        ),
      ),
    );
  }
}
