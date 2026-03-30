package com.example.apporbit

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import com.airbnb.lottie.LottieAnimationView
import com.airbnb.lottie.LottieDrawable
import androidx.appcompat.view.ContextThemeWrapper

class AppBlockerService : Service() {

    companion object {
        val temporaryWhitelist = mutableMapOf<String, Long>()

        fun grantEmergencyAccess(packageName: String, minutes: Int) {
            val expireTime = System.currentTimeMillis() + (minutes * 60 * 1000)
            temporaryWhitelist[packageName] = expireTime
        }
    }

    private lateinit var windowManager: WindowManager
    private lateinit var overlayContainer: LinearLayout
    private val handler = Handler(Looper.getMainLooper())
    private var isOverlayShowing = false
    private var currentForegroundPackage = ""

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val notification = NotificationCompat.Builder(this, "blocker_channel")
            .setContentTitle("AppOrbit Active")
            .setContentText("Guarding your focus...")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .build()
        startForeground(1, notification)

        setupPremiumOverlay()
        startMonitoring()
    }

    // ✨ UPGRADED: Floating, rounded, premium glass-like UI
    private fun setupPremiumOverlay() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val themeContext = ContextThemeWrapper(this, androidx.appcompat.R.style.Theme_AppCompat_NoActionBar)

        // The outer fullscreen background (dark translucent)
        overlayContainer = LinearLayout(themeContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#CC000000")) // 80% Black
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // The inner floating card
        val cardBackground = GradientDrawable().apply {
            colors = intArrayOf(Color.parseColor("#1E293B"), Color.parseColor("#0F172A"))
            cornerRadius = 60f
            setStroke(3, Color.parseColor("#33FFFFFF")) // Subtle glowing border
        }

        val popupCard = LinearLayout(themeContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = cardBackground
            setPadding(60, 80, 60, 80)
            val params = LinearLayout.LayoutParams(
                (resources.displayMetrics.widthPixels * 0.85).toInt(),
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            layoutParams = params
        }

        val animationView = LottieAnimationView(themeContext).apply {
            try {
                setAnimation("lock_animation.lottie")
                repeatCount = LottieDrawable.INFINITE
                playAnimation()
            } catch (e: Exception) { e.printStackTrace() }
            layoutParams = LinearLayout.LayoutParams(350, 350).apply { setMargins(0, 0, 0, 30) }
        }

        val warningText = TextView(themeContext).apply {
            text = "App Locked"
            setTextColor(Color.WHITE)
            textSize = 24f
            setTypeface(null, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
        }

        val subText = TextView(themeContext).apply {
            text = "Focus mode is active."
            setTextColor(Color.parseColor("#A0AABF"))
            textSize = 15f
            gravity = Gravity.CENTER
            setPadding(0, 10, 0, 60)
        }

        val closeButton = Button(themeContext).apply {
            text = "Exit App"
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1AFFFFFF"))
                cornerRadius = 30f
            }
            setTextColor(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 130).apply { setMargins(0, 0, 0, 20) }
            setOnClickListener {
                val startMain = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(startMain)
            }
        }

        val unlockButton = Button(themeContext).apply {
            text = "Use for 5 Mins"
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#3B82F6"))
                cornerRadius = 30f
            }
            setTextColor(Color.WHITE)
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 130)
            setOnClickListener {
                val intent = Intent(this@AppBlockerService, AuthActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    putExtra("package_to_unlock", currentForegroundPackage)
                }
                startActivity(intent)
                hideOverlay() // ✨ FIXED: Hides the overlay so the fingerprint scanner can show smoothly!
            }
        }

        popupCard.addView(animationView)
        popupCard.addView(warningText)
        popupCard.addView(subText)
        popupCard.addView(closeButton)
        popupCard.addView(unlockButton)
        overlayContainer.addView(popupCard)
    }

    private fun startMonitoring() {
        handler.post(object : Runnable {
            override fun run() {
                checkCurrentApp()
                handler.postDelayed(this, 1000)
            }
        })
    }

    private fun checkCurrentApp() {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val currentTime = System.currentTimeMillis()

        temporaryWhitelist.entries.removeIf { it.value < currentTime }

        val events = usageStatsManager.queryEvents(currentTime - 1000 * 10, currentTime)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                currentForegroundPackage = event.packageName
            }
        }

        val appOrbitPrefs = getSharedPreferences("AppOrbitPrefs", Context.MODE_PRIVATE)
        val blockedApps = appOrbitPrefs.getStringSet("restricted_packages", setOf()) ?: setOf()

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isLockdown = flutterPrefs.getBoolean("flutter.lockdown_enabled", false)

        val isAppBlocked = blockedApps.contains(currentForegroundPackage)
        val isNotAppOrbit = currentForegroundPackage != packageName
        val isNotWhitelisted = !temporaryWhitelist.containsKey(currentForegroundPackage)

        if (isLockdown && isAppBlocked && isNotAppOrbit && isNotWhitelisted) {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    private fun showOverlay() {
        if (!isOverlayShowing) {
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            )
            try {
                windowManager.addView(overlayContainer, params)
                isOverlayShowing = true
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    private fun hideOverlay() {
        if (isOverlayShowing) {
            try {
                windowManager.removeView(overlayContainer)
                isOverlayShowing = false
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("blocker_channel", "App Blocker", NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
        handler.removeCallbacksAndMessages(null)
    }
}