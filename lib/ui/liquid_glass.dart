// Arc TV: a TV-friendly take on Apple's Liquid Glass (iOS / tvOS 26).
//
// What the HIG describes, and how it is drawn here:
// - Translucent glass that shows a blurred, colour-rich view of what is behind
//   it → a pre-blurred snapshot of the wallpaper is blitted under the glass
//   (CachedBlurBackdrop), so there is no per-frame blur on the TV's GPU.
// - Light bending at the edges (lensing) and a "thick" body → a bright rim that
//   fades around the shape plus a soft inner shade along the bottom edge.
// - Specular highlights → a hot spot on the top edge that brightens with focus.
// - A dimming layer for legibility, tint only on the primary element, no glass
//   stacked on glass (inner parts use plain fills).
// - "Reduce transparency" swaps the glass for a solid dark material.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_service.dart';
import '../widgets/cached_blur_backdrop.dart';

class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double radius;

  /// 0..1 — focus turns the glass bright and milky, like tvOS 26 focus.
  final double focus;

  /// Optional tint for the one primary element on screen.
  final Color? tint;
  final double tintStrength;
  final bool shadow;

  const LiquidGlass({
    super.key,
    required this.child,
    this.radius = 24,
    this.focus = 0,
    this.tint,
    this.tintStrength = 0.35,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = context.select<SettingsService, bool>((s) => s.reduceTransparency);
    final borderRadius = BorderRadius.circular(radius);

    final body = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _GlassBodyPainter(
              radius: radius,
              focus: focus,
              tint: tint,
              tintStrength: tintStrength,
              solid: reduce,
            ),
          ),
        ),
        child,
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22 + 0.18 * focus),
                  blurRadius: 18 + 14 * focus,
                  offset: Offset(0, 6 + 6 * focus),
                ),
              ]
            : const [],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: CustomPaint(
          foregroundPainter: _GlassRimPainter(radius: radius, focus: focus, solid: reduce),
          child: reduce ? body : CachedBlurBackdrop(sigma: 26, child: body),
        ),
      ),
    );
  }
}

/// Fill: dimming layer, milky veil (stronger when focused) and optional tint.
class _GlassBodyPainter extends CustomPainter {
  final double radius;
  final double focus;
  final Color? tint;
  final double tintStrength;
  final bool solid;

  _GlassBodyPainter({
    required this.radius,
    required this.focus,
    required this.tint,
    required this.tintStrength,
    required this.solid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    if (solid) {
      canvas.drawRRect(rrect, Paint()..color = Color.lerp(const Color(0xF2242428), const Color(0xFFF2F2F7), focus)!);
    } else {
      // Dimming layer keeps white text readable on bright wallpapers.
      canvas.drawRRect(rrect, Paint()..color = Colors.black.withValues(alpha: 0.16 * (1 - focus)));
      // Milky veil, lighter towards the top like light passing through glass.
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.16 + 0.72 * focus),
              Colors.white.withValues(alpha: 0.05 + 0.74 * focus),
            ],
          ).createShader(rect),
      );
    }
    final t = tint;
    if (t != null && tintStrength > 0) {
      canvas.drawRRect(rrect, Paint()..color = t.withValues(alpha: tintStrength * (1 - 0.6 * focus)));
    }
  }

  @override
  bool shouldRepaint(covariant _GlassBodyPainter old) =>
      old.focus != focus || old.tint != tint || old.tintStrength != tintStrength || old.solid != solid || old.radius != radius;
}

/// Rim: lensing edge, specular hot spot and a soft inner shade at the bottom.
class _GlassRimPainter extends CustomPainter {
  final double radius;
  final double focus;
  final bool solid;

  _GlassRimPainter({required this.radius, required this.focus, required this.solid});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    // Inner shade along the bottom: the glass has thickness.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(1.5), Radius.circular(radius - 1.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: solid ? 0.0 : 0.16)],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(rect),
    );

    // Lensing rim: light bends at the edge, bright at top-left and bottom-right.
    final rim = rect.deflate(0.75);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rim, Radius.circular(radius - 0.75)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.70 + 0.25 * focus),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.06),
            Colors.white.withValues(alpha: 0.38 + 0.2 * focus),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(rect),
    );

    // Specular hot spot on the top edge.
    final hotWidth = size.width * (0.42 + 0.2 * focus);
    final hotRect = Rect.fromLTWH(radius * 0.6, 0, hotWidth, size.height * 0.5);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawRRect(
      RRect.fromRectAndRadius(rim, Radius.circular(radius - 0.75)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = RadialGradient(
          center: Alignment.topCenter,
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.85 + 0.15 * focus), Colors.white.withValues(alpha: 0)],
        ).createShader(hotRect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassRimPainter old) => old.focus != focus || old.radius != radius || old.solid != solid;
}

/// A focusable Liquid Glass button (capsule or circle). Focus lifts it, scales it
/// up and turns the glass bright with dark content, as on tvOS 26.
class GlassButton extends StatefulWidget {
  final IconData? icon;
  final String? label;
  final VoidCallback onPressed;
  final bool autofocus;
  final Color? tint;
  final String? semanticLabel;
  final double height;

  const GlassButton({
    super.key,
    this.icon,
    this.label,
    required this.onPressed,
    this.autofocus = false,
    this.tint,
    this.semanticLabel,
    this.height = 48,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final iconOnly = widget.label == null;
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: Actions(
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
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _focused ? 1 : 0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, f, _) {
                final fg = Color.lerp(Colors.white, const Color(0xFF111114), f)!;
                return Transform.scale(
                  scale: 1 + 0.1 * f,
                  child: LiquidGlass(
                    radius: widget.height / 2,
                    focus: f,
                    tint: widget.tint,
                    child: SizedBox(
                      height: widget.height,
                      width: iconOnly ? widget.height : null,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: iconOnly ? 0 : 26),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) Icon(widget.icon, size: 21, color: fg),
                            if (widget.icon != null && !iconOnly) const SizedBox(width: 8),
                            if (!iconOnly)
                              Text(widget.label!, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: fg)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
