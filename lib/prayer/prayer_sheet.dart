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
    barrierColor: const Color(0xE6101012),
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

    // tvOS HIG: a full-screen modal over a dimmed background — large title,
    // content centred in the title-safe area, buttons at the bottom.
    return Directionality(
      textDirection: strings.direction,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ValueListenableBuilder<PrayerStatus?>(
                valueListenable: service.status,
                builder: (context, status, _) {
                  if (status == null) {
                    return const Center(child: CircularProgressIndicator());
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
    const tabular = [FontFeature.tabularFigures()];

    final subtitle = [
      strings.cityName(city),
      strings.gregorian(today.year, today.month, today.day),
      if (today.hijri != null) strings.hijri(today.hijri),
    ].join('  ·  ');

    final info = [
      strings.methodName(city.method),
      strings.asrName(hanafi),
      if (today.ramadanIsha) strings.ramadanNote,
    ].join('  ·  ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.title,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: PrayerColors.label, height: 1.15),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 15, color: PrayerColors.secondaryLabel)),
        const SizedBox(height: 22),
        // Hero line: what is next and how long until it.
        if (current != null)
          Text(
            '${strings.name(current.id)} · ${strings.nowLabel}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: PrayerColors.gold),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${strings.name(next.id)} ${strings.remainingPrefix}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: PrayerColors.secondaryLabel),
              ),
              const SizedBox(width: 14),
              RollingText(
                text: PrayerStrings.countdown(status.remaining),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w300,
                  color: PrayerColors.label,
                  height: 1.1,
                  fontFeatures: tabular,
                ),
              ),
            ],
          ),
        const SizedBox(height: 26),
        Row(
          children: [
            for (var i = 0; i < today.times.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _buildTile(today.times[i], nextIsTomorrow: nextIsTomorrow)),
            ],
          ],
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TvButton(icon: Icons.tune_rounded, label: strings.settings, onPressed: onOpenSettings),
            const SizedBox(width: 20),
            TvButton(label: strings.close, autofocus: true, onPressed: () => Navigator.of(context).maybePop()),
          ],
        ),
        const SizedBox(height: 18),
        Text(info, style: const TextStyle(fontSize: 12.5, color: PrayerColors.tertiaryLabel)),
      ],
    );
  }

  Widget _buildTile(PrayerTime time, {required bool nextIsTomorrow}) {
    final next = status.next;
    final current = status.current;
    final isCurrent = current != null && current.id == time.id && current.utc == time.utc;
    final isNext = current == null && next.id == time.id && (next.utc == time.utc || nextIsTomorrow);
    final showTomorrow = isNext && nextIsTomorrow;
    final shown = showTomorrow ? next : time;
    final isPast = !isCurrent && !isNext && !time.utc.isAfter(status.nowUtc);

    String? caption;
    if (isCurrent) {
      caption = strings.nowLabel;
    } else if (isNext) {
      caption = showTomorrow ? (strings.ar ? 'غدًا' : 'Tomorrow') : strings.nextLabel;
    }

    return _PrayerTile(
      name: strings.name(time.id),
      time: strings.clock(shown.local(city), use24h: use24h),
      caption: caption,
      state: isCurrent
          ? _TileState.current
          : isNext
              ? _TileState.next
              : isPast
                  ? _TileState.past
                  : _TileState.upcoming,
    );
  }
}

enum _TileState { past, upcoming, next, current }

class _PrayerTile extends StatelessWidget {
  final String name;
  final String time;
  final String? caption;
  final _TileState state;

  const _PrayerTile({required this.name, required this.time, required this.caption, required this.state});

  @override
  Widget build(BuildContext context) {
    final current = state == _TileState.current;
    final next = state == _TileState.next;
    final past = state == _TileState.past;

    final fill = current
        ? PrayerColors.gold
        : next
            ? const Color(0x33FFFFFF)
            : const Color(0x1AFFFFFF);
    final primary = current ? PrayerColors.ink : (past ? PrayerColors.tertiaryLabel : PrayerColors.label);
    final secondary = current ? const Color(0xB3111114) : (past ? PrayerColors.tertiaryLabel : PrayerColors.secondaryLabel);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: 118,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, maxLines: 1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: secondary)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              maxLines: 1,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            height: 18,
            child: caption == null
                ? null
                : Text(
                    caption!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: current ? PrayerColors.ink : PrayerColors.gold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
