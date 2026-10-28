// Arc TV: shared look for the prayer widgets (glass + soft gold).
//
// Everything is drawn with plain gradients and strokes — no live backdrop blur —
// so it stays cheap on low-end TV GPUs.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PrayerColors {
  PrayerColors._();

  static const Color gold = Color(0xFFE9CB86);
  static const Color goldDeep = Color(0xFFC79A4A);
  static const Color goldGlow = Color(0xFFF2D79B);
  static const Color ink = Color(0xFF0E1116);
}

/// Paints a frosted-glass stadium/rounded surface with a specular hairline.
class GlassSurfacePainter extends CustomPainter {
  /// 0..1 — brighter fill and a gold hairline when focused.
  final double focus;

  /// 0..1 — warm gold tint used at adhan time.
  final double warmth;
  final double radius;

  const GlassSurfacePainter({this.focus = 0, this.warmth = 0, this.radius = 999});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = math.min(radius, size.height / 2);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // Dark base keeps text readable over bright wallpapers.
    canvas.drawRRect(rrect, Paint()..color = Color.lerp(const Color(0x66000000), const Color(0x7A000000), focus)!);

    // Frosted fill: lighter at the top, like light catching glass.
    final fillTop = Color.lerp(const Color(0x2EFFFFFF), const Color(0x47FFFFFF), focus)!;
    final fillBottom = Color.lerp(const Color(0x0DFFFFFF), const Color(0x1AFFFFFF), focus)!;
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [fillTop, fillBottom]),
    );

    if (warmth > 0.001) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            [
              PrayerColors.gold.withValues(alpha: 0.30 * warmth),
              PrayerColors.goldDeep.withValues(alpha: 0.12 * warmth),
            ],
          ),
      );
    }

    // Specular hairline: white at the top, gold through the middle.
    final border = rect.deflate(0.6);
    final borderRRect = RRect.fromRectAndRadius(border, Radius.circular(math.max(0, r - 0.6)));
    final goldAmount = math.max(focus, warmth);
    canvas.drawRRect(
      borderRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(
          border.topCenter,
          border.bottomCenter,
          [
            Colors.white.withValues(alpha: 0.30 + 0.35 * focus),
            Color.lerp(Colors.white.withValues(alpha: 0.10), PrayerColors.gold.withValues(alpha: 0.85), goldAmount)!,
            Colors.white.withValues(alpha: 0.06 + 0.10 * focus),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant GlassSurfacePainter old) =>
      old.focus != focus || old.warmth != warmth || old.radius != radius;
}

/// Thin progress ring with a small crescent in the middle.
class PrayerRingPainter extends CustomPainter {
  final double progress;
  final double warmth;

  PrayerRingPainter({required this.progress, this.warmth = 0});

  static Path? _cachedCrescent;
  static Size? _cachedSize;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 2.6;
    final radius = size.shortestSide / 2 - stroke;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.01) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(PrayerColors.gold, PrayerColors.goldGlow, warmth)!,
      );
    }

    if (_cachedCrescent == null || _cachedSize != size) {
      final r = radius * 0.46;
      final outer = Path()..addOval(Rect.fromCircle(center: center, radius: r));
      final inner = Path()
        ..addOval(Rect.fromCircle(center: center + Offset(r * 0.42, -r * 0.30), radius: r * 0.86));
      _cachedCrescent = Path.combine(PathOperation.difference, outer, inner);
      _cachedSize = size;
    }
    canvas.drawPath(
      _cachedCrescent!,
      Paint()..color = Color.lerp(PrayerColors.gold.withValues(alpha: 0.85), PrayerColors.goldGlow, warmth)!,
    );
  }

  @override
  bool shouldRepaint(covariant PrayerRingPainter old) => old.progress != progress || old.warmth != warmth;
}
