// Arc TV: the small prayer pill in the centre of the top bar.

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/launcher_state.dart';
import 'prayer_engine.dart';
import 'prayer_service.dart';
import 'prayer_sheet.dart';
import 'prayer_strings.dart';
import 'prayer_theme.dart';
import '../ui/liquid_glass.dart';

class PrayerPill extends StatefulWidget {
  final FocusNode? focusNode;

  const PrayerPill({super.key, this.focusNode});

  @override
  State<PrayerPill> createState() => _PrayerPillState();
}

class _PrayerPillState extends State<PrayerPill> {
  bool _focused = false;

  void _open() => showPrayerSheet(context);

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PrayerService>();
    final strings = service.strings;
    final city = service.city;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);

    return Semantics(
      button: true,
      label: strings.title,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            _open();
            return null;
          }),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(onInvoke: (_) {
            _open();
            return null;
          }),
        },
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              context.read<LauncherState>().setAppGridFocused(false);
            }
            if (mounted && hasFocus != _focused) {
              setState(() => _focused = hasFocus);
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: RepaintBoundary(
              child: ValueListenableBuilder<PrayerStatus?>(
                valueListenable: service.status,
                builder: (context, status, _) {
                  if (status == null) {
                    return const SizedBox.shrink();
                  }
                  return _PillBody(
                    status: status,
                    strings: strings,
                    city: city,
                    use24h: use24h,
                    focused: _focused,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillBody extends StatelessWidget {
  final PrayerStatus status;
  final PrayerStrings strings;
  final PrayerCity city;
  final bool use24h;
  final bool focused;

  const _PillBody({
    required this.status,
    required this.strings,
    required this.city,
    required this.use24h,
    required this.focused,
  });

  @override
  Widget build(BuildContext context) {
    final current = status.current;
    final isNow = current != null;
    final target = current ?? status.next;

    // tvOS HIG: a capsule on dark material at rest; when focused it lifts,
    // scales up and turns white with dark text. Adhan time tints it gold.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: focused ? 1 : 0),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, f, _) {
        final onFill = Color.lerp(Colors.white, const Color(0xFF111114), f)!;
        final secondary = onFill.withValues(alpha: 0.66);
        final tabular = const [FontFeature.tabularFigures()];

        final body = LiquidGlass(
          radius: 24,
          focus: f,
          tint: isNow ? PrayerColors.gold : null,
          tintStrength: 0.55,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 20, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedRing(progress: isNow ? 1.0 : status.progress, onLight: f > 0.5),
                  const SizedBox(width: 11),
                  Text(
                    strings.name(target.id),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onFill, height: 1.1),
                  ),
                  const SizedBox(width: 10),
                  if (isNow)
                    Text(strings.nowLabel,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: onFill, height: 1.1))
                  else ...[
                    Text(
                      strings.clock(target.local(city), use24h: use24h),
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w400, color: secondary, height: 1.1, fontFeatures: tabular),
                    ),
                    Container(
                      width: 1,
                      height: 18,
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      color: onFill.withValues(alpha: 0.25),
                    ),
                    RollingText(
                      text: PrayerStrings.countdown(status.remaining),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: f > 0.5 ? onFill : PrayerColors.gold,
                        height: 1.1,
                        fontFeatures: tabular,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        return Transform.scale(
          scale: 1 + 0.08 * f,
          child: _AdhanGlow(active: isNow && f < 0.5, child: body),
        );
      },
    );
  }
}

/// Progress ring that only animates on real jumps (e.g. when the next prayer
/// changes), so it does not repaint continuously on a TV GPU.
class _AnimatedRing extends StatefulWidget {
  final double progress;
  final bool onLight;

  const _AnimatedRing({required this.progress, required this.onLight});

  @override
  State<_AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<_AnimatedRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: widget.progress,
  );

  @override
  void didUpdateWidget(covariant _AnimatedRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final delta = (widget.progress - _controller.value).abs();
    if (delta > 0.02) {
      _controller.animateTo(widget.progress, curve: Curves.easeInOutCubic);
    } else if (!_controller.isAnimating) {
      _controller.value = widget.progress;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: PrayerRingPainter(progress: _controller.value, onLight: widget.onLight),
        ),
      ),
    );
  }
}

/// Gentle pulsing gold glow while a prayer has just started ("حان الآن").
class _AdhanGlow extends StatefulWidget {
  final bool active;
  final Widget child;

  const _AdhanGlow({required this.active, required this.child});

  @override
  State<_AdhanGlow> createState() => _AdhanGlowState();
}

class _AdhanGlowState extends State<_AdhanGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _AdhanGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _pulse,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: PrayerColors.gold.withValues(alpha: 0.25 + 0.35 * t), blurRadius: 8 + 8 * t)],
          ),
          child: child,
        );
      },
    );
  }
}

/// Text whose digits roll vertically when they change (the countdown).
class RollingText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const RollingText({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < chars.length; i++)
            // Keyed from the right so the seconds keep their slot when the text shortens.
            _RollingChar(key: ValueKey('slot-${chars.length - i}'), char: chars[i], style: style),
        ],
      ),
    );
  }
}

class _RollingChar extends StatelessWidget {
  final String char;
  final TextStyle style;

  const _RollingChar({super.key, required this.char, required this.style});

  static final RegExp _digit = RegExp(r'\d');

  @override
  Widget build(BuildContext context) {
    if (!_digit.hasMatch(char)) {
      return Text(char, style: style);
    }
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(char);
          final offset = Tween<Offset>(
            begin: incoming ? const Offset(0, 0.9) : const Offset(0, -0.9),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text(char, key: ValueKey(char), style: style),
      ),
    );
  }
}
