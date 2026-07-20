/// The SINGLE source of truth for layout breakpoints across the app.
///
/// Three width classes, by available width in logical pixels:
///   * [WidthClass.compact]  — `width < 600` (phones, narrow panes)
///   * [WidthClass.medium]   — `600 <= width < 1024` (tablets, split panes)
///   * [WidthClass.expanded] — `width >= 1024` (desktop, master-detail)
///
/// Today the surfaces still carry their own scattered literals (900 / 1000 /
/// 720). Those are NOT migrated yet: the migration onto these constants happens
/// per-surface in later waves (W2–W4), gated by
/// `FeatureFlags.masterDetailLayout`, so each move is an isolated, reviewable
/// behaviour change. This module only establishes the shared scale; it changes
/// no existing surface.
library;

import 'package:flutter/widgets.dart';

/// Lower bound of [WidthClass.medium]. Below this, layout is [WidthClass.compact].
const double kBreakpointMedium = 600.0;

/// Lower bound of [WidthClass.expanded]. At or above this, layout is
/// [WidthClass.expanded]; between [kBreakpointMedium] and this, it is
/// [WidthClass.medium].
const double kBreakpointExpanded = 1024.0;

/// Coarse layout width class. See library docs for the bands.
enum WidthClass { compact, medium, expanded }

/// Classifies a logical-pixel [width] into a [WidthClass].
///
/// Boundaries are inclusive on the lower edge: `599 -> compact`, `600 -> medium`,
/// `1023 -> medium`, `1024 -> expanded`.
WidthClass widthClassFor(double width) {
  if (width < kBreakpointMedium) return WidthClass.compact;
  if (width < kBreakpointExpanded) return WidthClass.medium;
  return WidthClass.expanded;
}

/// Ergonomic accessor mirroring the project's `context.colors` style.
extension WidthClassContext on BuildContext {
  /// The [WidthClass] for the current `MediaQuery` width.
  WidthClass get widthClass => widthClassFor(MediaQuery.sizeOf(this).width);
}
