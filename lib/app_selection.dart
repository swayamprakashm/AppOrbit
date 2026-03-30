import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  static const platform = MethodChannel('apporbit/usage');

  List<Map<String, dynamic>> allApps = [];
  List<Map<String, dynamic>> filteredApps = [];
  Set<String> selectedPackages = {};
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApps = prefs.getStringList('restricted_packages') ?? [];

    try {
      final List<dynamic> apps = await platform.invokeMethod('getInstalledApps');
      setState(() {
        allApps = apps.map((e) => Map<String, dynamic>.from(e)).toList();
        allApps.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
        filteredApps = allApps;
        selectedPackages = savedApps.toSet();
        isLoading = false;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to get apps: '${e.message}'.");
      setState(() => isLoading = false);
    }
  }

  void _filterApps(String query) {
    setState(() {
      filteredApps = allApps
          .where((app) => app['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('restricted_packages', selectedPackages.toList());

    await platform.invokeMethod('setRestrictedApps', {'apps': selectedPackages.toList()});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Restricted list updated! 🛡️"), backgroundColor: Colors.blueAccent),
      );
      Navigator.pop(context);
    }
  }

  // ✨ Shared Premium Container Style for App Tiles
  Widget _premiumAppTile(Widget child, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blueAccent.withOpacity(0.15) : const Color(0xff1e293b).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.blueAccent.withOpacity(0.6) : Colors.white.withOpacity(0.08),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  // ✨ Premium Glass Header (Replaces standard AppBar)
  Widget _buildGlassHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
          decoration: BoxDecoration(
            color: const Color(0xff0f172a).withOpacity(0.65),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      "Strict Mode Apps",
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              // 🔍 SEARCH BAR
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterApps,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search installed apps...",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                    prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _filterApps("");
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2, curve: Curves.easeOutCirc);
  }

  // ✨ Floating Save Button Pill
  Widget _buildFloatingSaveButton() {
    return Positioned(
      bottom: 30,
      left: 60,
      right: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: GestureDetector(
            onTap: _saveSelection,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 60,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent.withOpacity(0.8), Colors.purpleAccent.withOpacity(0.8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 8))
                  ]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    "Lock ${selectedPackages.length} Apps",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.5, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allows list to scroll behind header
      backgroundColor: const Color(0xff0f172a),
      body: Stack(
        children: [
          // 1. Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff1e1b4b), Color(0xff0f172a)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // 2. The App List
          isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              : filteredApps.isEmpty
              ? const Center(child: Text("No apps found", style: TextStyle(color: Colors.white54, fontSize: 16)))
              : ListView.builder(
            physics: const BouncingScrollPhysics(),
            // Padding accommodates the floating header and save pill
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 140,
                bottom: 120,
                left: 20,
                right: 20
            ),
            itemCount: filteredApps.length,
            itemBuilder: (context, index) {
              final app = filteredApps[index];
              final String pkg = app['packageName'];
              final bool isSelected = selectedPackages.contains(pkg);

              return _premiumAppTile(
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: _buildAppIcon(app['icon']),
                  ),
                  title: Text(app['name'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(pkg, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? Colors.blueAccent : Colors.transparent,
                      border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white38, width: 2),
                    ),
                    width: 24,
                    height: 24,
                    child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                  ),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedPackages.remove(pkg);
                      } else {
                        selectedPackages.add(pkg);
                      }
                    });
                  },
                ),
                isSelected,
              ).animate(key: ValueKey(app['packageName']))
                  .fadeIn(duration: 300.ms, delay: (index.clamp(0, 15) * 40).ms) // Clamped delay so long lists don't wait forever
                  .slideX(begin: 0.05, curve: Curves.easeOutQuad);
            },
          ),

          // 3. The Floating Glass Header (On Top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildGlassHeader(),
          ),

          // 4. The Floating Save Action Pill (On Top)
          _buildFloatingSaveButton(),
        ],
      ),
    );
  }

  Widget _buildAppIcon(String base64String) {
    if (base64String.isEmpty) {
      return const CircleAvatar(radius: 22, backgroundColor: Colors.white10, child: Icon(Icons.android, color: Colors.blueAccent, size: 20));
    }
    try {
      Uint8List bytes = base64Decode(base64String);
      return CircleAvatar(
        radius: 22,
        backgroundColor: Colors.transparent,
        backgroundImage: MemoryImage(bytes),
      );
    } catch (e) {
      return const CircleAvatar(radius: 22, backgroundColor: Colors.white10, child: Icon(Icons.android, color: Colors.blueAccent, size: 20));
    }
  }
}