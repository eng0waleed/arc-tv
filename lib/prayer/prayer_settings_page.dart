// Arc TV: prayer-time settings pages (inside the launcher's settings panel).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../kiosk/kiosk_page.dart';
import '../providers/settings_service.dart';
import '../widgets/rounded_switch_list_tile.dart';
import '../widgets/settings/focusable_settings_tile.dart';
import '../widgets/settings/settings_theme.dart';
import 'prayer_engine.dart';
import 'prayer_service.dart';

class PrayerSettingsPage extends StatelessWidget {
  static const String routeName = 'arc_tv_prayer_settings';

  const PrayerSettingsPage({super.key});

  static int _nextAdjustment(int current) {
    const order = [0, 1, 2, -2, -1];
    final index = order.indexOf(current);
    return order[(index + 1) % order.length];
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PrayerService>();
    final s = service.strings;
    final city = service.city;
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.6));

    return Directionality(
      textDirection: s.direction,
      child: Column(
        children: [
          SettingsPageHeader(title: s.title),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                RoundedSwitchListTile(
                  autofocus: true,
                  value: service.enabled,
                  onChanged: service.setEnabled,
                  title: Text(s.showOnHome, style: body),
                  secondary: const Icon(Icons.access_time_rounded),
                ),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.location_city_rounded),
                  title: Text(s.city, style: body),
                  subtitle: Text('${s.cityName(city)}  ·  ${s.methodName(city.method)}', style: small),
                  onPressed: () => Navigator.of(context).pushNamed(PrayerCityPage.routeName),
                ),
                RoundedSwitchListTile(
                  value: service.hanafiAsr,
                  onChanged: service.setHanafiAsr,
                  title: Text(s.hanafiAsr, style: body),
                  subtitle: Text(s.hanafiAsrHint, style: small),
                  secondary: const Icon(Icons.brightness_6_rounded),
                ),
                RoundedSwitchListTile(
                  value: service.arabicNames,
                  onChanged: service.setArabicNames,
                  title: Text(s.arabicNames, style: body),
                  secondary: const Icon(Icons.translate),
                ),
                RoundedSwitchListTile(
                  value: service.countdownToSunrise,
                  onChanged: service.setCountdownToSunrise,
                  title: Text(s.countSunrise, style: body),
                  secondary: const Icon(Icons.wb_sunny_outlined),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.event),
                  title: Text(s.hijriAdjust, style: body),
                  subtitle: Text('${s.hijriAdjustValue(service.hijriAdjustment)}\n${s.hijriAdjustHint}', style: small),
                  onPressed: () => service.setHijriAdjustment(_nextAdjustment(service.hijriAdjustment)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                  child: Text(s.ramadanAuto, style: small),
                ),
                const SettingsSectionDivider(),
                Consumer<SettingsService>(
                  builder: (context, settings, _) => RoundedSwitchListTile(
                    value: settings.reduceTransparency,
                    onChanged: settings.setReduceTransparency,
                    title: Text(s.reduceTransparency, style: body),
                    subtitle: Text(s.reduceTransparencyHint, style: small),
                    secondary: const Icon(Icons.blur_off_rounded),
                  ),
                ),
                FocusableSettingsTile(
                  showChevron: true,
                  leading: const Icon(Icons.home_rounded),
                  title: Text(s.homeButton, style: body),
                  subtitle: Text(s.homeButtonSubtitle, style: small),
                  onPressed: () => Navigator.of(context).pushNamed(KioskPage.routeName),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrayerCityPage extends StatelessWidget {
  static const String routeName = 'arc_tv_prayer_city';

  const PrayerCityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PrayerService>();
    final s = service.strings;
    final selectedId = service.city.id;
    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.6));
    final accent = Theme.of(context).colorScheme.primary;

    final children = <Widget>[];
    String? lastCountry;
    for (final city in kPrayerCities) {
      final country = s.countryName(city);
      if (country != lastCountry) {
        lastCountry = country;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: Text(
            '$country  ·  ${s.methodName(city.method)}',
            style: small?.copyWith(fontWeight: FontWeight.w600),
          ),
        ));
      }
      final selected = city.id == selectedId;
      children.add(FocusableSettingsTile(
        autofocus: selected,
        frameLeading: false,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? accent : Colors.grey,
        ),
        title: Text(s.cityName(city), style: body),
        onPressed: () async {
          await service.setCity(city.id);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
      ));
    }

    return Directionality(
      textDirection: s.direction,
      child: Column(
        children: [
          SettingsPageHeader(title: s.chooseCity),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
