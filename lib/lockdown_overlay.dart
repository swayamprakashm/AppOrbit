import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'security_service.dart'; // ✨ FIXED: Direct root import
import 'package:flutter_animate/flutter_animate.dart';

class LockdownOverlay extends StatefulWidget {
  final String appName;
  const LockdownOverlay({super.key, required this.appName});

  @override
  State<LockdownOverlay> createState() => _LockdownOverlayState();
}

class _LockdownOverlayState extends State<LockdownOverlay> {
  bool _isAuthenticating = false;

  void _exitApp() {
    // ✨ Closes the blocked app and returns the user to the home screen
    SystemNavigator.pop();
  }

  Future<void> _requestEmergencyTime() async {
    setState(() => _isAuthenticating = true);

    // ✨ UPGRADED: Triggers the native prompt + Lottie animations
    bool success = await SecurityService.authenticateWithVisuals(
      context,
      reason: "Authorize 5 minutes of emergency use for ${widget.appName}",
    );

    if (success) {
      // Signals to the background service that this app is now whitelisted
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.85),
      body: Center(
        child: GlassmorphicContainer(
          width: 320,
          height: 420,
          borderRadius: 30,
          blur: 20,
          alignment: Alignment.center,
          border: 2,
          linearGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
          ),
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueAccent.withOpacity(0.5), Colors.purpleAccent.withOpacity(0.5)],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_rounded, color: Colors.redAccent, size: 70)
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 2.seconds, color: Colors.white38)
                    .shake(hz: 4, curve: Curves.easeInOut),

                const SizedBox(height: 25),

                Text(
                  "${widget.appName} is Locked",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                const Text(
                  "You've reached your limit for today. Focus on what truly matters!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),

                const Spacer(),

                // 🚪 EXIT BUTTON
                _buildButton(
                  text: "Exit App",
                  color: Colors.white.withOpacity(0.05),
                  textColor: Colors.white70,
                  onTap: () { _exitApp(); }, // ✨ FIXED: Strict Callback
                ),

                const SizedBox(height: 15),

                // ⏱️ 5 MINUTE EMERGENCY BUTTON
                _buildButton(
                  text: _isAuthenticating ? "Authenticating..." : "Unlock for 5 Mins",
                  color: Colors.blueAccent.withOpacity(0.7),
                  textColor: Colors.white,
                  icon: Icons.fingerprint,
                  onTap: _isAuthenticating ? null : () { _requestEmergencyTime(); }, // ✨ FIXED: Strict Callback
                ),
              ],
            ),
          ),
        ),
      ).animate().scale(curve: Curves.easeOutBack, duration: 600.ms).fadeIn(),
    );
  }

  Widget _buildButton({
    required String text,
    required Color color,
    required Color textColor,
    IconData? icon,
    VoidCallback? onTap
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        width: double.infinity,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              if (icon != null)
                BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 15, spreadRadius: -5)
            ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, color: textColor, size: 22),
            if (icon != null) const SizedBox(width: 12),
            Text(
                text,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)
            ),
          ],
        ),
      ),
    );
  }
}