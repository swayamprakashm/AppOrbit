import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'app_selection.dart';
import 'security_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isLockdownEnabled = false;
  bool isUninstallProtectionEnabled = false;
  bool isSyncing = false;
  String? savedPin;

  static const platform = MethodChannel('apporbit/usage');
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedPin = prefs.getString('guardian_pin');
      isLockdownEnabled = prefs.getBool('lockdown_enabled') ?? false;
      isUninstallProtectionEnabled = prefs.getBool('uninstall_protection') ?? false;
    });
  }

  Future<bool> _authenticateAction(String reason) async {
    bool isAuth = await SecurityService.authenticateWithVisuals(context, reason: reason);
    if (isAuth) return true;

    if (savedPin != null) {
      String? enteredPin = await _getPinInput(
          title: "Verify Identity\nEnter Guardian PIN",
          buttonText: "Unlock"
      );

      if (enteredPin == savedPin) {
        return true;
      } else if (enteredPin != null) {
        _showMessage("Incorrect Guardian PIN", Colors.redAccent);
      }
    } else {
      _showMessage("Authentication failed. Please set a Guardian PIN.", Colors.orangeAccent);
    }
    return false;
  }

  Future<void> _handlePinChange() async {
    if (savedPin == null) {
      String? newPin = await _getPinInput(title: "Create Guardian PIN", buttonText: "Save PIN");
      if (newPin != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('guardian_pin', newPin);
        setState(() => savedPin = newPin);
        _showMessage("Guardian PIN created successfully! 🔒", Colors.green);
      }
    } else {
      String? oldPin = await _getPinInput(title: "Enter Current PIN", buttonText: "Verify");
      if (oldPin == null) return;

      if (oldPin != savedPin) {
        _showMessage("Incorrect Current PIN", Colors.redAccent);
        return;
      }

      String? newPin = await _getPinInput(title: "Enter New Guardian PIN", buttonText: "Save New PIN");
      if (newPin != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('guardian_pin', newPin);
        setState(() => savedPin = newPin);
        _showMessage("Guardian PIN updated successfully! 🔒", Colors.green);
      }
    }
  }

  Future<void> _openAppSelection() async {
    if (savedPin == null) {
      _showMessage("Tip: Set a Guardian PIN to secure this list from bypasses.", Colors.blueAccent);
      Navigator.push(context, MaterialPageRoute(builder: (c) => const AppSelectionScreen()));
      return;
    }

    String? enteredPin = await _getPinInput(
        title: "Strict Mode Security\nEnter Guardian PIN to access",
        buttonText: "Unlock"
    );

    if (enteredPin == savedPin) {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (c) => const AppSelectionScreen()));
    } else if (enteredPin != null) {
      _showMessage("Incorrect Guardian PIN", Colors.redAccent);
    }
  }

  Future<void> _toggleLockdown(bool enable) async {
    if (enable && savedPin == null) {
      _showMessage("Please set a Guardian PIN first!", Colors.orangeAccent);
      return;
    }

    bool isAuth = await _authenticateAction("Authorize to ${enable ? 'enable' : 'disable'} Strict Lockdown Mode");
    if (!isAuth) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (enable) {
        final bool success = await platform.invokeMethod('startLockdown');
        if (success) {
          setState(() => isLockdownEnabled = true);
          await prefs.setBool('lockdown_enabled', true);
        }
      } else {
        await platform.invokeMethod('stopLockdown');
        setState(() => isLockdownEnabled = false);
        await prefs.setBool('lockdown_enabled', false);
      }
    } on PlatformException catch (e) {
      debugPrint("Error: '${e.message}'.");
    }
  }

  Future<void> _toggleUninstallProtection(bool enable) async {
    if (enable && savedPin == null) {
      _showMessage("Please set a Guardian PIN first!", Colors.orangeAccent);
      return;
    }

    bool isAuth = await _authenticateAction("Security check to change Uninstall Protection");
    if (!isAuth) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (enable) {
        final bool success = await platform.invokeMethod('enableUninstallProtection');
        if (success) {
          setState(() => isUninstallProtectionEnabled = true);
          await prefs.setBool('uninstall_protection', true);
        }
      } else {
        await platform.invokeMethod('disableUninstallProtection');
        setState(() => isUninstallProtectionEnabled = false);
        await prefs.setBool('uninstall_protection', false);
      }
    } on PlatformException catch (e) {
      debugPrint("Error: '${e.message}'.");
    }
  }

  Future<bool> _signInWithGoogleAndFirebase() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', userCredential.user!.email ?? "");
        if (userCredential.user!.photoURL != null) {
          await prefs.setString('user_photo', userCredential.user!.photoURL!);
        }
        return true;
      }
    } catch (e) { debugPrint("Login Error: $e"); }
    return false;
  }

  Future<bool> _showLoginDialog() async {
    bool isSuccess = false;
    bool isLoggingIn = false;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: Material(
            color: Colors.transparent,
            child: GlassmorphicContainer(
              width: 320, height: 250, borderRadius: 20, blur: 15, border: 1, alignment: Alignment.center,
              linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]),
              borderGradient: LinearGradient(colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.1)]),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_sync, color: Colors.blueAccent, size: 40),
                    const SizedBox(height: 15),
                    const Text("Cloud Sync Required", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text("Sign in with Google to connect and backup your data.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    isLoggingIn ? const CircularProgressIndicator(color: Colors.blueAccent) : GestureDetector(
                      onTap: () async {
                        setDialogState(() => isLoggingIn = true);
                        bool success = await _signInWithGoogleAndFirebase();
                        if (success) {
                          isSuccess = true;
                          if (context.mounted) Navigator.maybePop(context);
                        } else {
                          setDialogState(() => isLoggingIn = false);
                          _showMessage("Sign-in failed.", Colors.redAccent);
                        }
                      },
                      child: Container(
                        height: 50, decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blueAccent.withOpacity(0.5))),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.g_mobiledata, color: Colors.white), SizedBox(width: 10), Text("Sign in with Google", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return isSuccess;
  }

  Future<void> _syncDataToFirebase() async {
    setState(() => isSyncing = true);
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isSyncing = false);
        bool loggedIn = await _showLoginDialog();
        if (!loggedIn) return;
        user = FirebaseAuth.instance.currentUser;
      }
      final prefs = await SharedPreferences.getInstance();
      String today = DateTime.now().toString().substring(0, 10);
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('daily_usage').doc(today).set({
        'date': today,
        'total_time_ms': prefs.getInt("day_$today") ?? 0,
        'user_name': prefs.getString('user_name') ?? "Unknown",
        'last_synced': FieldValue.serverTimestamp(),
      });
      _showMessage("Data synced successfully! ☁️", Colors.green);
    } catch (e) { _showMessage("Sync failed.", Colors.redAccent); }
    finally { if (mounted) setState(() => isSyncing = false); }
  }

  Future<String?> _getPinInput({required String title, required String buttonText}) async {
    String? enteredPin;
    bool isSuccess = false;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: GlassmorphicContainer(
            width: 300, height: 250, borderRadius: 20, blur: 15, border: 1, alignment: Alignment.center,
            linearGradient: LinearGradient(colors: [Colors.white12, Colors.white10]),
            borderGradient: LinearGradient(colors: [Colors.white30, Colors.white10]),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextField(
                    autofocus: true,
                    obscureText: true, maxLength: 4, textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(counterText: "", filled: true, fillColor: Colors.black26),
                    onChanged: (v) => enteredPin = v,
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(onPressed: () => Navigator.maybePop(context), child: const Text("Cancel")),
                      ElevatedButton(
                        onPressed: () {
                          if (enteredPin != null && enteredPin!.length == 4) {
                            isSuccess = true;
                            Navigator.maybePop(context);
                          }
                        },
                        child: Text(buttonText),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return isSuccess ? enteredPin : null;
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Widget _premiumContainer({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xff1e293b).withOpacity(0.6),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 6))
          ]
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(bottom: 15, top: 10), child: Text(title, style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)));

  Widget _buildPremiumTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: GestureDetector(onTap: onTap, child: _premiumContainer(padding: const EdgeInsets.all(10), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.blueAccent)), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis,), trailing: const Icon(Icons.chevron_right, color: Colors.white54)))));
  }

  Widget _buildPremiumSwitchTile({required IconData icon, required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: _premiumContainer(padding: const EdgeInsets.all(10), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0), leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.blueAccent)), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)), subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis,), trailing: Switch(value: value, onChanged: onChanged, activeColor: Colors.blueAccent))));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xff1e1b4b), Color(0xff0f172a)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 120.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Settings & Controls", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))
                    .animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

                const SizedBox(height: 30),

                _buildSectionHeader("Parental Controls").animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                _buildPremiumTile(
                  icon: savedPin == null ? Icons.lock_open : Icons.lock,
                  title: savedPin == null ? "Set Guardian PIN" : "Change Guardian PIN",
                  subtitle: "Secure backup for biometrics",
                  onTap: () { _handlePinChange(); },
                ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),

                _buildPremiumTile(
                  icon: Icons.checklist_rtl,
                  title: "Custom Strict Mode Apps",
                  subtitle: "Manage restricted list",
                  onTap: () { _openAppSelection(); },
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),

                _buildPremiumSwitchTile(
                  icon: Icons.block,
                  title: "Strict Lockdown",
                  subtitle: "Bio-auth required to toggle",
                  value: isLockdownEnabled,
                  onChanged: (v) { _toggleLockdown(v); },
                ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),

                _buildPremiumSwitchTile(
                  icon: Icons.phonelink_erase,
                  title: "Uninstall Protection",
                  subtitle: "Guard the app from removal",
                  value: isUninstallProtectionEnabled,
                  onChanged: (v) { _toggleUninstallProtection(v); },
                ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1),

                const SizedBox(height: 30),
                _buildSectionHeader("Account & Data").animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),

                _buildPremiumTile(
                  icon: Icons.cloud_sync,
                  title: isSyncing ? "Syncing..." : "Sync with Firebase",
                  subtitle: "Cloud backup for your stats",
                  onTap: () { if (!isSyncing) _syncDataToFirebase(); },
                ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.1),

                const SizedBox(height: 30),
                _buildSectionHeader("System").animate().fadeIn(delay: 900.ms).slideY(begin: 0.2),

                _buildPremiumTile(
                  icon: Icons.groups_rounded,
                  title: "Meet the Team",
                  subtitle: "The creators behind AppOrbit",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamScreen()));
                  },
                ).animate().fadeIn(delay: 1000.ms).slideX(begin: 0.1),

                _buildPremiumTile(
                  icon: Icons.info_outline_rounded,
                  title: "About AppOrbit",
                  subtitle: "Our mission, privacy & terms",
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutAppScreen()));
                  },
                ).animate().fadeIn(delay: 1100.ms).slideX(begin: 0.1),

                _buildPremiumTile(
                  icon: Icons.verified_user_rounded,
                  title: "App Version 1.0.0",
                  subtitle: "Developed by Swayam Prakash Macharla '",

                  onTap: () {
                    _showMessage("You are running the latest version of AppOrbit!", Colors.blueAccent);
                  },
                ).animate().fadeIn(delay: 1200.ms).slideX(begin: 0.1),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- Team Screen ---

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {

  Widget _buildTeamMemberCard({
    required String name,
    required String rollNo,
    required String bio,
    required String branch,
    required String imageAsset,
    required int index,
  }) {
    return _PremiumInkWellCard(
      onTap: () { _showMessage("Connected with $name!", Colors.blueAccent); },
      child: Column(
        children: [
          // 🖼️ SQUARED IMAGE HEADER - FULLY UNCROPPED
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                imageAsset,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: const Color(0xff0f172a),
                    child: const Center(
                      child: Icon(Icons.person, color: Colors.white24, size: 80),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 📛 NAME
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),

          // 💬 BIO SECTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5, fontStyle: FontStyle.italic),
            ),
          ),

          const SizedBox(height: 16),

          // 💻 BRANCH
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.terminal_rounded, size: 14, color: Colors.cyanAccent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  branch,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 🆔 ROLL NUMBER PILL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
            ),
            child: Text(
              "ID: $rollNo",
              style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 1.2, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 200 + (index * 150))).slideY(begin: 0.1, curve: Curves.easeOutCirc);
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f172a),
      body: Stack(
        children: [
          // Static, clean gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff1e1b4b), Color(0xff0f172a)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () { Navigator.maybePop(context); } // ✨ Safely pop
                      ),
                      const Text(
                        "AppOrbit Creators",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const Center(
                        child: Text(
                          "Meet the team behind the code.",
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                      ).animate().fadeIn().slideY(begin: 0.2),

                      const SizedBox(height: 30),

                      _buildTeamMemberCard(
                        name: "Vasala Akshaya",
                        bio: "Passionate about crafting intuitive, beautiful user experiences and ensuring pixel-perfect designs.",
                        rollNo: "23AG1A05C6",
                        branch: "Computer Science & Engineering",
                        imageAsset: 'assets/akshaya.png',
                        index: 0,
                      ),

                      _buildTeamMemberCard(
                        name: "Devaruppala Sairam",
                        bio: "Dedicated to building robust backend architectures and ensuring high-performance data flow.",
                        rollNo: "23AG1A0584",
                        branch: "Computer Science & Engineering",
                        imageAsset: 'assets/sairam.png',
                        index: 1,
                      ),

                      _buildTeamMemberCard(
                        name: "Macharla Swayam Prakash",
                        bio: "Focused on combining cutting-edge frameworks with secure, scalable application logic.",
                        rollNo: "24AG5A0510",
                        branch: "Computer Science & Engineering",
                        imageAsset: 'assets/swayam.png',
                        index: 2,
                      ),

                      const SizedBox(height: 40),

                      // ✨ Static Footer
                      const Center(
                        child: Text("Swaash Technologies", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ).animate().fadeIn(delay: 800.ms),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ✨ Safe Reactive Card
class _PremiumInkWellCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PremiumInkWellCard({required this.child, required this.onTap});

  @override
  State<_PremiumInkWellCard> createState() => _PremiumInkWellCardState();
}

class _PremiumInkWellCardState extends State<_PremiumInkWellCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (mounted) setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapCancel() {
    if (mounted) setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    if (mounted) setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapCancel: _onTapCancel,
      onTapUp: _onTapUp,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(bottom: 25),
                decoration: BoxDecoration(
                  color: const Color(0xff1e293b).withOpacity(_isPressed ? 0.75 : 0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(_isPressed ? 0.12 : 0.08)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- About AppOrbit Screen ---

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f172a),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff1e1b4b), Color(0xff0f172a)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                          onPressed: () { Navigator.maybePop(context); } // ✨ Safely pop
                      ),
                      const Text(
                        "Legal & About",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                                  boxShadow: [
                                    BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)
                                  ]
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/app_logo.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Padding(
                                      padding: EdgeInsets.all(15.0),
                                      child: Icon(Icons.rocket_launch_rounded, size: 50, color: Colors.blueAccent),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            const Text("AppOrbit", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                            const Text("v1.0.0 Stable Build", style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ).animate().fadeIn().scale(),

                      const SizedBox(height: 40),

                      _buildInfoCard(
                        icon: Icons.track_changes_rounded,
                        title: "Our Mission",
                        content: "In a world of constant digital noise, AppOrbit serves as your personal guardian. We built this app to help you reclaim your focus, break away from endless scrolling, and build healthier digital habits by enforcing strict, biometric-secured boundaries.",
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),

                      const SizedBox(height: 15),

                      _buildInfoCard(
                        icon: Icons.memory_rounded,
                        title: "How It Works",
                        content: "AppOrbit runs a highly optimized background service that monitors your active screen. When a restricted app is launched, our native Android overlay instantly locks the screen. The only way to bypass it is through a strict 5-minute emergency override secured by your fingerprint or Guardian PIN.",
                      ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1),

                      const SizedBox(height: 15),

                      _buildInfoCard(
                        icon: Icons.privacy_tip_rounded,
                        title: "Privacy Policy",
                        content: "• Data Localization: Your usage statistics and restricted app lists never leave your device.\n\n"
                            "• Biometric Security: We utilize Android's system-level BiometricPrompt. We never see, store, or transmit your actual fingerprint or face data.\n\n"
                            "• Cloud Sync: If enabled, only your basic 'Total Usage Time' is securely backed up to Firebase.",
                      ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),

                      const SizedBox(height: 15),

                      _buildInfoCard(
                        icon: Icons.gavel_rounded,
                        title: "Terms & Conditions",
                        content: "By using AppOrbit, you grant the app permission to monitor foreground applications. We are not responsible for missed notifications or restricted access during active focus sessions.\n\n"
                            "The 'Uninstall Protection' feature utilizes Device Administrator privileges to prevent unauthorized removal.",
                      ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),

                      const SizedBox(height: 15),

                      _buildInfoCard(
                        icon: Icons.security_rounded,
                        title: "Required Permissions",
                        content: "• Usage Access: To detect when a restricted app is opened.\n\n"
                            "• Display Over Other Apps: To draw the lockdown screen over distractions.\n\n"
                            "• Device Admin: To prevent someone from simply deleting AppOrbit to bypass the lock.",
                      ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1),

                      const SizedBox(height: 15),

                      _buildInfoCard(
                        icon: Icons.support_agent_rounded,
                        title: "Support & Feedback",
                        content: "Encountered a bug or have a feature request? We are constantly working to improve AppOrbit.\n\n"
                            "Contact us via email for support regarding Guardian PIN resets, sync issues, or general feedback.",
                      ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.1),

                      const SizedBox(height: 40),

                      const Center(
                        child: Text(
                          "Developed by Swayam Prakash Macharla\n© 2026 AppOrbit - Swaash Technologies",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.5),
                        ),
                      ).animate().fadeIn(delay: 800.ms),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String title, required String content}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: const Color(0xff1e293b).withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4)
            )
          ]
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      shape: BoxShape.circle
                  ),
                  child: Icon(icon, color: Colors.blueAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              content,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}