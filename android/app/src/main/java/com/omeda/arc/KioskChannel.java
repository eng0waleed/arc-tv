/*
 * Arc TV
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

package com.omeda.arc;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import androidx.annotation.NonNull;

import java.io.EOFException;
import java.io.File;
import java.io.IOException;
import java.net.ConnectException;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketTimeoutException;
import java.security.KeyPair;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Makes Arc the TV's Home app (and undoes it) by running a fixed, reversible list of
 * package-manager commands through the TV's own debugging service.
 * It never uninstalls anything and never touches TCL packages.
 */
final class KioskChannel implements MethodChannel.MethodCallHandler {
    static final String CHANNEL = "com.omeda.arc/kiosk";

    static final String LAUNCHERX = "com.google.android.apps.tv.launcherx";
    static final String SETUPWRAITH = "com.google.android.tungsten.setupwraith";
    private static final String[] REPORTED_PACKAGES = {
            LAUNCHERX, SETUPWRAITH, "com.tcl.suspension", "com.tcl.tv"
    };
    private static final String LAUNCHERX_FALLBACK_HOME =
            LAUNCHERX + "/com.google.android.apps.tv.launcherx.home.HomeActivity";
    private static final int ADB_PORT = 5555;

    private final Activity activity;
    private final MethodChannel channel;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private boolean running = false;

    private KioskChannel(Activity activity, BinaryMessenger messenger) {
        this.activity = activity;
        this.channel = new MethodChannel(messenger, CHANNEL);
        this.channel.setMethodCallHandler(this);
    }

    static void register(Activity activity, BinaryMessenger messenger) {
        new KioskChannel(activity, messenger);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "status":
                result.success(status());
                break;
            case "setupHome":
                runInBackground(true, result);
                break;
            case "restoreHome":
                runInBackground(false, result);
                break;
            case "openDeveloperOptions":
                result.success(openDeveloperOptions());
                break;
            default:
                result.notImplemented();
        }
    }

    private void runInBackground(boolean setup, MethodChannel.Result result) {
        if (running) {
            result.error("BUSY", "Already running", null);
            return;
        }
        running = true;
        executor.execute(() -> {
            Map<String, Object> outcome;
            try {
                outcome = setup ? setupHome() : restoreHome();
            } catch (RuntimeException e) {
                outcome = new HashMap<>();
                outcome.put("ok", false);
                outcome.put("log", "Unexpected error: " + e);
                outcome.put("status", status());
            }
            final Map<String, Object> finalOutcome = outcome;
            mainHandler.post(() -> {
                running = false;
                result.success(finalOutcome);
            });
        });
    }

    private void progress(String event) {
        mainHandler.post(() -> channel.invokeMethod("progress", event));
    }

    // ---- Operations ----------------------------------------------------------------------------

    private Map<String, Object> setupHome() {
        StringBuilder log = new StringBuilder();
        boolean ok = false;
        LocalAdb adb = null;
        try {
            adb = connect(log);
            progress("running");
            String component = activity.getPackageName() + "/" + MainActivity.class.getName();
            run(adb, log, "cmd package set-home-activity " + component);
            for (String pkg : new String[] {SETUPWRAITH, LAUNCHERX}) {
                if (isInstalled(pkg)) {
                    run(adb, log, "pm disable-user --user 0 " + pkg);
                } else {
                    log.append("• ").append(pkg).append(" is not on this TV, skipped\n");
                }
            }
            String resolved = run(adb, log,
                    "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").output;
            ok = resolved.contains(activity.getPackageName() + "/");
        } catch (IOException e) {
            log.append("✗ ").append(describe(e)).append('\n');
        } finally {
            if (adb != null) {
                adb.close();
            }
        }
        ok = ok && isDefaultHome();
        return outcome(ok, log);
    }

    private Map<String, Object> restoreHome() {
        StringBuilder log = new StringBuilder();
        boolean ok = false;
        LocalAdb adb = null;
        try {
            adb = connect(log);
            progress("running");
            for (String pkg : new String[] {LAUNCHERX, SETUPWRAITH}) {
                if (isInstalled(pkg)) {
                    run(adb, log, "pm enable " + pkg);
                }
            }
            boolean homeSet = false;
            if (isInstalled(LAUNCHERX)) {
                String target = findHomeActivity(LAUNCHERX);
                if (target == null) {
                    String homes = run(adb, log,
                            "cmd package query-activities --brief --components -a android.intent.action.MAIN -c android.intent.category.HOME").output;
                    target = findComponent(homes, LAUNCHERX);
                }
                if (target == null) {
                    target = LAUNCHERX_FALLBACK_HOME;
                }
                homeSet = run(adb, log, "cmd package set-home-activity " + target).ok;
            }
            if (!homeSet) {
                // Hand the Home role back to the system default.
                run(adb, log, "cmd role remove-role-holder android.app.role.HOME " + activity.getPackageName());
            }
            String resolved = run(adb, log,
                    "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME").output;
            ok = !resolved.contains(activity.getPackageName() + "/");
        } catch (IOException e) {
            log.append("✗ ").append(describe(e)).append('\n');
        } finally {
            if (adb != null) {
                adb.close();
            }
        }
        return outcome(ok, log);
    }

    private Map<String, Object> outcome(boolean ok, StringBuilder log) {
        Map<String, Object> result = new HashMap<>();
        result.put("ok", ok);
        result.put("log", log.toString());
        result.put("status", status());
        return result;
    }

    /** The HOME activity of [packageName] as "pkg/class", using PackageManager (no shell needed). */
    private String findHomeActivity(String packageName) {
        Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        intent.setPackage(packageName);
        List<ResolveInfo> matches = activity.getPackageManager().queryIntentActivities(intent, disabledMatchFlags());
        for (ResolveInfo info : matches) {
            if (info.activityInfo != null && packageName.equals(info.activityInfo.packageName)) {
                return new ComponentName(info.activityInfo.packageName, info.activityInfo.name).flattenToString();
            }
        }
        return null;
    }

    private static String findComponent(String output, String packageName) {
        Matcher matcher = Pattern.compile(Pattern.quote(packageName) + "/[\\w.$]+").matcher(output);
        return matcher.find() ? matcher.group() : null;
    }

    private static final class Shell {
        final String output;
        final boolean ok;

        Shell(String output, boolean ok) {
            this.output = output;
            this.ok = ok;
        }
    }

    private Shell run(LocalAdb adb, StringBuilder log, String command) throws IOException {
        String output = adb.shell(command + " 2>&1; echo \"__ARC_EXIT=$?\"", 30000);
        String exit = "?";
        int marker = output.lastIndexOf("__ARC_EXIT=");
        if (marker >= 0) {
            exit = output.substring(marker + "__ARC_EXIT=".length()).trim();
            output = output.substring(0, marker);
        }
        boolean ok = "0".equals(exit);
        log.append(ok ? "✓ " : "✗ ").append(command).append('\n');
        String trimmed = output.trim();
        if (!trimmed.isEmpty()) {
            log.append("   ").append(trimmed.replace("\n", "\n   ")).append('\n');
        }
        return new Shell(output, ok);
    }

    private LocalAdb connect(StringBuilder log) throws IOException {
        progress("connecting");
        File keyDirectory = new File(activity.getFilesDir(), "adb");
        KeyPair keys = LocalAdb.loadOrCreateKeys(keyDirectory);
        IOException lastError = null;
        for (String host : candidateHosts()) {
            try {
                LocalAdb adb = LocalAdb.connect(host, ADB_PORT, keys, () -> progress("approval"));
                log.append("✓ Connected to the TV's debugging service (").append(host).append(':')
                        .append(ADB_PORT).append(")\n");
                return adb;
            } catch (ConnectException e) {
                lastError = e;
            } catch (SocketTimeoutException e) {
                lastError = e;
            }
        }
        throw lastError != null ? lastError : new ConnectException("No network address");
    }

    private static List<String> candidateHosts() {
        List<String> hosts = new ArrayList<>();
        hosts.add("127.0.0.1");
        try {
            for (NetworkInterface networkInterface : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!networkInterface.isUp() || networkInterface.isLoopback()) {
                    continue;
                }
                for (InetAddress address : Collections.list(networkInterface.getInetAddresses())) {
                    if (address instanceof Inet4Address && !address.isLoopbackAddress()) {
                        hosts.add(address.getHostAddress());
                    }
                }
            }
        } catch (Exception ignored) {
        }
        return hosts;
    }

    private static String describe(IOException e) {
        if (e instanceof ConnectException) {
            return "Could not reach the TV's debugging service on port " + ADB_PORT
                    + ". Turn on Settings > System > Developer options > USB debugging"
                    + " (and \"Network debugging\" / \"ADB over network\" if your TV has it), then try again.";
        }
        if (e instanceof EOFException) {
            return "The TV closed the connection. If you pressed Cancel on the \"Allow USB debugging?\" prompt,"
                    + " try again and choose \"Always allow from this computer\".";
        }
        if (e instanceof SocketTimeoutException) {
            return "No answer from the TV in time. Try again and approve the \"Allow USB debugging?\" prompt.";
        }
        return e.getMessage() != null ? e.getMessage() : e.toString();
    }

    // ---- Status (no debugging needed) ----------------------------------------------------------

    private Map<String, Object> status() {
        Map<String, Object> result = new HashMap<>();
        ResolveInfo home = resolveHome();
        String component = null;
        if (home != null && home.activityInfo != null) {
            component = new ComponentName(home.activityInfo.packageName, home.activityInfo.name).flattenToString();
        }
        result.put("homeComponent", component);
        result.put("isDefault", isDefaultHome());
        Map<String, String> packages = new LinkedHashMap<>();
        for (String pkg : REPORTED_PACKAGES) {
            packages.put(pkg, packageState(pkg));
        }
        result.put("packages", packages);
        return result;
    }

    private ResolveInfo resolveHome() {
        Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
        return activity.getPackageManager().resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY);
    }

    private boolean isDefaultHome() {
        ResolveInfo home = resolveHome();
        return home != null && home.activityInfo != null
                && activity.getPackageName().equals(home.activityInfo.packageName);
    }

    @SuppressWarnings("deprecation")
    private int disabledMatchFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return PackageManager.MATCH_DISABLED_COMPONENTS | PackageManager.MATCH_UNINSTALLED_PACKAGES;
        }
        return PackageManager.GET_DISABLED_COMPONENTS | PackageManager.GET_UNINSTALLED_PACKAGES;
    }

    private boolean isInstalled(String packageName) {
        try {
            activity.getPackageManager().getApplicationInfo(packageName, disabledMatchFlags());
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    private String packageState(String packageName) {
        PackageManager packageManager = activity.getPackageManager();
        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, disabledMatchFlags());
            int setting = packageManager.getApplicationEnabledSetting(packageName);
            switch (setting) {
                case PackageManager.COMPONENT_ENABLED_STATE_DISABLED:
                case PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER:
                case PackageManager.COMPONENT_ENABLED_STATE_DISABLED_UNTIL_USED:
                    return "disabled";
                case PackageManager.COMPONENT_ENABLED_STATE_DEFAULT:
                    return info.enabled ? "enabled" : "disabled";
                default:
                    return "enabled";
            }
        } catch (PackageManager.NameNotFoundException e) {
            return "missing";
        } catch (IllegalArgumentException e) {
            return "unknown";
        }
    }

    private boolean openDeveloperOptions() {
        try {
            Intent intent = new Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
            return true;
        } catch (ActivityNotFoundException e) {
            try {
                activity.startActivity(new Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                return true;
            } catch (ActivityNotFoundException ignored) {
                return false;
            }
        }
    }
}
