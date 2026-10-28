// Arc TV: renders the real launcher screens at TV resolution (1920x1080) so the
// build can publish screenshots. Run with:
//   flutter test test/screenshots
// The images are written to build/arc_tv_screens/.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flauncher/flauncher.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/kiosk/kiosk_page.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/prayer/prayer_service.dart';
import 'package:flauncher/prayer/prayer_settings_page.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/launcher_state.dart';
import 'package:flauncher/providers/network_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/providers/watch_next_service.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks.dart';
import '../mocks.mocks.dart';

const _rootKey = ValueKey('arc-tv-screen');

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final materialFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var added = 0;
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
        added++;
      }
    }
    if (added > 0) {
      await loader.load();
    }
  }

  await load('Roboto', [
    '$materialFonts/Roboto-Regular.ttf',
    '$materialFonts/Roboto-Medium.ttf',
    '$materialFonts/Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', ['$materialFonts/MaterialIcons-Regular.otf']);
  await load('ArabicUI', [
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Medium.ttf',
    '/usr/share/fonts/truetype/noto/NotoSansArabic-Bold.ttf',
    '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Regular.ttf',
    '/usr/share/fonts/truetype/noto/NotoNaskhArabic-Bold.ttf',
  ]);
}

/// A TV-style banner: gradient with the app name, like real Android TV banners.
Future<Uint8List> _banner(String label, Color a, Color b) async {
  const width = 480;
  const height = 270;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  canvas.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [a, b]));
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textAlign: TextAlign.center,
    fontFamily: 'Roboto',
    fontSize: 62,
    fontWeight: FontWeight.w700,
  ))
    ..pushStyle(ui.TextStyle(color: Colors.white))
    ..addText(label);
  final paragraph = builder.build()..layout(ui.ParagraphConstraints(width: width.toDouble()));
  canvas.drawParagraph(paragraph, Offset(0, (height - paragraph.height) / 2));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

class _AppSpec {
  final String package;
  final String name;
  final Color a;
  final Color b;

  const _AppSpec(this.package, this.name, this.a, this.b);
}

const _dockApps = [
  _AppSpec('tv.youtube', 'YouTube', Color(0xFFE62117), Color(0xFF8E0E0A)),
  _AppSpec('tv.netflix', 'NETFLIX', Color(0xFF141414), Color(0xFF3A0A0C)),
  _AppSpec('tv.shahid', 'shahid', Color(0xFF0FB37A), Color(0xFF075E44)),
  _AppSpec('tv.prime', 'prime video', Color(0xFF1A98FF), Color(0xFF0B3C6E)),
  _AppSpec('tv.bein', 'beIN', Color(0xFF5B2A86), Color(0xFF2B1142)),
  _AppSpec('tv.stc', 'stc tv', Color(0xFF4F008C), Color(0xFFFF375E)),
];

const _gridApps = [
  _AppSpec('tv.disney', 'Disney+', Color(0xFF0A2F6E), Color(0xFF06142E)),
  _AppSpec('tv.osn', 'OSN+', Color(0xFF111111), Color(0xFF3B3B3B)),
  _AppSpec('tv.spotify', 'Spotify', Color(0xFF1DB954), Color(0xFF0C5427)),
  _AppSpec('tv.tod', 'TOD', Color(0xFF7A00FF), Color(0xFF2A005A)),
  _AppSpec('tv.ssc', 'SSC', Color(0xFF00A9E0), Color(0xFF004B6E)),
  _AppSpec('tv.twitch', 'Twitch', Color(0xFF9146FF), Color(0xFF3E1B7A)),
  _AppSpec('tv.plex', 'Plex', Color(0xFF282A2D), Color(0xFFE5A00D)),
  _AppSpec('tv.vlc', 'VLC', Color(0xFFFF8800), Color(0xFF8A3B00)),
  _AppSpec('tv.photos', 'Photos', Color(0xFF4285F4), Color(0xFF0F9D58)),
  _AppSpec('tv.files', 'Files', Color(0xFF455A64), Color(0xFF263238)),
  _AppSpec('tv.play', 'Play Store', Color(0xFF01875F), Color(0xFF00474F)),
  _AppSpec('tv.settings', 'Settings', Color(0xFF546E7A), Color(0xFF37474F)),
];

AppsService _appsService(Map<String, Uint8List> banners) {
  final service = MockAppsService();
  final dock = [for (final a in _dockApps) fakeApp(packageName: a.package, name: a.name)];
  final grid = [for (final a in _gridApps) fakeApp(packageName: a.package, name: a.name)];
  final favorites =
      fakeCategory(name: 'Favorites', id: 1, order: 0, type: CategoryType.row, applications: dock);
  final allApps = fakeCategory(name: 'All Apps', id: 2, order: 1, type: CategoryType.grid, applications: grid);
  when(service.initialized).thenReturn(true);
  when(service.layoutVersion).thenReturn(0);
  when(service.categories).thenReturn([favorites, allApps]);
  when(service.launcherSections).thenReturn([favorites, allApps]);
  when(service.getAppBanner(any)).thenAnswer(
      (invocation) async => banners[invocation.positionalArguments.first as String] ?? Uint8List(0));
  when(service.getAppIcon(any)).thenAnswer((_) async => Uint8List(0));
  when(service.hasCustomBanner(any)).thenAnswer((_) async => false);
  when(service.isAppInFavorites(any)).thenReturn(false);
  when(service.isDefaultLauncher()).thenAnswer((_) async => true);
  return service;
}

WallpaperService _wallpaperService() {
  final service = MockWallpaperService();
  when(service.gradient).thenReturn(FLauncherGradients.arcNight);
  when(service.wallpaper).thenReturn(null);
  when(service.wallpaperVideoFile).thenReturn(null);
  when(service.wallpaperRevision).thenReturn(0);
  when(service.slideshowAuthor).thenReturn(null);
  when(service.redditWallpaperCredit).thenReturn(null);
  return service;
}

WatchNextService _watchNextService() {
  final service = MockWatchNextService();
  when(service.hasPermission).thenReturn(false);
  when(service.hasItems).thenReturn(false);
  when(service.hasVisibleSection).thenReturn(false);
  when(service.items).thenReturn([]);
  when(service.activeHeroItem).thenReturn(null);
  when(service.refreshPermissionAndItems()).thenAnswer((_) async {});
  return service;
}

MockFLauncherChannel _channel() {
  final channel = MockFLauncherChannel();
  when(channel.getActiveNetworkInformation())
      .thenAnswer((_) async => <String, dynamic>{'networkType': 1, 'internetAccess': true, 'wirelessSignalLevel': 4});
  return channel;
}

ThemeData _theme(Color accent) => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['ArabicUI'],
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        secondary: accent,
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(elevation: 0, backgroundColor: Colors.transparent),
    );

Future<void> _settle(WidgetTester tester) async {
  // Image loading/decoding needs real time; alternate real waits with frames.
  for (var round = 0; round < 3; round++) {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Simulates the remote's Back button.
Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await _settle(tester);
}

/// Captures the screen at full TV resolution (1920x1080) into build/arc_tv_screens/.
Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_rootKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/arc_tv_screens/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('Arc TV screens', (tester) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);

    SharedPreferences.setMockInitialValues({
      'show_time_in_status_bar': false,
      'show_app_names_below_icons': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs);

    // 26 Oct 2026, 14:10 in Jeddah (UTC+3).
    var now = DateTime.utc(2026, 10, 26, 11, 10, 0);
    final prayer = PrayerService(prefs, clock: () => now, autoTick: false);

    final banners = <String, Uint8List>{};
    await tester.runAsync(() async {
      for (final spec in [..._dockApps, ..._gridApps]) {
        banners[spec.package] = await _banner(spec.name, spec.a, spec.b);
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.omeda.arc/kiosk'),
      (call) async => call.method == 'status'
          ? {
              'isDefault': true,
              'homeComponent': 'com.omeda.arc/com.omeda.arc.MainActivity',
              'packages': {
                'com.google.android.apps.tv.launcherx': 'disabled',
                'com.google.android.tungsten.setupwraith': 'disabled',
                'com.tcl.suspension': 'enabled',
                'com.tcl.tv': 'enabled',
              },
            }
          : null,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WallpaperService>.value(value: _wallpaperService()),
          ChangeNotifierProvider<AppsService>.value(value: _appsService(banners)),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
          ChangeNotifierProvider<WatchNextService>.value(value: _watchNextService()),
          ChangeNotifierProvider<PrayerService>.value(value: prayer),
          ChangeNotifierProvider(create: (_) => LauncherState()),
          ChangeNotifierProvider(create: (_) => NetworkService(_channel())),
        ],
        child: RepaintBoundary(
          key: _rootKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _theme(settings.accentColor),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FLauncher(),
          ),
        ),
      ),
    );

    // 1. Home screen, countdown to Asr; the remote has moved focus to the second app.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _shot(tester, '01_home_countdown');

    // 2. Up from the first row lands on the prayer pill.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await _shot(tester, '02_home_pill_focused');

    // 3. OK on the pill opens the full-day sheet.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _shot(tester, '03_prayer_sheet');
    await _back(tester);

    // 4. Adhan time: 15:30 in Jeddah, six minutes after Asr ("حان الآن").
    now = DateTime.utc(2026, 10, 26, 12, 30, 0);
    prayer.refresh();
    await _shot(tester, '04_home_adhan_now');

    // 5. The sheet at adhan time (focus is back on the pill after closing the sheet).
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _shot(tester, '05_prayer_sheet_adhan');
    await _back(tester);

    // 6. Prayer settings page.
    final context = tester.element(find.byType(FLauncher));
    showDialog<void>(context: context, builder: (_) => const SettingsPanel(initialRoute: PrayerSettingsPage.routeName));
    await _shot(tester, '06_prayer_settings');
    await _back(tester);

    // 7. City list.
    showDialog<void>(context: context, builder: (_) => const SettingsPanel(initialRoute: PrayerCityPage.routeName));
    await _shot(tester, '07_city_list');
    await _back(tester);

    // 8. Home-button page.
    showDialog<void>(context: context, builder: (_) => const SettingsPanel(initialRoute: KioskPage.routeName));
    await _shot(tester, '08_home_button_setup');
    await _back(tester);

    // 9. English names, evening countdown to Isha (19:00 in Jeddah).
    await prayer.setArabicNames(false);
    now = DateTime.utc(2026, 10, 26, 16, 0, 0);
    prayer.refresh();
    await _shot(tester, '09_home_english');

    // Clean up so no timers are left running.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
