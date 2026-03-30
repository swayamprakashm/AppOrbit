import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'main.dart'; // Needed to route to your PermissionPage or Onboarding

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // ✨ Wait for 3 seconds, then transition to the main app
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          // ⚠️ Change 'PermissionPage()' to whatever your main.dart was loading first
          MaterialPageRoute(builder: (context) => const PermissionPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f172a), // Matches your deep tech dark theme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✨ The Animated Logo
            Image.asset(
              'assets/app_logo.png',
              width: 150,
              height: 150,
            )
                .animate()
                .scale(duration: 800.ms, curve: Curves.easeOutBack) // Pops in
                .fadeIn(duration: 800.ms)
                .shimmer(delay: 800.ms, duration: 1500.ms, color: Colors.blueAccent.withOpacity(0.4)), // Cool sweeping light effect

            const SizedBox(height: 30),

            // ✨ The Animated App Name
            const Text(
              "AppOrbit",
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 800.ms)
                .slideY(begin: 0.5, end: 0, curve: Curves.easeOutQuart),
          ],
        ),
      ),
    );
  }
}