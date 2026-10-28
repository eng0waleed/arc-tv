// Arc TV: prayer-time settings + a once-per-second status ticker.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_engine.dart';
import 'prayer_strings.dart';

const _kEnabled = 'arc_tv_prayer_enabled';
const _kCity = 'arc_tv_prayer_city';
const _kHanafi = 'arc_tv_prayer_hanafi_asr';
const _kArabic = 'arc_tv_prayer_arabic_names';
const _kSunrise = 'arc_tv_prayer_count_sunrise';
const _kHijriAdjustment = 'arc_tv_prayer_hijri_adjustment';

class PrayerService extends ChangeNotifier with WidgetsBindingObserver {
  final SharedPreferences _prefs;
  final Map<int, PrayerDay> _days = {};
  Timer? _timer;
  bool _disposed = false;

  /// Updated every second; the pill and the sheet listen to this only.
  final ValueNotifier<PrayerStatus?> status = ValueNotifier<PrayerStatus?>(null);

  /// Source of "now" (overridable for screenshots and tests).
  final DateTime Function() _clock;
  final bool _autoTick;

  PrayerService(this._prefs, {DateTime Function()? clock, bool autoTick = true})
      : _clock = clock ?? DateTime.now,
        _autoTick = autoTick {
    _tick();
    if (_autoTick) {
      _startTicker();
      WidgetsBinding.instance.addObserver(this);
    }
  }

  /// Recomputes the status immediately (e.g. after changing the test clock).
  void refresh() {
    _days.clear();
    _tick();
  }

  bool get enabled => _prefs.getBool(_kEnabled) ?? true;

  PrayerCity get city => prayerCityById(_prefs.getString(_kCity));

  bool get hanafiAsr => _prefs.getBool(_kHanafi) ?? false;

  bool get arabicNames => _prefs.getBool(_kArabic) ?? true;

  bool get countdownToSunrise => _prefs.getBool(_kSunrise) ?? true;

  int get hijriAdjustment => (_prefs.getInt(_kHijriAdjustment) ?? 0).clamp(-2, 2).toInt();

  PrayerStrings get strings => PrayerStrings(arabicNames);

  PrayerConfig get config => PrayerConfig(city: city, hanafiAsr: hanafiAsr, hijriAdjustmentDays: hijriAdjustment);

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_kEnabled, value);
    _settingsChanged();
  }

  Future<void> setCity(String cityId) async {
    await _prefs.setString(_kCity, cityId);
    _settingsChanged();
  }

  Future<void> setHanafiAsr(bool value) async {
    await _prefs.setBool(_kHanafi, value);
    _settingsChanged();
  }

  Future<void> setArabicNames(bool value) async {
    await _prefs.setBool(_kArabic, value);
    _settingsChanged();
  }

  Future<void> setCountdownToSunrise(bool value) async {
    await _prefs.setBool(_kSunrise, value);
    _settingsChanged();
  }

  Future<void> setHijriAdjustment(int days) async {
    await _prefs.setInt(_kHijriAdjustment, days.clamp(-2, 2).toInt());
    _settingsChanged();
  }

  /// Times for a calendar day in the selected city (cached).
  PrayerDay day(int year, int month, int day) {
    final key = year * 10000 + month * 100 + day;
    final cached = _days[key];
    if (cached != null) return cached;
    if (_days.length > 16) _days.clear();
    return _days[key] = PrayerEngine.computeDay(config, year, month, day);
  }

  void _settingsChanged() {
    _days.clear();
    _tick();
    notifyListeners();
  }

  void _tick() {
    if (_disposed) return;
    try {
      status.value = PrayerEngine.status(
        config,
        _clock().toUtc(),
        includeSunrise: countdownToSunrise,
        dayLookup: day,
      );
    } catch (error, stack) {
      // Never let a calculation problem take the launcher down.
      debugPrint('Prayer times unavailable: $error\n$stack');
      status.value = null;
    }
  }

  void _startTicker() {
    _timer?.cancel();
    // Align ticks to the start of each second so the countdown changes crisply.
    final delay = 1000 - _clock().millisecond;
    _timer = Timer(Duration(milliseconds: delay), () {
      if (_disposed) return;
      _tick();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _days.clear(); // the clock or time zone may have changed while away
      _tick();
      _startTicker();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_autoTick) {
      WidgetsBinding.instance.removeObserver(this);
    }
    status.dispose();
    super.dispose();
  }
}
