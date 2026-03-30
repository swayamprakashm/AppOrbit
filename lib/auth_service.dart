import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticateUser({required String reason}) async {
    try {
      // 1. Check if the device hardware supports biometrics
      bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canAuthenticateWithBiometrics || !isDeviceSupported) {
        return false; // Fallback to PIN logic here if you want
      }

      // 2. Trigger the native Fingerprint/Face ID prompt
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,      // Keeps auth alive if user briefly switches apps
          biometricOnly: false,  // Set to false to allow PIN fallback if finger fails
        ),
      );
    } on PlatformException catch (e) {
      print("Auth Error: $e");
      return false;
    }
  }
}