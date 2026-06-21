import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// At/above this width the file-detail opens as a centered, bounded dialog card
/// over a dimmed backdrop (desktop); below it the detail takes the whole screen
/// (mobile / narrow windows). Mirrors the inbox two-pane breakpoint feel.
const double kFileDetailDialogBreakpoint = 900;

/// Responsive page for the audio/image file-detail routes.
///
/// Narrow → an opaque full-screen page (the detail Scaffold fills the window).
/// Wide → a non-opaque page: the same detail Scaffold is clipped into a bounded,
/// centered card over a dim, tap-to-dismiss barrier — so a desktop user gets a
/// contained modal (the image preview stays reasonably sized, with its own
/// fullscreen affordance) instead of a giant edge-to-edge view.
Page<void> fileDetailPage(BuildContext context, Widget child) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < kFileDetailDialogBreakpoint) {
    return MaterialPage<void>(child: child);
  }
  return CustomTransitionPage<void>(
    opaque: false,
    barrierDismissible: true,
    // lib/ui is exempt from the design-system source guard; a plain scrim is the
    // right primitive here (there is no semantic scrim token).
    barrierColor: Colors.black54,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: const Duration(milliseconds: 160),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
    child: _DetailDialogCard(child: child),
  );
}

class _DetailDialogCard extends StatelessWidget {
  const _DetailDialogCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = context.radius;
    final spacing = context.spacing;
    final size = MediaQuery.sizeOf(context);

    return Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: size.height * 0.86,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius.xl),
            child: child,
          ),
        ),
      ),
    );
  }
}
