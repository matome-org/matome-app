/// The reusable master–detail shell.
///
/// This is the single, presentational implementation of the layout the
/// approved Widgetbook proposal (`[Proposals]/Master–detail layout`)
/// demonstrated: on [WidthClass.expanded] widths with the reading pane on the
/// right, the surface renders its list (master) beside a reading pane (detail);
/// everywhere else it renders the master full-width and tapping an item
/// navigates to a full-screen detail instead.
///
/// [MasterDetailScaffold] is PURE: it takes pre-built widgets and a
/// [ReadingPanePosition], and decides only *layout* from the current width
/// class. It owns no Riverpod providers, no per-surface logic, and no
/// navigation — those live in the surface that hosts it. The static
/// [MasterDetailScaffold.showsPane] predicate is the ONE source of truth a
/// surface consults to decide whether a tap selects (pane visible) or navigates
/// (pane absent), so the scaffold's layout decision and the surface's
/// interaction decision can never drift.
library;

import 'package:flutter/material.dart';

import '../core/layout/breakpoints.dart';
import '../core/theme/app_theme.dart';

/// Where the reading (detail) pane sits relative to the master.
///
/// Owned here; the provider that drives it (a later task) imports this enum.
///   * [right] — pane alongside the master, but only when the width class is
///     [WidthClass.expanded]. On narrower widths it degrades to full-width
///     master + navigate-on-tap.
///   * [off] — never show a side pane; master is always full-width.
enum ReadingPanePosition { right, off }

/// Reusable, presentational master–detail shell. See the library docs.
class MasterDetailScaffold extends StatelessWidget {
  const MasterDetailScaffold({
    super.key,
    required this.master,
    this.detail,
    required this.emptyState,
    required this.pane,
  });

  /// The master column (list/table). Always rendered.
  final Widget master;

  /// The pane content for the current selection, or `null` when nothing is
  /// selected. Only consulted when the pane is shown.
  final Widget? detail;

  /// Shown in the pane when [detail] is `null` and the pane is visible.
  final Widget emptyState;

  /// The configured reading-pane position. Combined with the current width
  /// class to decide whether the pane is actually shown.
  final ReadingPanePosition pane;

  /// The single source of truth for "is the side pane visible right now?".
  ///
  /// True only when [pane] is [ReadingPanePosition.right] AND the current width
  /// class is [WidthClass.expanded]. Surfaces call this to decide tap = select
  /// (pane visible) vs tap = navigate full-screen (pane absent).
  static bool showsPane(BuildContext context, ReadingPanePosition pane) {
    final expanded = context.widthClass == WidthClass.expanded;
    return pane == ReadingPanePosition.right && expanded;
  }

  @override
  Widget build(BuildContext context) {
    if (!showsPane(context, pane)) {
      // Off, medium, or compact → master full-width.
      return master;
    }

    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: master),
        Container(width: 1, color: colors.border),
        Expanded(flex: 3, child: detail ?? emptyState),
      ],
    );
  }
}
