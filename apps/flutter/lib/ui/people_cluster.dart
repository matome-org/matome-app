import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// PeopleCluster — the file/contact↔**people** relationship indicator
/// (DR-003 / DR-004).
///
/// An overlapping row of initials avatars: up to [maxShown] are drawn, with a
/// trailing "+N" overflow chip when more names are tagged. Each avatar carries
/// a ring in `colors.surface` so overlapping circles stay separable. A
/// [Tooltip] lists every name. An empty [names] list renders nothing
/// (`SizedBox.shrink()`) — callers that need a placeholder add their own dash.
///
/// Strictly presentational: props in, no callbacks, no providers, no DB.
class PeopleCluster extends StatelessWidget {
  const PeopleCluster({super.key, required this.names, this.size = 22});

  /// The tagged contact display names. Empty renders nothing.
  final List<String> names;

  /// The diameter of each avatar circle.
  final double size;

  /// The maximum number of initial avatars shown before collapsing the rest
  /// into a "+N" overflow chip.
  static const int maxShown = 3;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) return const SizedBox.shrink();

    final shown = names.take(maxShown).toList();
    final extra = names.length - shown.length;
    final overlap = size * 0.62;
    final slots = shown.length + (extra > 0 ? 1 : 0);
    final width = size + (slots - 1) * overlap;

    return Tooltip(
      message: names.join(', '),
      child: SizedBox(
        key: const ValueKey('people-cluster'),
        width: width,
        height: size,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              Positioned(
                left: i * overlap,
                child: _MiniAvatar(
                  label: shown[i].characters.first,
                  size: size,
                ),
              ),
            if (extra > 0)
              Positioned(
                left: shown.length * overlap,
                child: _MiniAvatar(
                  key: const ValueKey('people-cluster-overflow'),
                  label: '+$extra',
                  size: size,
                  emphasized: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One initials/overflow circle in a [PeopleCluster], ringed in the surface
/// colour so adjacent overlapping avatars stay visually separated.
class _MiniAvatar extends StatelessWidget {
  const _MiniAvatar({
    super.key,
    required this.label,
    required this.size,
    this.emphasized = false,
  });

  final String label;
  final double size;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: emphasized ? colors.textPrimary : colors.subtleFillStrong,
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: typography.label.copyWith(
          color: emphasized ? colors.onTextPrimary : colors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}
