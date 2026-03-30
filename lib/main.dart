import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dashboard.dart';
import 'onboarding.dart';
import 'splash_screen.dart'; // ✨ NEW: Imported your new animated splash screen!

// Made main() async and initialized Firebase
Future<void> main() async {
  // This ensures Flutter is fully loaded before Firebase starts
  WidgetsFlutterBinding.ensureInitialized();

  // This connects your app to the google-services.json file we added
  await Firebase.initializeApp();

  runApp(const AppOrbit());
}

class AppOrbit extends StatelessWidget {
  const AppOrbit({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppOrbit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      // ✨ UPDATED: Now the app boots directly into your animated logo!
      home: const SplashScreen(),
    );
  }
}

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> with WidgetsBindingObserver {
  static const platform = MethodChannel('apporbit/usage');
  bool hasPermission = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Detects when the user returns from the Android System Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkPermission();
    }
  }

  Future<void> checkPermission() async {
    try {
      final bool result = await platform.invokeMethod('checkPermission');
      setState(() {
        hasPermission = result;
        // Keep loading true if we have permission so the UI doesn't "flicker"
        // while we determine which screen to show next.
        if (!result) isLoading = false;
      });

      if (result) {
        _handleNavigation();
      }
    } catch (e) {
      debugPrint("Permission Check Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _handleNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('is_first_time') ?? true;

    if (isFirstTime) {
      // First launch logic: Go to Name/Age setup
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } else {
      // Returning user logic: Go directly to Dashboard data loading
      _loadDataAndLaunch();
    }
  }

  Future<void> _loadDataAndLaunch() async {
    setState(() => isLoading = true);
    try {
      final List<dynamic> result = await platform.invokeMethod("getUsageStats");
      int sum = 0;
      for (var app in result) {
        sum += (app["time"] as num).toInt();
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Dashboard(apps: result, totalTime: sum),
          ),
        );
      }
    } catch (e) {
      debugPrint("Data Loading Error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f172a),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff1e1b4b), Color(0xff0f172a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.blueAccent)
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_update_good, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 30),
                const Text(
                  "Permission Required",
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                const Text(
                  "To track usage and protect your device, AppOrbit needs 'Usage Access' permission from your system settings.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 10,
                  ),
                  onPressed: () => platform.invokeMethod('openSettings'),
                  child: const Text("Grant Permission", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}