// Arc TV: "Home button" page — makes Arc the TV's Home screen and can undo it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../prayer/prayer_service.dart';
import '../prayer/prayer_theme.dart';
import '../providers/apps_service.dart';
import '../providers/launcher_state.dart';
import '../providers/settings_service.dart';
import '../widgets/settings/focusable_settings_tile.dart';
import '../widgets/settings/settings_theme.dart';
import 'kiosk_service.dart';

class KioskPage extends StatefulWidget {
  static const String routeName = 'arc_tv_kiosk';

  const KioskPage({super.key});

  @override
  State<KioskPage> createState() => _KioskPageState();
}

class _KioskPageState extends State<KioskPage> {
  final KioskService _kiosk = KioskService();
  KioskStatus? _status;
  bool _busy = false;
  String? _progress;
  String? _resultLog;
  bool? _resultOk;

  @override
  void initState() {
    super.initState();
    KioskService.onProgress = (event) {
      if (mounted) setState(() => _progress = event);
    };
    _refresh();
  }

  @override
  void dispose() {
    KioskService.onProgress = null;
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final status = await _kiosk.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Status is informative only.
    }
  }

  Future<void> _run({required bool setup}) async {
    if (_busy) return;
    final settings = context.read<SettingsService>();
    final launcherState = context.read<LauncherState>();
    final appsService = context.read<AppsService>();
    setState(() {
      _busy = true;
      _progress = 'connecting';
      _resultLog = null;
      _resultOk = null;
    });
    KioskResult result;
    try {
      result = setup ? await _kiosk.setupHome() : await _kiosk.restoreHome();
    } catch (error) {
      result = KioskResult(ok: false, log: '$error');
    }
    await settings.setKioskMode(setup && result.ok);
    await launcherState.refresh(appsService);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _progress = null;
      _resultOk = result.ok;
      _resultLog = result.log.trim();
      _status = result.status ?? _status;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final ar = context.select<PrayerService, bool>((p) => p.arabicNames);
    String t(String arabic, String english) => ar ? arabic : english;

    final body = Theme.of(context).textTheme.bodyMedium;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.65));
    final status = _status;

    String packageState(String pkg) {
      switch (status?.stateOf(pkg)) {
        case 'enabled':
          return t('مفعّل', 'enabled');
        case 'disabled':
          return t('معطّل', 'turned off');
        case 'missing':
          return t('غير موجود', 'not installed');
        default:
          return '—';
      }
    }

    Widget statusRow(bool good, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Row(
            children: [
              Icon(
                good ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 18,
                color: good ? PrayerColors.gold : Colors.white38,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: small?.copyWith(color: Colors.white.withValues(alpha: 0.85)))),
              Text(value, style: small),
            ],
          ),
        );

    final progressText = switch (_progress) {
      'approval' => t(
          'على التلفاز: إذا ظهرت رسالة «السماح بتصحيح USB؟» فعّل «السماح دائمًا من هذا الكمبيوتر» ثم اضغط «موافق».',
          'On the TV: when "Allow USB debugging?" appears, tick "Always allow from this computer" and press OK.'),
      'running' => t('جارٍ التطبيق…', 'Applying…'),
      _ => t('جارٍ الاتصال بخدمة التصحيح في التلفاز…', 'Connecting to the TV\'s debugging service…'),
    };

    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        children: [
          SettingsPageHeader(title: t('زر الرئيسية (Home)', 'Home button')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    t('يجعل Arc الشاشة الرئيسية: زر Home وزر الرجوع يبقيان في Arc. يتم ذلك عبر خدمة التصحيح في التلفاز نفسه، ولا يُحذف أي تطبيق.',
                        'Makes Arc the Home screen so Home and Back always stay in Arc. It uses the TV\'s own debugging service; nothing is uninstalled.'),
                    style: small,
                  ),
                ),
                if (status != null) ...[
                  statusRow(status.isDefault, t('Arc هو الشاشة الرئيسية', 'Arc is the Home app'),
                      status.isDefault ? t('نعم', 'yes') : t('لا', 'no')),
                  statusRow(status.stateOf(KioskPackages.launcherX) != 'enabled', 'Google TV Home',
                      packageState(KioskPackages.launcherX)),
                  statusRow(status.stateOf(KioskPackages.setupWraith) != 'enabled', 'Google TV Setup',
                      packageState(KioskPackages.setupWraith)),
                  statusRow(status.stateOf(KioskPackages.tclInputs) != 'disabled',
                      t('قائمة المصادر (TCL)', 'Inputs menu (TCL)'), packageState(KioskPackages.tclInputs)),
                  const SizedBox(height: 6),
                ],
                FocusableSettingsTile(
                  autofocus: true,
                  leading: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.home_rounded),
                  title: Text(t('اجعل Arc الشاشة الرئيسية', 'Make Arc the Home screen'), style: body),
                  subtitle: Text(
                      t('يعطّل واجهة Google TV (قابل للتراجع). عند سؤال «السماح بتصحيح USB؟» اختر «السماح دائمًا» ثم «موافق».',
                          'Turns off the Google TV home (reversible). When asked "Allow USB debugging?", choose "Always allow", then OK.'),
                      style: small),
                  onPressed: _busy ? null : () => _run(setup: true),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.restore_rounded),
                  title: Text(t('استرجاع واجهة Google TV (تراجع)', 'Restore Google TV home (undo)'), style: body),
                  onPressed: _busy ? null : () => _run(setup: false),
                ),
                FocusableSettingsTile(
                  leading: const Icon(Icons.developer_mode_rounded),
                  title: Text(t('خيارات المطوّر', 'Developer options'), style: body),
                  subtitle: Text(t('تأكد من تفعيل «تصحيح USB»', 'Make sure "USB debugging" is on'), style: small),
                  onPressed: _busy ? null : () => _kiosk.openDeveloperOptions(),
                ),
                if (_busy)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                    child: Text(progressText, style: body?.copyWith(color: PrayerColors.gold)),
                  ),
                if (_resultOk != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                    child: Text(
                      _resultOk!
                          ? t('تم ✓ اضغط زر Home للتأكد.', 'Done ✓ Press Home to check.')
                          : t('لم يكتمل. التفاصيل أدناه.', 'Not completed. Details below.'),
                      style: body?.copyWith(color: _resultOk! ? PrayerColors.gold : Colors.orangeAccent),
                    ),
                  ),
                if (_resultLog != null && _resultLog!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        _resultLog!,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70, height: 1.35),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
