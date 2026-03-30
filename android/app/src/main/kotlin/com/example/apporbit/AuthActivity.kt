package com.example.apporbit

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.fragment.app.FragmentActivity
import androidx.biometric.BiometricPrompt
import androidx.biometric.BiometricManager // ✨ FIXED: Added this missing import
import androidx.core.content.ContextCompat

class AuthActivity : FragmentActivity() {

    private var hasPrompted = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // No layout is set to keep this Activity invisible to the user
    }

    override fun onResume() {
        super.onResume()

        // Ensures the prompt only fires once per launch
        if (hasPrompted) return
        hasPrompted = true

        val targetPackage = intent.getStringExtra("package_to_unlock") ?: ""

        // 300ms delay: This is critical for invisible activities to ensure
        // the window is "attached" to the Android WindowManager before showing biometrics.
        Handler(Looper.getMainLooper()).postDelayed({
            val executor = ContextCompat.getMainExecutor(this)

            val biometricPrompt = BiometricPrompt(this, executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        super.onAuthenticationSucceeded(result)
                        // Success: Tell the blocker service to whitelist the app
                        AppBlockerService.grantEmergencyAccess(targetPackage, 5)
                        finish()
                    }

                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        super.onAuthenticationError(errorCode, errString)
                        // Failure/Cancel: Close the invisible activity and return to overlay
                        finish()
                    }

                    override fun onAuthenticationFailed() {
                        super.onAuthenticationFailed()
                        // Optional: Handle wrong finger placement
                    }
                })

            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("AppOrbit Security")
                .setSubtitle("Authenticate to unlock for 5 minutes")
                .setNegativeButtonText("Cancel")
                // ✨ FIXED: Changed to BiometricManager.Authenticators
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
                .build()

            try {
                biometricPrompt.authenticate(promptInfo)
            } catch (e: Exception) {
                e.printStackTrace()
                finish() // Exit if biometrics are unavailable
            }
        }, 300)
    }

    // Ensure we finish the activity if the user hits the back button
    override fun onBackPressed() {
        super.onBackPressed()
        finish()
    }
}