// Arc TV: offline prayer-time engine built on the `adhan` package.
//
// Everything here is pure Dart (no Flutter) so it can be unit tested.
// All instants are handled in UTC; each city carries its own fixed UTC offset
// (none of the supported countries use daylight saving time).

import 'package:adhan/adhan.dart';

import 'umm_al_qura.dart';

/// The six daily times shown by the launcher, in chronological order.
enum PrayerId { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerIdX on PrayerId {
  /// Sunrise is the end of Fajr time, not a prayer with an adhan.
  bool get hasAdhan => this != PrayerId.sunrise;
}

/// Local calculation conventions per country.
enum CityMethod {
  /// Saudi Arabia: Umm al-Qura (Fajr 18.5°, Isha = Maghrib + 90 min, +30 min in Ramadan).
  ummAlQura,

  /// UAE: General Authority of Islamic Affairs (Fajr/Isha 18.2°, with its minute adjustments).
  uae,

  /// Kuwait: Ministry of Awqaf (Fajr 18°, Isha 17.5°).
  kuwait,

  /// Qatar: Ministry of Awqaf (Fajr 18°, Isha = Maghrib + 90 min).
  qatar,

  /// Bahrain: local timetable (Fajr 18.2°, Isha 18°, sunrise -1, dhuhr +2 min).
  bahrain,

  /// Oman: local timetable (Fajr 18°, Isha 18°, dhuhr/asr/maghrib +6 min).
  oman,
}

class PrayerCity {
  final String id;
  final String nameAr;
  final String nameEn;
  final String countryAr;
  final String countryEn;
  final double latitude;
  final double longitude;
  final int utcOffsetMinutes;
  final CityMethod method;

  const PrayerCity({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.countryAr,
    required this.countryEn,
    required this.latitude,
    required this.longitude,
    required this.utcOffsetMinutes,
    required this.method,
  });

  Duration get utcOffset => Duration(minutes: utcOffsetMinutes);
}

const _sa = ('السعودية', 'Saudi Arabia');
const _ae = ('الإمارات', 'UAE');
const _kw = ('الكويت', 'Kuwait');
const _qa = ('قطر', 'Qatar');
const _bh = ('البحرين', 'Bahrain');
const _om = ('عُمان', 'Oman');

PrayerCity _city(String id, String ar, String en, (String, String) country, double lat, double lng, int offsetHours,
        CityMethod method) =>
    PrayerCity(
      id: id,
      nameAr: ar,
      nameEn: en,
      countryAr: country.$1,
      countryEn: country.$2,
      latitude: lat,
      longitude: lng,
      utcOffsetMinutes: offsetHours * 60,
      method: method,
    );

const String kDefaultPrayerCityId = 'jeddah';

final List<PrayerCity> kPrayerCities = [
  // Saudi Arabia — Umm al-Qura, UTC+3
  _city('jeddah', 'جدة', 'Jeddah', _sa, 21.4858, 39.1925, 3, CityMethod.ummAlQura),
  _city('makkah', 'مكة المكرمة', 'Makkah', _sa, 21.4225, 39.8262, 3, CityMethod.ummAlQura),
  _city('madinah', 'المدينة المنورة', 'Madinah', _sa, 24.4686, 39.6142, 3, CityMethod.ummAlQura),
  _city('riyadh', 'الرياض', 'Riyadh', _sa, 24.7136, 46.6753, 3, CityMethod.ummAlQura),
  _city('dammam', 'الدمام', 'Dammam', _sa, 26.4207, 50.0888, 3, CityMethod.ummAlQura),
  _city('khobar', 'الخبر', 'Al Khobar', _sa, 26.2172, 50.1971, 3, CityMethod.ummAlQura),
  _city('jubail', 'الجبيل', 'Jubail', _sa, 27.0174, 49.6225, 3, CityMethod.ummAlQura),
  _city('ahsa', 'الأحساء', 'Al-Ahsa', _sa, 25.3833, 49.5833, 3, CityMethod.ummAlQura),
  _city('qatif', 'القطيف', 'Qatif', _sa, 26.5652, 49.9964, 3, CityMethod.ummAlQura),
  _city('taif', 'الطائف', 'Taif', _sa, 21.2703, 40.4158, 3, CityMethod.ummAlQura),
  _city('yanbu', 'ينبع', 'Yanbu', _sa, 24.0890, 38.0618, 3, CityMethod.ummAlQura),
  _city('rabigh', 'رابغ', 'Rabigh', _sa, 22.7986, 39.0349, 3, CityMethod.ummAlQura),
  _city('baha', 'الباحة', 'Al Baha', _sa, 20.0129, 41.4677, 3, CityMethod.ummAlQura),
  _city('abha', 'أبها', 'Abha', _sa, 18.2164, 42.5053, 3, CityMethod.ummAlQura),
  _city('khamis', 'خميس مشيط', 'Khamis Mushait', _sa, 18.3000, 42.7333, 3, CityMethod.ummAlQura),
  _city('jazan', 'جازان', 'Jazan', _sa, 16.8892, 42.5511, 3, CityMethod.ummAlQura),
  _city('najran', 'نجران', 'Najran', _sa, 17.4924, 44.1277, 3, CityMethod.ummAlQura),
  _city('kharj', 'الخرج', 'Al Kharj', _sa, 24.1556, 47.3120, 3, CityMethod.ummAlQura),
  _city('buraidah', 'بريدة', 'Buraidah', _sa, 26.3260, 43.9750, 3, CityMethod.ummAlQura),
  _city('unaizah', 'عنيزة', 'Unaizah', _sa, 26.0840, 43.9940, 3, CityMethod.ummAlQura),
  _city('hail', 'حائل', 'Hail', _sa, 27.5114, 41.7208, 3, CityMethod.ummAlQura),
  _city('hafar', 'حفر الباطن', 'Hafar Al-Batin', _sa, 28.4328, 45.9708, 3, CityMethod.ummAlQura),
  _city('tabuk', 'تبوك', 'Tabuk', _sa, 28.3838, 36.5550, 3, CityMethod.ummAlQura),
  _city('sakaka', 'سكاكا', 'Sakaka', _sa, 29.9697, 40.2064, 3, CityMethod.ummAlQura),
  _city('arar', 'عرعر', 'Arar', _sa, 30.9753, 41.0381, 3, CityMethod.ummAlQura),
  // UAE — UTC+4
  _city('dubai', 'دبي', 'Dubai', _ae, 25.2048, 55.2708, 4, CityMethod.uae),
  _city('abudhabi', 'أبوظبي', 'Abu Dhabi', _ae, 24.4539, 54.3773, 4, CityMethod.uae),
  _city('sharjah', 'الشارقة', 'Sharjah', _ae, 25.3463, 55.4209, 4, CityMethod.uae),
  _city('alain', 'العين', 'Al Ain', _ae, 24.2075, 55.7447, 4, CityMethod.uae),
  // Kuwait — UTC+3
  _city('kuwait', 'مدينة الكويت', 'Kuwait City', _kw, 29.3759, 47.9774, 3, CityMethod.kuwait),
  // Qatar — UTC+3
  _city('doha', 'الدوحة', 'Doha', _qa, 25.2854, 51.5310, 3, CityMethod.qatar),
  // Bahrain — UTC+3
  _city('manama', 'المنامة', 'Manama', _bh, 26.2285, 50.5860, 3, CityMethod.bahrain),
  // Oman — UTC+4
  _city('muscat', 'مسقط', 'Muscat', _om, 23.5880, 58.3829, 4, CityMethod.oman),
  _city('salalah', 'صلالة', 'Salalah', _om, 17.0151, 54.0924, 4, CityMethod.oman),
];

PrayerCity prayerCityById(String? id) =>
    kPrayerCities.firstWhere((c) => c.id == id, orElse: () => kPrayerCities.firstWhere((c) => c.id == kDefaultPrayerCityId));

/// User-facing settings that change the calculation.
class PrayerConfig {
  final PrayerCity city;
  final bool hanafiAsr;

  /// Days added to the Umm al-Qura date (to follow an announced moon sighting).
  final int hijriAdjustmentDays;

  const PrayerConfig({required this.city, this.hanafiAsr = false, this.hijriAdjustmentDays = 0});

  @override
  bool operator ==(Object other) =>
      other is PrayerConfig &&
      other.city.id == city.id &&
      other.hanafiAsr == hanafiAsr &&
      other.hijriAdjustmentDays == hijriAdjustmentDays;

  @override
  int get hashCode => Object.hash(city.id, hanafiAsr, hijriAdjustmentDays);
}

class PrayerTime {
  final PrayerId id;

  /// The exact instant, in UTC.
  final DateTime utc;

  const PrayerTime(this.id, this.utc);

  /// Wall-clock time in the city (a UTC DateTime shifted by the city's offset;
  /// read its hour/minute fields, never convert it again).
  DateTime local(PrayerCity city) => utc.add(city.utcOffset);
}

/// Prayer times for one calendar day in the city.
class PrayerDay {
  final int year;
  final int month;
  final int day;
  final List<PrayerTime> times;
  final HijriDate? hijri;

  /// True when Isha was moved 30 minutes later for Ramadan (Umm al-Qura rule).
  final bool ramadanIsha;

  const PrayerDay({
    required this.year,
    required this.month,
    required this.day,
    required this.times,
    required this.hijri,
    required this.ramadanIsha,
  });

  PrayerTime operator [](PrayerId id) => times[id.index];
}

/// Where "now" sits between the day's events.
class PrayerStatus {
  final PrayerDay today;
  final PrayerTime previous;
  final PrayerTime next;

  /// Set while we are inside the adhan window (e.g. the first 20 minutes after Asr).
  final PrayerTime? current;
  final DateTime nowUtc;

  const PrayerStatus({
    required this.today,
    required this.previous,
    required this.next,
    required this.current,
    required this.nowUtc,
  });

  Duration get remaining => next.utc.difference(nowUtc);

  /// 0..1 progress from the previous event to the next one.
  double get progress {
    final total = next.utc.difference(previous.utc).inMilliseconds;
    if (total <= 0) return 0;
    final done = nowUtc.difference(previous.utc).inMilliseconds;
    return (done / total).clamp(0.0, 1.0);
  }
}

class PrayerEngine {
  PrayerEngine._();

  static const Duration defaultAdhanWindow = Duration(minutes: 20);
  static const int ramadanIshaExtraMinutes = 30;

  static CalculationParameters parametersFor(CityMethod method, {required bool hanafi, required bool ramadan}) {
    final CalculationParameters params;
    switch (method) {
      case CityMethod.ummAlQura:
        params = CalculationMethod.umm_al_qura.getParameters();
        if (ramadan) {
          params.ishaInterval = params.ishaInterval + ramadanIshaExtraMinutes;
        }
        break;
      case CityMethod.uae:
        params = CalculationMethod.dubai.getParameters();
        break;
      case CityMethod.kuwait:
        params = CalculationMethod.kuwait.getParameters();
        break;
      case CityMethod.qatar:
        params = CalculationMethod.qatar.getParameters();
        break;
      case CityMethod.bahrain:
        params = CalculationParameters(fajrAngle: 18.2, ishaAngle: 18.0)
            .withMethodAdjustments(PrayerAdjustments(sunrise: -1, dhuhr: 2));
        break;
      case CityMethod.oman:
        params = CalculationParameters(fajrAngle: 18.0, ishaAngle: 18.0)
            .withMethodAdjustments(PrayerAdjustments(dhuhr: 6, asr: 6, maghrib: 6));
        break;
    }
    params.madhab = hanafi ? Madhab.hanafi : Madhab.shafi;
    return params;
  }

  static HijriDate? hijriFor(int year, int month, int day, {int adjustmentDays = 0}) {
    final shifted = DateTime.utc(year, month, day).add(Duration(days: adjustmentDays));
    return UmmAlQura.fromGregorian(shifted.year, shifted.month, shifted.day);
  }

  /// Times for the given calendar day in the city.
  static PrayerDay computeDay(PrayerConfig config, int year, int month, int day) {
    final hijri = hijriFor(year, month, day, adjustmentDays: config.hijriAdjustmentDays);
    final ramadan = config.city.method == CityMethod.ummAlQura && (hijri?.isRamadan ?? false);
    final params = parametersFor(config.city.method, hanafi: config.hanafiAsr, ramadan: ramadan);
    final pt = PrayerTimes.utc(
      Coordinates(config.city.latitude, config.city.longitude),
      DateComponents(year, month, day),
      params,
    );
    final times = <PrayerTime>[
      PrayerTime(PrayerId.fajr, pt.fajr.toUtc()),
      PrayerTime(PrayerId.sunrise, pt.sunrise.toUtc()),
      PrayerTime(PrayerId.dhuhr, pt.dhuhr.toUtc()),
      PrayerTime(PrayerId.asr, pt.asr.toUtc()),
      PrayerTime(PrayerId.maghrib, pt.maghrib.toUtc()),
      PrayerTime(PrayerId.isha, pt.isha.toUtc()),
    ];
    return PrayerDay(year: year, month: month, day: day, times: times, hijri: hijri, ramadanIsha: ramadan);
  }

  /// The city's calendar date at [nowUtc].
  static DateTime localDate(PrayerCity city, DateTime nowUtc) {
    final local = nowUtc.toUtc().add(city.utcOffset);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Computes where [nowUtc] sits between prayers.
  ///
  /// [includeSunrise] decides whether the countdown can target Sunrise.
  /// [dayLookup] lets callers cache [computeDay] results.
  static PrayerStatus status(
    PrayerConfig config,
    DateTime nowUtc, {
    bool includeSunrise = true,
    Duration adhanWindow = defaultAdhanWindow,
    PrayerDay Function(int year, int month, int day)? dayLookup,
  }) {
    final now = nowUtc.toUtc();
    final PrayerDay Function(int, int, int) lookup = dayLookup ?? ((int y, int m, int d) => computeDay(config, y, m, d));
    final today = localDate(config.city, now);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final todayDay = lookup(today.year, today.month, today.day);
    final events = <PrayerTime>[
      ...lookup(yesterday.year, yesterday.month, yesterday.day).times,
      ...todayDay.times,
      ...lookup(tomorrow.year, tomorrow.month, tomorrow.day).times,
    ].where((t) => includeSunrise || t.id != PrayerId.sunrise).toList();

    PrayerTime? previous;
    PrayerTime? next;
    for (final event in events) {
      if (!event.utc.isAfter(now)) {
        previous = event;
      } else {
        next = event;
        break;
      }
    }

    PrayerTime? current;
    for (final event in events.reversed) {
      if (!event.utc.isAfter(now)) {
        if (event.id.hasAdhan && now.difference(event.utc) < adhanWindow) {
          current = event;
        }
        break;
      }
    }

    return PrayerStatus(
      today: todayDay,
      previous: previous ?? events.first,
      next: next ?? events.last,
      current: current,
      nowUtc: now,
    );
  }
}
