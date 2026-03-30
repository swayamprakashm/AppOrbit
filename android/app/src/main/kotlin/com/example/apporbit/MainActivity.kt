package com.example.apporbit

import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar

class MainActivity: FlutterFragmentActivity() {

    private val CHANNEL = "apporbit/usage"
    private var methodChannel: MethodChannel? = null

    // ✨ CATCH INTENT 1: If the app was closed and is being launched fresh
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Handle incoming intent from AppBlockerService
        val pendingPackage = intent.getStringExtra("trigger_auth_for_package")
        if (pendingPackage != null) {
            methodChannel?.invokeMethod("requestBiometricUnlock", pendingPackage)
        }

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // --- EXISTING METHODS ---
                "checkPermission" -> result.success(hasUsagePermission())

                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }

                "startLockdown" -> {
                    if (!Settings.canDrawOverlays(this@MainActivity)) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName"))
                        startActivity(intent)
                        result.success(false)
                    } else {
                        val serviceIntent = Intent(this, AppBlockerService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }
                        result.success(true)
                    }
                }

                "stopLockdown" -> {
                    stopService(Intent(this, AppBlockerService::class.java))
                    result.success(true)
                }

                "enableUninstallProtection" -> {
                    val componentName = ComponentName(this, AppOrbitDeviceAdmin::class.java)
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                    if (!dpm.isAdminActive(componentName)) {
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                        intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Protects AppOrbit from deletion.")
                        startActivity(intent)
                    }
                    result.success(true)
                }

                "disableUninstallProtection" -> {
                    val componentName = ComponentName(this, AppOrbitDeviceAdmin::class.java)
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                    if (dpm.isAdminActive(componentName)) dpm.removeActiveAdmin(componentName)
                    result.success(true)
                }

                "getInstalledApps" -> {
                    val pm = packageManager
                    val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
                    val apps = pm.queryIntentActivities(intent, 0)
                    val list = ArrayList<Map<String, Any>>()
                    for (info in apps) {
                        val map = HashMap<String, Any>()
                        map["name"] = info.loadLabel(pm).toString()
                        map["packageName"] = info.activityInfo.packageName
                        try {
                            val bitmap = drawableToBitmap(info.loadIcon(pm))
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            map["icon"] = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                        } catch (e: Exception) { map["icon"] = "" }
                        list.add(map)
                    }
                    result.success(list)
                }

                "setRestrictedApps" -> {
                    val apps = call.argument<List<String>>("apps") ?: listOf()
                    getSharedPreferences("AppOrbitPrefs", Context.MODE_PRIVATE)
                        .edit().putStringSet("restricted_packages", apps.toSet()).apply()
                    result.success(true)
                }

                // ✨ FIXED: Uses the new high-precision algorithm
                "getUsageStats" -> {
                    val accurateStats = getAccurateDailyUsage()
                    result.success(accurateStats)
                }

                "grantEmergencyAccess" -> {
                    val pkgName = call.argument<String>("package") ?: ""
                    val minutes = call.argument<Int>("minutes") ?: 5
                    AppBlockerService.grantEmergencyAccess(pkgName, minutes)

                    // Return the user to the app they just unlocked
                    val launchIntent = packageManager.getLaunchIntentForPackage(pkgName)
                    if (launchIntent != null) {
                        startActivity(launchIntent)
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ✨ CATCH INTENT 2: If the Flutter app was already running in the background
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val pendingPackage = intent.getStringExtra("trigger_auth_for_package")
        if (pendingPackage != null) {
            methodChannel?.invokeMethod("requestBiometricUnlock", pendingPackage)
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow("android:get_usage_stats", Process.myUid(), packageName) == AppOpsManager.MODE_ALLOWED
    }

    private fun drawableToBitmap(drawable: android.graphics.drawable.Drawable): Bitmap {
        if (drawable is BitmapDrawable) return drawable.bitmap
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 100
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 100

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    // ✨ NEW ALGORITHM: Highly accurate screen-time tracker (Matches Digital Wellbeing)
    private fun getAccurateDailyUsage(): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val pm = packageManager

        // Start from exactly midnight today
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)

        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        // Read specific resume/pause events instead of "total foreground time"
        val events = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()

        val appUsageMap = mutableMapOf<String, Long>()
        val startTimes = mutableMapOf<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName

            // Ignore Android system noise, launchers, and our own app
            if (packageName.contains("com.android.systemui") ||
                packageName.contains("launcher") ||
                packageName.contains("nexuslauncher") ||
                packageName == "com.example.apporbit") {
                continue
            }

            // User physically opened the app and is looking at it
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                startTimes[packageName] = event.timeStamp
            }
            // User closed the app or turned off the screen
            else if (event.eventType == UsageEvents.Event.ACTIVITY_PAUSED ||
                event.eventType == UsageEvents.Event.ACTIVITY_STOPPED) {
                val start = startTimes.remove(packageName)
                if (start != null) {
                    val duration = event.timeStamp - start
                    if (duration > 0) {
                        appUsageMap[packageName] = appUsageMap.getOrDefault(packageName, 0L) + duration
                    }
                }
            }
        }

        // Add the time for the app that is currently open right now
        startTimes.forEach { (pkg, start) ->
            val duration = endTime - start
            if (duration > 0) {
                appUsageMap[pkg] = appUsageMap.getOrDefault(pkg, 0L) + duration
            }
        }

        // Format data back to Flutter requirements
        val list = ArrayList<Map<String, Any>>()
        appUsageMap.forEach { (pkg, timeMs) ->
            if (timeMs > 60000) { // Only track apps used for more than 1 minute
                try {
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    val icon = drawableToBitmap(pm.getApplicationIcon(appInfo))
                    val stream = ByteArrayOutputStream()
                    icon.compress(Bitmap.CompressFormat.PNG, 100, stream)

                    list.add(mapOf(
                        "name" to pm.getApplicationLabel(appInfo).toString(),
                        "package" to pkg,
                        "time" to timeMs,
                        "icon" to Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
                    ))
                } catch (e: Exception) {
                    // Skip uninstalled apps
                }
            }
        }

        return list
    }
}