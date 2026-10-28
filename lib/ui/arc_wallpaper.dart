// Arc TV: colourful "mesh" wallpapers. Liquid Glass needs rich colour behind it
// to read as glass, so the default wallpaper is a soft multi-light gradient.
// It is painted once into a cached image (see flauncher.dart), never per frame.

import 'package:flutter/material.dart';

class MeshLight {
  /// Centre in 0..1 of the canvas.
  final Offset center;

  /// Radius as a fraction of the canvas's longest side.
  final double radius;
  final Color color;

  const MeshLight(this.center, this.radius, this.color);
}

/// A [LinearGradient] base with soft radial lights painted on top.
/// Anything that only understands [Gradient] still draws the base colours.
class ArcMeshGradient extends LinearGradient {
  final List<MeshLight> lights;

  const ArcMeshGradient({
    required super.colors,
    super.begin,
    super.end,
    required this.lights,
  });
}

/// Paints any wallpaper gradient (including [ArcMeshGradient]) into [rect].
void paintWallpaperGradient(Canvas canvas, Rect rect, Gradient gradient) {
  canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  if (gradient is ArcMeshGradient) {
    final longest = rect.longestSide;
    for (final light in gradient.lights) {
      final center = Offset(rect.left + rect.width * light.center.dx, rect.top + rect.height * light.center.dy);
      final radius = longest * light.radius;
      final circle = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [light.color, light.color.withValues(alpha: 0)],
          ).createShader(circle),
      );
    }
  }
}
