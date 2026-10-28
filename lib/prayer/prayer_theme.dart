// Arc TV: shared look for the prayer widgets, following Apple's tvOS
// Human Interface Guidelines (dark materials, white focus, restrained tint).
//
// Everything is drawn with plain fills and strokes — no live backdrop blur —
// so it stays cheap on low-end TV GPUs.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class PrayerColors {
  PrayerColors._();

  /// The tint colour (soft gold), used sparingly like a tvOS accent.
  static const Color gold = Color(0xFFE3BE6E);

  /// tvOS dark materials and label colours.
  static const Color material = Color(0xE61C1C1E);
  static const Color materialRaised = Color(0x29FFFFFF);
  static const Color label = Colors.white;
  static const Color secondaryLabel = Color(0x99EBEBF5);
  static const Color tertiaryLabel = Color(0x4DEBEBF5);
  static const Color ink = Color(0xFF111114);
}

/// Thin progress ring (previous prayer → next prayer) with a small crescent.
class PrayerRingPainter extends CustomPainter {
  final double progress;

  /// Draw for a white (focused) background instead of dark material.
  final bool onLight;

  PrayerRingPainter({required this.progress, this.onLight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 2.4;
    final radius = size.shortestSide / 2 - stroke;
    final ink = onLight ? PrayerColors.ink : PrayerColors.gold;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = onLight ? const Color(0x26000000) : const Color(0x38FFFFFF),
    );

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (sweep > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
    }

    final r = radius * 0.46;
    final outer = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final inner = Path()..addOval(Rect.fromCircle(center: center + Offset(r * 0.42, -r * 0.30), radius: r * 0.86));
    canvas.drawPath(Path.combine(PathOperation.difference, outer, inner), Paint()..color = ink);
  }

  @override
  bool shouldRepaint(covariant PrayerRingPainter old) => old.progress != progress || old.onLight != onLight;
}

/// A tvOS-style button: dark material at rest; focused it lifts, scales up and
/// turns white with dark text. OK activates it.
class TvButton extends StatefulWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  const TvButton({super.key, this.icon, required this.label, required this.onPressed, this.autofocus = false});

  @override
  State<TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final fg = _focused ? PrayerColors.ink : Colors.white;
    return Actions(
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onPressed();
          return null;
        }),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
          widget.onPressed();
          return null;
        }),
      },
      child: Focus(
        autofocus: widget.autofocus,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _focused ? 1.1 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: _focused ? Colors.white : PrayerColors.materialRaised,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _focused
                    ? const [BoxShadow(color: Color(0x73000000), blurRadius: 18, offset: Offset(0, 8))]
                    : const [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 19, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(widget.label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
