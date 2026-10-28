import 'package:flauncher/prayer/prayer_engine.dart';
import 'package:flauncher/prayer/umm_al_qura.dart';
import 'package:flutter_test/flutter_test.dart';

String _hm(DateTime local) =>
    '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

void main() {
  final jeddah = prayerCityById('jeddah');
  final config = PrayerConfig(city: jeddah);

  test('Jeddah 26 Oct 2026 matches the Umm al-Qura sanity check', () {
    final day = PrayerEngine.computeDay(config, 2026, 10, 26);
    final local = day.times.map((t) => _hm(t.local(jeddah))).toList();
    expect(local, ['05:06', '06:23', '12:07', '15:24', '17:51', '19:21']);
    expect(day.ramadanIsha, isFalse);
  });

  test('Umm al-Qura Hijri dates', () {
    expect(UmmAlQura.fromGregorian(2026, 10, 28), const HijriDate(1448, 5, 17));
    expect(UmmAlQura.fromGregorian(2026, 2, 18), const HijriDate(1447, 9, 1));
    expect(UmmAlQura.fromGregorian(2026, 3, 19), const HijriDate(1447, 9, 30));
    expect(UmmAlQura.fromGregorian(2026, 3, 20), const HijriDate(1447, 10, 1));
    expect(UmmAlQura.fromGregorian(2027, 2, 8), const HijriDate(1448, 9, 1));
    expect(UmmAlQura.fromGregorian(1900, 1, 1), isNull);
  });

  test('Ramadan moves Isha to Maghrib + 120 min, only for Umm al-Qura', () {
    final ramadanDay = PrayerEngine.computeDay(config, 2027, 2, 15);
    expect(ramadanDay.ramadanIsha, isTrue);
    expect(ramadanDay[PrayerId.isha].utc.difference(ramadanDay[PrayerId.maghrib].utc).inMinutes, 120);

    final shawwalDay = PrayerEngine.computeDay(config, 2027, 3, 10);
    expect(shawwalDay.ramadanIsha, isFalse);
    expect(shawwalDay[PrayerId.isha].utc.difference(shawwalDay[PrayerId.maghrib].utc).inMinutes, 90);

    final doha = PrayerConfig(city: prayerCityById('doha'));
    expect(PrayerEngine.computeDay(doha, 2027, 2, 15).ramadanIsha, isFalse);
  });

  test('Hijri adjustment shifts the Ramadan rule', () {
    // 7 Feb 2027 is 30 Shaban 1448; with +1 day it counts as 1 Ramadan.
    expect(PrayerEngine.computeDay(config, 2027, 2, 7).ramadanIsha, isFalse);
    final adjusted = PrayerConfig(city: jeddah, hijriAdjustmentDays: 1);
    expect(PrayerEngine.computeDay(adjusted, 2027, 2, 7).ramadanIsha, isTrue);
  });

  test('Hanafi Asr is later than standard Asr', () {
    final standard = PrayerEngine.computeDay(config, 2026, 10, 26)[PrayerId.asr].utc;
    final hanafi = PrayerEngine.computeDay(PrayerConfig(city: jeddah, hanafiAsr: true), 2026, 10, 26)[PrayerId.asr].utc;
    expect(hanafi.isAfter(standard), isTrue);
  });

  test('Status: adhan window, countdown and day boundaries', () {
    // 15:30 Jeddah time = 12:30 UTC, six minutes after Asr (15:24).
    var s = PrayerEngine.status(config, DateTime.utc(2026, 10, 26, 12, 30));
    expect(s.current?.id, PrayerId.asr);
    expect(s.next.id, PrayerId.maghrib);
    expect(_hm(s.next.local(jeddah)), '17:51');
    expect(s.remaining, const Duration(hours: 2, minutes: 21));

    // 15:50: the 20 minute window is over.
    s = PrayerEngine.status(config, DateTime.utc(2026, 10, 26, 12, 50));
    expect(s.current, isNull);
    expect(s.previous.id, PrayerId.asr);
    expect(s.progress, greaterThan(0));
    expect(s.progress, lessThan(1));

    // 23:00 local: next is tomorrow's Fajr.
    s = PrayerEngine.status(config, DateTime.utc(2026, 10, 26, 20, 0));
    expect(s.next.id, PrayerId.fajr);
    expect(s.next.local(jeddah).day, 27);
    expect(s.previous.id, PrayerId.isha);

    // 03:00 local: previous is yesterday's Isha.
    s = PrayerEngine.status(config, DateTime.utc(2026, 10, 26, 0, 0));
    expect(s.previous.id, PrayerId.isha);
    expect(s.previous.local(jeddah).day, 25);
    expect(s.next.id, PrayerId.fajr);
    expect(s.today.day, 26);

    // 06:00 local without sunrise in the countdown: next is Dhuhr.
    s = PrayerEngine.status(config, DateTime.utc(2026, 10, 26, 3, 0), includeSunrise: false);
    expect(s.next.id, PrayerId.dhuhr);
    s = PrayerEngine.status(config, DateTime.utc(2026, 10, 26, 3, 0));
    expect(s.next.id, PrayerId.sunrise);
  });

  test('Every city computes a full, ordered year of times', () {
    for (final city in kPrayerCities) {
      final cfg = PrayerConfig(city: city);
      var date = DateTime.utc(2026, 1, 1);
      while (date.year == 2026) {
        final day = PrayerEngine.computeDay(cfg, date.year, date.month, date.day);
        for (var i = 1; i < day.times.length; i++) {
          expect(day.times[i].utc.isAfter(day.times[i - 1].utc), isTrue,
              reason: '${city.id} ${date.toIso8601String()} ${day.times[i].id}');
        }
        // Every time falls on the same local calendar day.
        for (final t in day.times) {
          expect(t.local(city).day, date.day, reason: '${city.id} ${date.toIso8601String()} ${t.id}');
        }
        date = date.add(const Duration(days: 5));
      }
    }
  });
}
