// Arc TV: Arabic / English strings for the prayer-time and Home-button features.

import 'package:flutter/widgets.dart';

import 'prayer_engine.dart';
import 'umm_al_qura.dart';

class PrayerStrings {
  final bool ar;

  const PrayerStrings(this.ar);

  TextDirection get direction => ar ? TextDirection.rtl : TextDirection.ltr;

  static const _namesAr = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
  static const _namesEn = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  String name(PrayerId id) => ar ? _namesAr[id.index] : _namesEn[id.index];

  String get nowLabel => ar ? 'حان الآن' : 'Time now';
  String get nextLabel => ar ? 'القادمة' : 'Next';
  String get title => ar ? 'مواقيت الصلاة' : 'Prayer times';
  String get settings => ar ? 'الإعدادات' : 'Settings';
  String get close => ar ? 'إغلاق' : 'Close';
  String get remainingPrefix => ar ? 'بعد' : 'in';
  String get am => ar ? 'ص' : 'AM';
  String get pm => ar ? 'م' : 'PM';
  String get ramadanNote => ar ? 'رمضان: العشاء بعد المغرب بساعتين' : 'Ramadan: Isha 2 h after Maghrib';

  String cityName(PrayerCity city) => ar ? city.nameAr : city.nameEn;
  String countryName(PrayerCity city) => ar ? city.countryAr : city.countryEn;

  String methodName(CityMethod method) {
    switch (method) {
      case CityMethod.ummAlQura:
        return ar ? 'تقويم أم القرى' : 'Umm al-Qura';
      case CityMethod.uae:
        return ar ? 'الهيئة العامة للشؤون الإسلامية (الإمارات)' : 'UAE Islamic Affairs';
      case CityMethod.kuwait:
        return ar ? 'وزارة الأوقاف الكويتية' : 'Kuwait Awqaf';
      case CityMethod.qatar:
        return ar ? 'وزارة الأوقاف القطرية' : 'Qatar Awqaf';
      case CityMethod.bahrain:
        return ar ? 'تقويم البحرين' : 'Bahrain timetable';
      case CityMethod.oman:
        return ar ? 'تقويم سلطنة عُمان' : 'Oman timetable';
    }
  }

  String asrName(bool hanafi) =>
      hanafi ? (ar ? 'العصر: الحنفي' : 'Asr: Hanafi') : (ar ? 'العصر: الجمهور' : 'Asr: standard');

  String hijri(HijriDate? date) {
    if (date == null) return '';
    final months = ar ? UmmAlQura.monthNamesAr : UmmAlQura.monthNamesEn;
    return ar ? '${date.day} ${months[date.month - 1]} ${date.year}هـ' : '${date.day} ${months[date.month - 1]} ${date.year} AH';
  }

  static const _gregMonthsAr = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  static const _gregMonthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdaysAr = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _weekdaysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  String gregorian(int year, int month, int day) {
    final weekday = DateTime.utc(year, month, day).weekday; // 1 = Monday
    return ar
        ? '${_weekdaysAr[weekday - 1]} $day ${_gregMonthsAr[month - 1]}'
        : '${_weekdaysEn[weekday - 1]} $day ${_gregMonthsEn[month - 1]}';
  }

  /// "15:24" or "3:24 م" depending on the TV's 24-hour setting.
  String clock(DateTime local, {required bool use24h}) {
    final minutes = local.minute.toString().padLeft(2, '0');
    if (use24h) {
      return '${local.hour.toString().padLeft(2, '0')}:$minutes';
    }
    final h12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '$h12:$minutes ${local.hour < 12 ? am : pm}';
  }

  /// "1:05:09" above an hour, "05:09" below.
  static String countdown(Duration remaining) {
    final total = remaining.isNegative ? 0 : remaining.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  // ---- Settings page ----
  String get showOnHome => ar ? 'إظهار المواقيت في الشاشة الرئيسية' : 'Show prayer times on Home';
  String get city => ar ? 'المدينة' : 'City';
  String get hanafiAsr => ar ? 'العصر على المذهب الحنفي' : 'Hanafi Asr';
  String get hanafiAsrHint => ar ? 'مغلق = الجمهور (الشافعي)' : 'Off = standard (Shafi\'i)';
  String get arabicNames => ar ? 'الأسماء بالعربية' : 'Arabic names';
  String get countSunrise => ar ? 'العدّ التنازلي للشروق' : 'Count down to sunrise';
  String get hijriAdjust => ar ? 'تعديل التاريخ الهجري' : 'Hijri date adjustment';
  String hijriAdjustValue(int days) {
    if (days == 0) return ar ? 'بدون تعديل (أم القرى)' : 'None (Umm al-Qura)';
    final sign = days > 0 ? '+' : '−';
    return ar ? '$sign${days.abs()} يوم' : '$sign${days.abs()} day${days.abs() == 1 ? '' : 's'}';
  }

  String get hijriAdjustHint =>
      ar ? 'استخدمه إذا اختلفت بداية رمضان المعلنة عن تقويم أم القرى' : 'Use if the announced Ramadan start differs from Umm al-Qura';
  String get ramadanAuto => ar ? 'في رمضان تُؤخَّر العشاء ٣٠ دقيقة تلقائيًا (أم القرى)' : 'Isha moves 30 min later in Ramadan automatically (Umm al-Qura)';
  String get chooseCity => ar ? 'اختر المدينة' : 'Choose city';

  // ---- Home button page ----
  String get homeButton => ar ? 'زر الرئيسية (Home)' : 'Home button';
  String get homeButtonSubtitle =>
      ar ? 'اجعل Arc الشاشة الرئيسية بدل واجهة Google TV' : 'Make Arc the Home screen instead of Google TV';
}
