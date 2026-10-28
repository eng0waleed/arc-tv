// Arc TV: talks to the native side that makes Arc the TV's Home app.
//
// The native code connects to the TV's own debugging service (adb over Wi-Fi,
// 127.0.0.1:5555) and runs a fixed, reversible set of commands:
//   cmd package set-home-activity com.omeda.arc/com.omeda.arc.MainActivity
//   pm disable-user --user 0 com.google.android.tungsten.setupwraith
//   pm disable-user --user 0 com.google.android.apps.tv.launcherx
// and, to undo, `pm enable` for both plus restoring Google TV as Home.
// Nothing is ever uninstalled and no TCL package is touched.

import 'package:flutter/services.dart';

class KioskPackages {
  KioskPackages._();

  static const String launcherX = 'com.google.android.apps.tv.launcherx';
  static const String setupWraith = 'com.google.android.tungsten.setupwraith';
  static const String tclInputs = 'com.tcl.suspension';
  static const String tclTv = 'com.tcl.tv';
}

class KioskStatus {
  final bool isDefault;
  final String? homeComponent;

  /// package -> enabled | disabled | missing | unknown
  final Map<String, String> packages;

  const KioskStatus({required this.isDefault, required this.homeComponent, required this.packages});

  factory KioskStatus.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['packages'];
    final packages = <String, String>{};
    if (raw is Map) {
      raw.forEach((key, value) => packages['$key'] = '$value');
    }
    return KioskStatus(
      isDefault: map['isDefault'] == true,
      homeComponent: map['homeComponent'] as String?,
      packages: packages,
    );
  }

  String stateOf(String packageName) => packages[packageName] ?? 'unknown';
}

class KioskResult {
  final bool ok;
  final String log;
  final KioskStatus? status;

  const KioskResult({required this.ok, required this.log, this.status});

  factory KioskResult.fromMap(Map<dynamic, dynamic> map) {
    final status = map['status'];
    return KioskResult(
      ok: map['ok'] == true,
      log: (map['log'] as String?) ?? '',
      status: status is Map ? KioskStatus.fromMap(status) : null,
    );
  }
}

class KioskService {
  static const MethodChannel _channel = MethodChannel('com.omeda.arc/kiosk');

  /// Progress events from the native side: "connecting", "approval", "running".
  static void Function(String event)? onProgress;
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'progress') {
        onProgress?.call('${call.arguments}');
      }
      return null;
    });
  }

  Future<KioskStatus> status() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('status');
    return KioskStatus.fromMap(map ?? const {});
  }

  Future<KioskResult> setupHome() async {
    _ensureHandler();
    final map = await _channel.invokeMapMethod<String, dynamic>('setupHome');
    return KioskResult.fromMap(map ?? const {});
  }

  Future<KioskResult> restoreHome() async {
    _ensureHandler();
    final map = await _channel.invokeMapMethod<String, dynamic>('restoreHome');
    return KioskResult.fromMap(map ?? const {});
  }

  Future<void> openDeveloperOptions() => _channel.invokeMethod<void>('openDeveloperOptions');
}
