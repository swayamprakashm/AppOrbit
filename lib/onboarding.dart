import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _selectedDate;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _handleGoogleSignIn() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user != null) {
        setState(() {
          _nameController.text = user.displayName ?? "";
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', user.email);
        if (user.photoUrl != null) {
          await prefs.setString('user_photo', user.photoUrl!);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Signed in as ${user.email}"), backgroundColor: Colors.green),
          );
        }
      }
    } catch (error) {
      debugPrint("Google Sign-In Error: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sign-In failed. Please try again."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Color(0xff1e1b4b),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isNotEmpty && _selectedDate != null) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('user_name', _nameController.text.trim());
      await prefs.setString('user_dob', DateFormat('dd-MM-yyyy').format(_selectedDate!));
      await prefs.setBool('is_first_time', false);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PermissionPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide your name and date of birth"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f172a),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff1e1b4b), Color(0xff0f172a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 50, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              "Profile Setup",
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Google Sign In Button
            GestureDetector(
              onTap: _handleGoogleSignIn,
              child: GlassmorphicContainer(
                width: double.infinity, height: 55, borderRadius: 15, blur: 15, border: 1,
                alignment: Alignment.center, // ✨ FIX: Centers contents
                linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                borderGradient: LinearGradient(colors: [Colors.white24, Colors.white10]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ✨ FIX: Safer Google Icon fallback so it doesn't break if the URL fails
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.g_mobiledata, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 15),
                    const Text("Sign in with Google", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text("OR", style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 20),

            // Name Field
            _buildGlassField("Full Name", _nameController, Icons.person_outline),

            const SizedBox(height: 20),

            // Date of Birth Picker
            GestureDetector(
              onTap: () => _selectDate(context),
              child: GlassmorphicContainer(
                width: double.infinity, height: 65, borderRadius: 15, blur: 15, border: 1,
                alignment: Alignment.center, // ✨ FIX
                linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                borderGradient: LinearGradient(colors: [Colors.white24, Colors.white10]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blueAccent),
                      const SizedBox(width: 15),
                      Text(
                        _selectedDate == null
                            ? "Select Date of Birth"
                            : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
                        style: TextStyle(color: _selectedDate == null ? Colors.white38 : Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Continue Button
            GestureDetector(
              onTap: _saveProfile,
              child: GlassmorphicContainer(
                width: double.infinity, height: 55, borderRadius: 15, blur: 20, border: 1,
                alignment: Alignment.center, // ✨ FIX
                linearGradient: LinearGradient(colors: [Colors.blueAccent.withOpacity(0.6), Colors.blueAccent.withOpacity(0.2)]),
                borderGradient: LinearGradient(colors: [Colors.white30, Colors.white10]),
                child: const Text(
                  "Complete Setup",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassField(String hint, TextEditingController controller, IconData icon) {
    return GlassmorphicContainer(
      width: double.infinity, height: 65, borderRadius: 15, blur: 15, border: 1,
      alignment: Alignment.center, // ✨ FIX
      linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
      borderGradient: LinearGradient(colors: [Colors.white24, Colors.white10]),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }
}