// Arc TV: full-day prayer sheet, opened from the top-bar pill.

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/settings/settings_panel.dart';
import 'prayer_engine.dart';
import 'prayer_pill.dart' show RollingText;
import 'prayer_service.dart';
import 'prayer_settings_page.dart';
import 'prayer_strings.dart';
import 'prayer_theme.dart';

Future<void> showPrayerSheet(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'prayer-times',
    barrierColor: const Color(0x99000000),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, _, __) => PrayerSheet(
      onOpenSettings: () {
        Navigator.of(dialogContext).pop();
        showDialog<void>(
          context: context,
          builder: (_) => const SettingsPanel(initialRoute: PrayerSettingsPage.routeName),
        );
      },
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      );
    },
  );
}

class PrayerSheet extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const PrayerSheet({super.key, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PrayerService>();
    final strings = service.strings;
    final city = service.city;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);

    return Directionality(
      textDirection: strings.direction,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Material(
              type: MaterialType.transparency,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xE6121722),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 12))],
                ),
                child: CustomPaint(
                  painter: const GlassSurfacePainter(radius: 28),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                    child: ValueListenableBuilder<PrayerStatus?>(
                      valueListenable: service.status,
                      builder: (context, status, _) {
                        if (status == null) {
                          return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                        }
                        return _SheetContent(
                          status: status,
                          strings: strings,
                          city: city,
                          use24h: use24h,
                          hanafi: service.hanafiAsr,
                          onOpenSettings: onOpenSettings,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  final PrayerStatus status;
  final PrayerStrings strings;
  final PrayerCity city;
  final bool use24h;
  final bool hanafi;
  final VoidCallback onOpenSettings;

  const _SheetContent({
    required this.status,
    required this.strings,
    required this.city,
    required this.use24h,
    required this.hanafi,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final today = status.today;
    final next = status.next;
    final current = status.current;
    final nextLocal = next.local(city);
    final nextIsTomorrow =
        nextLocal.year != today.year || nextLocal.month != today.month || nextLocal.day != today.day;

    final subtitleStyle = TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.66), height: 1.2);
    const tabular = [FontFeature.tabularFigures()];

    final infoParts = <String>[
      strings.methodName(city.method),
      strings.asrName(hanafi),
      if (today.ramadanIsha) strings.ramadanNote,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CustomPaint(
                painter: PrayerRingPainter(progress: current != null ? 1 : status.progress, warmth: current != null ? 1 : 0),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      strings.cityName(city),
                      strings.gregorian(today.year, today.month, today.day),
                      if (today.hijri != null) strings.hijri(today.hijri),
                    ].join('  ·  '),
                    style: subtitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Live countdown chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: PrayerColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PrayerColors.gold.withValues(alpha: 0.45)),
              ),
              child: current != null
                  ? Text(
                      '${strings.name(current.id)} · ${strings.nowLabel}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrayerColors.gold),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${strings.name(next.id)} ${strings.remainingPrefix} ',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        RollingText(
                          text: PrayerStrings.countdown(status.remaining),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PrayerColors.gold,
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Six tiles
        Row(
          children: [
            for (var i = 0; i < today.times.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _buildTile(today.times[i], nextIsTomorrow: nextIsTomorrow),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        // Footer
        Row(
          children: [
            Expanded(
              child: Text(
                infoParts.join('  ·  '),
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            _SheetButton(icon: Icons.tune_rounded, label: strings.settings, onPressed: onOpenSettings),
            const SizedBox(width: 10),
            _SheetButton(
              icon: Icons.close_rounded,
              label: strings.close,
              autofocus: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTile(PrayerTime time, {required bool nextIsTomorrow}) {
    final next = status.next;
    final current = status.current;
    final isCurrent = current != null && current.id == time.id && current.utc == time.utc;
    var isNext = current == null && next.id == time.id && (next.utc == time.utc || (nextIsTomorrow && time.id == next.id));
    final showTomorrow = isNext && nextIsTomorrow;
    final shown = showTomorrow ? next : time;
    final isPast = !isCurrent && !isNext && !time.utc.isAfter(status.nowUtc);

    final _TileState state;
    if (isCurrent) {
      state = _TileState.current;
    } else if (isNext) {
      state = _TileState.next;
    } else if (isPast) {
      state = _TileState.past;
    } else {
      state = _TileState.upcoming;
    }

    String? badge;
    if (state == _TileState.current) {
      badge = strings.nowLabel;
    } else if (state == _TileState.next) {
      badge = showTomorrow ? (strings.ar ? 'غدًا' : 'Tomorrow') : strings.nextLabel;
    }

    return _PrayerTile(
      name: strings.name(time.id),
      time: strings.clock(shown.local(city), use24h: use24h),
      badge: badge,
      state: state,
    );
  }
}

enum _TileState { past, upcoming, next, current }

class _PrayerTile extends StatelessWidget {
  final String name;
  final String time;
  final String? badge;
  final _TileState state;

  const _PrayerTile({required this.name, required this.time, required this.badge, required this.state});

  @override
  Widget build(BuildContext context) {
    final highlighted = state == _TileState.next || state == _TileState.current;
    final dim = state == _TileState.past;

    final fill = switch (state) {
      _TileState.current => PrayerColors.gold.withValues(alpha: 0.22),
      _TileState.next => PrayerColors.gold.withValues(alpha: 0.10),
      _TileState.upcoming => Colors.white.withValues(alpha: 0.07),
      _TileState.past => Colors.white.withValues(alpha: 0.035),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? PrayerColors.gold.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.08),
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: state == _TileState.current
            ? [BoxShadow(color: PrayerColors.gold.withValues(alpha: 0.35), blurRadius: 16)]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: highlighted ? PrayerColors.gold : Colors.white.withValues(alpha: dim ? 0.5 : 0.9),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              maxLines: 1,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: dim ? 0.5 : 1),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            height: 20,
            child: badge == null
                ? null
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: state == _TileState.current ? PrayerColors.gold : PrayerColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: state == _TileState.current ? PrayerColors.ink : PrayerColors.gold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool autofocus;

  const _SheetButton({required this.icon, required this.label, required this.onPressed, this.autofocus = false});

  @override
  State<_SheetButton> createState() => _SheetButtonState();
}

class _SheetButtonState extends State<_SheetButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
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
            scale: _focused ? 1.06 : 1,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _focused ? PrayerColors.gold.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _focused ? PrayerColors.gold : Colors.white.withValues(alpha: 0.12),
                  width: _focused ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 18, color: _focused ? PrayerColors.gold : Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _focused ? Colors.white : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
