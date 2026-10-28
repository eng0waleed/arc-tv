# Arc TV

A personal build of [Arc Launcher](https://github.com/meddouribadis/arclauncher) for a TCL Google TV,
with prayer times built in and a one-button way to make it the TV's Home screen.

## What's different from Arc Launcher

- **Prayer pill** in the centre of the top bar: next prayer, its time and a live countdown
  (rolling digits, progress ring). At adhan time it shows **حان الآن** with a soft gold glow
  for 20 minutes.
- **Day sheet**: select the pill (OK on the remote) to see all six times, the Hijri date and the
  calculation method. Back closes it.
- **Offline calculation** with the [`adhan`](https://pub.dev/packages/adhan) package.
  Jeddah / Umm al-Qura by default; Asr standard (Shafi'i).
  In Ramadan, Isha moves 30 minutes later automatically (Umm al-Qura rule), using the
  Umm al-Qura Hijri calendar (with an optional ±2 day adjustment for the announced start).
- **Settings → مواقيت الصلاة**: city (Saudi + Gulf, each with its local method), Hanafi Asr,
  Arabic/English names, sunrise in the countdown, show/hide.
- **Settings → زر الرئيسية (Home)**: makes Arc the Home app and keeps Back inside Arc.
  It talks to the TV's own debugging service (the same thing `adb` uses) and runs only:
  ```
  cmd package set-home-activity com.omeda.arc/com.omeda.arc.MainActivity
  pm disable-user --user 0 com.google.android.tungsten.setupwraith
  pm disable-user --user 0 com.google.android.apps.tv.launcherx
  ```
  Nothing is uninstalled and no TCL package (Inputs menu, TV service) is touched.
  **Undo** on the same page runs `pm enable` for both and gives Home back to Google TV.
- The first row of apps is always on screen without scrolling.
- A darker default wallpaper ("Arc Night") so the gold accents stand out.

## Install on the TV (no computer needed)

1. On the TV, install **Downloader** (by AFTVnews) from Google Play.
2. Open Downloader, allow it to install apps when asked, and enter:
   ```
   https://github.com/eng0waleed/arc-tv/releases/latest/download/arc.apk
   ```
   Tip: the Google TV remote in the Google Home app on your phone has a keyboard you can paste into.
3. Install, then open **Arc Launcher**.
4. In Arc: press **Up** (prayer pill) → **Left** (gear) → **زر الرئيسية (Home)** →
   **اجعل Arc الشاشة الرئيسية**. When the TV asks *"Allow USB debugging?"*, tick
   *"Always allow from this computer"* and press OK.
5. Check: **Home** opens Arc, **Back** stays in Arc, **Input/Source** still opens the HDMI list.

Updates: Arc settings → *Check for updates* (downloads the newest build from this repository).

## Undo

- In Arc: Settings → زر الرئيسية (Home) → **استرجاع واجهة Google TV (تراجع)**.
- Without Arc: TV Settings → Apps → See all apps → Show system apps → **Google TV Home** → Enable
  (and the same for **Google TV Setup** if listed), then uninstall Arc Launcher.
- From a computer with adb:
  ```
  adb connect TV_IP:5555
  adb shell pm enable com.google.android.apps.tv.launcherx
  adb shell pm enable com.google.android.tungsten.setupwraith
  adb shell cmd role remove-role-holder android.app.role.HOME com.omeda.arc
  ```

## Building

GitHub Actions builds every push to `main` with Flutter 3.41.9 (from `.fvmrc`), runs the
prayer-time tests (including the Jeddah 26 Oct 2026 check: Fajr 05:06, Sunrise 06:23,
Dhuhr 12:07, Asr 15:24, Maghrib 17:51, Isha 19:21), renders TV screenshots, and publishes
`arc.apk` as the latest release. Logs and screenshots are pushed to the `ci` branch.
The APK signing key is created on the first build and stored encrypted (AES-256) on the
`signing` branch; it can only be decrypted with the `ARC_TV_SIGNING_SECRET` repository secret.

## Credits and licence

Arc Launcher © its authors (based on FLauncher © Étienne Fesser), GNU GPL v3 — see `LICENSE`.
Umm al-Qura month table from [hijridate](https://github.com/dralshehri/hijridate) (MIT).
Prayer-time maths: [adhan](https://github.com/iamriajul/adhan-dart) (MIT).
The original project README is in [`docs/UPSTREAM_README.md`](docs/UPSTREAM_README.md).
