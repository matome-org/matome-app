import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../i18n/strings.g.dart';
import '../../../ui/avatar.dart';

/// Graduated from the approved nav proposal (DR-002, #1466) per the DR-000
/// convergence procedure. PRESENTATIONAL only: [MatomeBottomDock] (mobile) and
/// [MatomeSidebar] (desktop) take a list of [NavDestinationSpec]s + a
/// `selectedId` and emit callbacks ([onSelect], [onToggle], [onAddOption],
/// [onSettings]) — NO providers, NO router/navigation, NO DB. The shell host
/// builds the destination list from the [ShellTab]s the router drives and wires
/// the callbacks; satori is excluded by the CALLER, not hardcoded here. Copy is
/// slang `t.nav.*` plus the per-tab titles supplied in each spec's [label].
///
/// The hero action is an "Add" entry point (icon `+`) — NOT a record-only mic.
/// Tapping it opens a menu with [NavAddOption.values] (record audio · add photo
/// · add file · record meeting); the chosen option is surfaced via
/// [onAddOption] so the host can route to the right picker / recorder.

// ─── Public model ────────────────────────────────────────────────────────────

/// One primary navigation destination, supplied by the caller. Identity is the
/// opaque [id] string (the host maps it to a route); the widget never inspects
/// it beyond equality against `selectedId`.
class NavDestinationSpec {
  const NavDestinationSpec({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Caller-owned identity (e.g. a [ShellTab] location). Compared to the
  /// active `selectedId` to pick the selected destination.
  final String id;

  /// Glyph shown when the destination is inactive.
  final IconData icon;

  /// Glyph shown when the destination is active (typically the filled variant).
  final IconData selectedIcon;

  /// Already-localised label (the host passes the tab's `t.*.title`).
  final String label;
}

/// The options behind the hero "Add" action — the single entry point for
/// everything you can bring into a matome. The widget renders them; the host
/// decides what each one does via [onAddOption].
enum NavAddOption { recordAudio, addPhoto, addFile, recordMeeting }

extension NavAddOptionX on NavAddOption {
  IconData get icon => switch (this) {
    NavAddOption.recordAudio => Icons.mic_none_rounded,
    NavAddOption.addPhoto => Icons.photo_camera_outlined,
    NavAddOption.addFile => Icons.upload_file,
    NavAddOption.recordMeeting => Icons.groups_outlined,
  };

  String label(Translations t) => switch (this) {
    NavAddOption.recordAudio => t.nav.recordAudio,
    NavAddOption.addPhoto => t.nav.addPhoto,
    NavAddOption.addFile => t.nav.addFile,
    NavAddOption.recordMeeting => t.nav.recordMeeting,
  };
}

// ─── Component-owned dimensions ──────────────────────────────────────────────
// Reviewed, nav-specific sizes that have no token rung. Kept as named constants
// so they read as deliberate component primitives (and so the design-system
// source guard sees no ad-hoc inline visual literals).

/// WCAG 2.5.5 minimum interactive target.
const double _kMinTapTarget = 48;

/// Zero inset, named so the collapsed-rail "no horizontal padding" branch reads
/// as an intentional component primitive (not an ad-hoc magic number).
const double _kZero = 0;

/// Active-destination / inactive nav glyph size.
const double _kNavIconSize = 22;

/// Mobile "Add" FAB diameter.
const double _kFabSize = 56;

/// Mobile FAB glyph size.
const double _kFabIconSize = 28;

/// Desktop collapsed "Add" tile side.
const double _kAddTileSize = 48;

/// Account avatar diameter in the sidebar footer.
const double _kAccountAvatarSize = 32;

/// Expanded sidebar width.
const double kSidebarExpandedWidth = 248;

/// Collapsed icon-only rail width.
const double kSidebarRailWidth = 76;

const Duration _kAnim = Duration(milliseconds: 220);
const Curve _kCurve = Curves.easeOutCubic;

// ─── Shared add-menu plumbing ────────────────────────────────────────────────

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

List<Widget> _addMenuChildren(
  BuildContext context,
  ValueChanged<NavAddOption>? onAddOption,
  List<NavAddOption> options,
) {
  final colors = context.colors;
  final typography = context.typography;
  final t = Translations.of(context);
  return [
    for (final option in options)
      MenuItemButton(
        leadingIcon: Icon(
          option.icon,
          size: typography.body.fontSize,
          color: colors.textSecondary,
        ),
        onPressed: onAddOption == null ? null : () => onAddOption(option),
        child: Text(
          option.label(t),
          style: typography.bodySmall.copyWith(color: colors.textPrimary),
        ),
      ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE — floating dock
// ═══════════════════════════════════════════════════════════════════════════

/// The floating bottom navigation dock. The active destination expands into a
/// gold-tinted label pill; the rest stay icon-only. It does NOT host the "Add"
/// FAB itself — the FAB ([MatomeAddFab]) is positioned by the shell just above
/// the dock so it can float over scrollable content.
class MatomeBottomDock extends StatelessWidget {
  const MatomeBottomDock({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    this.onSettings,
  });

  final List<NavDestinationSpec> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;

  /// Opens Settings. The mobile dock has no other entry point to Settings (the
  /// desktop sidebar carries its own tile), so a persistent account/profile
  /// affordance at the dock's trailing edge keeps it reachable from every
  /// screen. Null hides the affordance.
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;

    // Single floating bar: the border lives on the Material's own shape (with
    // the shadow), and the side-gap is OUTER padding. A bordered inner Container
    // inset from the Material edge previously drew a second rounded rect — the
    // "weird inner border".
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.md),
      child: Material(
        color: colors.surface,
        elevation: context.elevation.level3,
        shadowColor: colors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius.xl),
          side: BorderSide(color: colors.border),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.xs,
            vertical: spacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final dest in destinations)
                // The active pill grows by its label; on narrow widths the
                // packed destinations + trailing account affordance would
                // overflow, so each item is loose-flexible and the active
                // label ellipsizes under pressure rather than overrunning.
                Flexible(
                  child: _DockItem(
                    dest: dest,
                    active: dest.id == selectedId,
                    onTap: () => onSelect(dest.id),
                  ),
                ),
              // Persistent account/profile → Settings affordance. The trailing
              // edge keeps it clear of the navigation destinations and mirrors
              // the sidebar footer's account row.
              if (onSettings != null) _DockSettingsButton(onTap: onSettings!),
            ],
          ),
        ),
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

  final NavDestinationSpec dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    return Semantics(
      button: true,
      selected: active,
      label: dest.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius.pill),
        // The wrapping Semantics already names this destination; exclude the
        // inner glyph/label so the active pill's Text doesn't add a duplicate
        // node under the same label.
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _kMinTapTarget,
              minHeight: _kMinTapTarget,
            ),
            child: AnimatedContainer(
              duration: _kAnim,
              curve: _kCurve,
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm,
                vertical: spacing.sm,
              ),
              decoration: BoxDecoration(
                color: active ? colors.accentSoft : null,
                borderRadius: BorderRadius.circular(radius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active ? dest.selectedIcon : dest.icon,
                    size: _kNavIconSize,
                    color: active ? colors.accentDark : colors.textMuted,
                  ),
                  // Label only on the active pill — kept out of the layout when
                  // inactive so the dock stays compact.
                  // Label only on the active pill, and flexible so it ellipsizes
                  // (rather than overrunning) when the packed dock is narrow.
                  Flexible(
                    child: AnimatedSize(
                      duration: _kAnim,
                      curve: _kCurve,
                      child: active
                          ? Padding(
                              padding: EdgeInsets.only(left: spacing.xs),
                              child: Text(
                                dest.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.label.copyWith(
                                  color: colors.accentDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dock's trailing account/profile avatar — the mobile entry point to
/// Settings. The mobile dock otherwise has no Settings affordance (the desktop
/// sidebar carries its own tile), so this keeps it reachable from every screen.
/// A circular [Avatar] with a generic person glyph; tapping calls `onTap`.
class _DockSettingsButton extends StatelessWidget {
  const _DockSettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = context.radius;
    final t = Translations.of(context);

    return Semantics(
      button: true,
      label: t.settings.title,
      child: Tooltip(
        message: t.settings.title,
        child: InkWell(
          key: const ValueKey('nav-dock-settings'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius.pill),
          // The wrapping Semantics already names this control; keep the inner
          // avatar from adding a second node under the same label.
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: Center(
                child: Avatar(
                  size: _kAccountAvatarSize,
                  backgroundColor: colors.textPrimary,
                  foregroundColor: colors.onTextPrimary,
                  icon: Icons.person_outline,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The offset gold "Add" FAB — the single entry point for adding anything to a
/// matome (record / photo / file / meeting). Tapping opens the add menu; it is
/// NOT a record-only button. Presentational: the host positions it and handles
/// the chosen [NavAddOption] via [onAddOption].
class MatomeAddFab extends StatelessWidget {
  const MatomeAddFab({
    super.key,
    this.onAddOption,
    this.options = NavAddOption.values,
  });

  final ValueChanged<NavAddOption>? onAddOption;

  /// The add-menu options to offer. Defaults to all; the host trims options the
  /// active feature flags gate out (e.g. "Add file" when `ff.documents` is off).
  final List<NavAddOption> options;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = Translations.of(context);

    return MenuAnchor(
      style: _addMenuStyle(context),
      alignmentOffset: Offset(0, context.spacing.xs),
      menuChildren: _addMenuChildren(context, onAddOption, options),
      builder: (context, controller, child) {
        return Tooltip(
          message: t.nav.add,
          child: Material(
            color: colors.accent,
            elevation: context.elevation.level3,
            shadowColor: colors.accentDark,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: Semantics(
                button: true,
                label: t.nav.add,
                child: SizedBox(
                  width: _kFabSize,
                  height: _kFabSize,
                  child: Icon(
                    Icons.add,
                    color: colors.onAccent,
                    size: _kFabIconSize,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DESKTOP — sidebar
// ═══════════════════════════════════════════════════════════════════════════

/// The desktop primary navigation sidebar. [expanded] shows the wordmark, the
/// full Add button, and destination labels; collapsed is an icon-only rail.
/// Active destination state is a soft rounded tint — NO colored left-stripe.
class MatomeSidebar extends StatelessWidget {
  const MatomeSidebar({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.expanded,
    required this.onSelect,
    required this.onToggle,
    this.onAddOption,
    this.options = NavAddOption.values,
    this.onSettings,
    this.accountName,
  });

  final List<NavDestinationSpec> destinations;
  final String selectedId;
  final bool expanded;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;
  final ValueChanged<NavAddOption>? onAddOption;

  /// The add-menu options to offer (host trims flag-gated ones, e.g. "Add file"
  /// when `ff.documents` is off). Defaults to all.
  final List<NavAddOption> options;

  final VoidCallback? onSettings;

  /// Account display name shown (expanded only) in the footer; its first glyph
  /// seeds the avatar initial. Null hides the name and shows a generic glyph.
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;

    return AnimatedContainer(
      duration: _kAnim,
      curve: _kCurve,
      width: expanded ? kSidebarExpandedWidth : kSidebarRailWidth,
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
            child: _AddButton(
              expanded: expanded,
              onAddOption: onAddOption,
              options: options,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: spacing.sm),
              children: [
                for (final dest in destinations)
                  Padding(
                    padding: EdgeInsets.only(bottom: spacing.xxs),
                    child: _SidebarItem(
                      dest: dest,
                      active: dest.id == selectedId,
                      expanded: expanded,
                      onTap: () => onSelect(dest.id),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),
          _SidebarFooter(
            expanded: expanded,
            accountName: accountName,
            onSettings: onSettings,
          ),
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
    final t = Translations.of(context);

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
                style: typography.title.copyWith(color: colors.textPrimary),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.menu_open,
                size: _kNavIconSize,
                color: colors.textMuted,
              ),
              tooltip: t.nav.collapse,
              onPressed: onToggle,
            ),
          ] else
            Expanded(
              child: Center(
                child: IconButton(
                  icon: Icon(
                    Icons.menu,
                    size: _kNavIconSize,
                    color: colors.textMuted,
                  ),
                  tooltip: t.nav.expand,
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
  const _AddButton({
    required this.expanded,
    this.onAddOption,
    this.options = NavAddOption.values,
  });

  final bool expanded;
  final ValueChanged<NavAddOption>? onAddOption;
  final List<NavAddOption> options;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final t = Translations.of(context);

    return MenuAnchor(
      style: _addMenuStyle(context),
      alignmentOffset: Offset(0, context.spacing.xxs),
      menuChildren: _addMenuChildren(context, onAddOption, options),
      builder: (context, controller, child) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();

        if (!expanded) {
          return Center(
            child: Tooltip(
              message: t.nav.add,
              child: Material(
                color: colors.accent,
                borderRadius: BorderRadius.circular(radius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius.md),
                  onTap: toggle,
                  child: Semantics(
                    button: true,
                    label: t.nav.add,
                    child: SizedBox(
                      width: _kAddTileSize,
                      height: _kAddTileSize,
                      child: Icon(
                        Icons.add,
                        color: colors.onAccent,
                        size: _kNavIconSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Semantics(
          button: true,
          label: t.nav.add,
          child: Material(
            color: colors.accent,
            borderRadius: BorderRadius.circular(radius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius.md),
              onTap: toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _kMinTapTarget),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.md,
                    vertical: spacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add,
                        color: colors.onAccent,
                        size: typography.body.fontSize,
                      ),
                      SizedBox(width: spacing.xs),
                      Expanded(
                        child: Text(
                          t.nav.add,
                          style: typography.label.copyWith(
                            color: colors.onAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.expand_more,
                        color: colors.onAccent,
                        size: typography.bodySmall.fontSize,
                      ),
                    ],
                  ),
                ),
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

  final NavDestinationSpec dest;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;

    // Active state = a soft rounded tint with a bolder icon/label — no colored
    // left-stripe (an overused, templated accent we deliberately avoid).
    final fg = active ? colors.accentDark : colors.textSecondary;

    // The wrapping Semantics names this destination; exclude the inner
    // icon/label so the visible Text does not add a duplicate labelled node.
    final content = ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? spacing.sm : _kZero,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                active ? dest.selectedIcon : dest.icon,
                size: _kNavIconSize,
                color: fg,
              ),
              if (expanded) ...[
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    dest.label,
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
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: active,
      label: dest.label,
      child: Tooltip(
        message: expanded ? '' : dest.label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active ? colors.accentSoft : null,
            borderRadius: BorderRadius.circular(radius.md),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius.md),
              onTap: onTap,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.expanded,
    required this.accountName,
    required this.onSettings,
  });

  final bool expanded;
  final String? accountName;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final t = Translations.of(context);

    final name = accountName;
    final initial = (name != null && name.trim().isNotEmpty)
        ? name.trim()[0]
        : '?';

    return Padding(
      padding: EdgeInsets.all(spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Settings.
          Semantics(
            button: true,
            label: t.settings.title,
            child: Tooltip(
              message: expanded ? '' : t.settings.title,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(radius.md),
                  onTap: onSettings,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _kMinTapTarget,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: expanded ? spacing.sm : _kZero,
                        vertical: spacing.sm,
                      ),
                      child: Row(
                        mainAxisAlignment: expanded
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: _kNavIconSize,
                            color: colors.textSecondary,
                          ),
                          if (expanded) ...[
                            SizedBox(width: spacing.sm),
                            Expanded(
                              child: Text(
                                t.settings.title,
                                style: typography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: spacing.xxs),
          // Account.
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? spacing.sm : _kZero,
              vertical: spacing.xs,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Avatar(
                  size: _kAccountAvatarSize,
                  backgroundColor: colors.textPrimary,
                  foregroundColor: colors.onTextPrimary,
                  initials: initial,
                  semanticLabel: name,
                ),
                if (expanded && name != null) ...[
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
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
