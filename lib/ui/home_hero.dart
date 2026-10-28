// Arc TV: the quiet area at the top of Home — the time and today's date
// (Gregorian and Hijri), set large over the wallpaper like a lock screen.

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../prayer/prayer_engine.dart';
import '../prayer/prayer_service.dart';

class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PrayerService>();
    final strings = service.strings;
    final city = service.city;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);

    return Directionality(
      textDirection: strings.direction,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(64, 0, 64, 26),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: ValueListenableBuilder<PrayerStatus?>(
            valueListenable: service.status,
            builder: (context, status, _) {
              if (status == null) return const SizedBox.shrink();
              final local = status.nowUtc.add(city.utcOffset);
              final hour = use24h ? local.hour : (local.hour % 12 == 0 ? 12 : local.hour % 12);
              final time = '${use24h ? hour.toString().padLeft(2, '0') : hour}:${local.minute.toString().padLeft(2, '0')}';
              final today = status.today;
              final date = [
                strings.gregorian(today.year, today.month, today.day),
                if (today.hijri != null) strings.hijri(today.hijri),
              ].join('  ·  ');
              const shadow = [Shadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 4))];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      time,
                      style: const TextStyle(
                        fontSize: 92,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        height: 1.0,
                        letterSpacing: -2,
                        fontFeatures: [FontFeature.tabularFigures()],
                        shadows: shadow,
                      ),
                    ),
                  ),
                  if (!use24h) ...[
                    const SizedBox(width: 12),
                    Text(
                      local.hour < 12 ? strings.am : strings.pm,
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: 0.86), shadows: shadow),
                    ),
                  ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.86),
                      shadows: shadow,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
