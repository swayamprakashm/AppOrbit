import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

class SecurityService {
  static final LocalAuthentication _auth = LocalAuthentication();

  // ✨ Method that handles biometrics and shows Lottie feedback
  static Future<bool> authenticateWithVisuals(BuildContext context, {required String reason}) async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return false;

      // 1. Trigger the native system prompt
      final bool success = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Set to true if you ONLY want fingerprint
        ),
      );

      // 2. Show the relevant animation based on success or failure
      if (context.mounted) {
        _showFeedbackOverlay(context, success);
      }

      return success;
    } on PlatformException catch (e) {
      debugPrint("Auth Error: $e");
      return false;
    }
  }

  // Helper to show the animation overlay
  static void _showFeedbackOverlay(BuildContext context, bool isAccepted) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: false,
      builder: (context) {
        // Automatically dismiss the animation overlay after 2 seconds
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (context.mounted) Navigator.pop(context);
        });

        return Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Lottie.asset(
              isAccepted ? 'assets/accepted.lottie' : 'assets/denied.lottie',
              repeat: false,
              animate: true,
              fit: BoxFit.contain,
              // ✨ FIX: Catches parser errors from compressed .lottie files
              onWarning: (warning) => debugPrint("Lottie Warning: $warning"),
              errorBuilder: (context, error, stackTrace) {
                debugPrint("Lottie Error: $error");
                // Fallback UI if the animation file fails to render
                return Icon(
                  isAccepted ? Icons.check_circle : Icons.error,
                  color: isAccepted ? Colors.greenAccent : Colors.redAccent,
                  size: 80,
                );
              },
            ),
          ),
        );
      },
    );
  }
}