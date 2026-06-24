/// The reusable master–detail shell.
///
/// This is the single, presentational implementation of the layout the
/// approved Widgetbook proposal (`[Proposals]/Master–detail layout`)
/// demonstrated: on [WidthClass.expanded] widths with a reading-pane mode that
/// shows the pane, the surface renders its list (master) beside a reading pane
/// (detail); everywhere else it renders the master full-width and tapping an
/// item navigates to a full-screen detail instead.
///
/// [MasterDetailScaffold] is PURE: it takes pre-built widgets and a
/// [ReadingPaneMode], and decides only *layout* from the current width class.
/// It owns no Riverpod providers, no per-surface logic, and no navigation —
/// those live in the surface that hosts it. The static
/// [MasterDetailScaffold.selectsOnTap] predicate is the ONE source of truth a
/// surface consults to decide whether a tap selects (pane mode + expanded) or
/// navigates (otherwise), so the scaffold's layout decision and the surface's
/// interaction decision can never drift.
library;

import 'package:flutter/material.dart';

import '../core/layout/breakpoints.dart';
import '../core/theme/app_theme.dart';

/// How the reading (detail) pane behaves for a surface.
///
/// Owned here; the per-surface provider that drives it imports this enum.
///   * [always] — pane alongside the master whenever the width class is
///     [WidthClass.expanded], showing the selection (or the empty state when
///     nothing is selected). On narrower widths it degrades to full-width
///     master + navigate-on-tap.
///   * [onClick] — like [always], but the pane only appears once something is
///     selected: the master is full-width until a selection exists, and the
///     first tap opens the split. On narrower widths it degrades to full-width
///     master + navigate-on-tap.
///   * [off] — never show a side pane; master is always full-width.
enum ReadingPaneMode { always, onClick, off }

/// Reusable, presentational master–detail shell. See the library docs.
class MasterDetailScaffold extends StatelessWidget {
  const MasterDetailScaffold({
    super.key,
    required this.master,
    this.detail,
    required this.emptyState,
    required this.mode,
    this.onClosePane,
  });

  /// The master column (list/table). Always rendered.
  final Widget master;

  /// The pane content for the current selection, or `null` when nothing is
  /// selected. Only consulted when the pane is shown.
  final Widget? detail;

  /// Shown in the pane when [detail] is `null` and the pane is visible
  /// (only reachable under [ReadingPaneMode.always]).
  final Widget emptyState;

  /// The configured reading-pane mode. Combined with the current width class
  /// (and, for [ReadingPaneMode.onClick], whether something is selected) to
  /// decide whether the pane is actually shown.
  final ReadingPaneMode mode;

  /// Clears the current selection (closing the pane). Wired by the surface to
  /// reset its selection provider. A close affordance is rendered ONLY in
  /// [ReadingPaneMode.onClick] (a transient pane) — [always] is a persistent
  /// pane with no close. Without it an `onClick` pane could never be dismissed
  /// (the embedded detail has no back/close of its own).
  final VoidCallback? onClosePane;

  /// The single source of truth for "does a tap select-in-pane right now?".
  ///
  /// True only when the current width class is [WidthClass.expanded] AND [mode]
  /// is not [ReadingPaneMode.off]. Surfaces call this to decide tap = select
  /// (pane reality) vs tap = navigate full-screen. Note: this is independent of
  /// whether anything is currently selected — under [ReadingPaneMode.onClick]
  /// the first selecting tap is what opens the split.
  static bool selectsOnTap(BuildContext context, ReadingPaneMode mode) {
    final expanded = context.widthClass == WidthClass.expanded;
    return expanded && mode != ReadingPaneMode.off;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = context.widthClass == WidthClass.expanded;
    final hasSelection = detail != null;

    // off, or any non-expanded width → master full-width.
    if (mode == ReadingPaneMode.off || !expanded) {
      return master;
    }

    // onClick + expanded + nothing selected → master full-width; the pane only
    // opens once a selection exists.
    if (mode == ReadingPaneMode.onClick && !hasSelection) {
      return master;
    }

    // always (expanded) → split with the selection or the empty state.
    // onClick (expanded, with a selection) → split with the selection.
    final colors = context.colors;

    // onClick is a TRANSIENT pane: give it a close affordance so the user can
    // dismiss it back to the full-width master (the embedded detail has none of
    // its own). `always` is persistent → no close bar.
    final showCloseBar = mode == ReadingPaneMode.onClick &&
        hasSelection &&
        onClosePane != null;
    final Widget pane = showCloseBar
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PaneCloseBar(onClose: onClosePane!),
              Expanded(child: detail ?? emptyState),
            ],
          )
        : (detail ?? emptyState);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: master),
        Container(width: 1, color: colors.border),
        Expanded(flex: 3, child: pane),
      ],
    );
  }
}

/// A thin bar atop the [ReadingPaneMode.onClick] reading pane carrying the
/// close affordance that dismisses the selection.
class _PaneCloseBar extends StatelessWidget {
  const _PaneCloseBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // A LEFT-aligned back arrow — the app's established detail-dismiss pattern
    // (the full-screen matome/file detail shows a ← at top-left). Mirrors it so
    // the pane close is consistent, not a competing top-right "×".
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: IconButton(
        key: const ValueKey('master-detail-close-pane'),
        icon: Icon(Icons.arrow_back, color: colors.textSecondary),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onClose,
      ),
    );
  }
}
