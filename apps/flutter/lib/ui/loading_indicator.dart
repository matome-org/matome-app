import 'package:flutter/material.dart';

/// Catalog loading spinner used wherever Matome shows indeterminate progress.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size,
    this.strokeWidth = 4,
    this.color,
  });

  final double? size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final indicator = CircularProgressIndicator(
      strokeWidth: strokeWidth,
      color: color,
    );

    final size = this.size;
    if (size == null) return indicator;

    return SizedBox.square(dimension: size, child: indicator);
  }
}
