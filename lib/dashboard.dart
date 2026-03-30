import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings.dart';
import 'security_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class Dashboard extends StatefulWidget {
  final List apps;
  final int totalTime;

  const Dashboard({super.key, required this.apps, required this.totalTime});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  static const platform = MethodChannel('apporbit/usage');

  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  Map<String, int> historicalData = {};
  Map<String, List<dynamic>> historicalAppsData = {};
  bool isWeeklyView = true;
  final int dailyGoalMinutes = 480;

  String userName = "User";
  String userDOB = "";
  String userPhoto = "";
  bool isGoogleSynced = false;

  // ✨ Rapid-tap protection flag
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    saveTodayUsage();
    loadHistoricalData();
    _listenForNativeTriggers();
  }

  void _listenForNativeTriggers() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "requestBiometricUnlock") {
        final String pendingPackage = call.arguments;
        bool isAuthenticated = await SecurityService.authenticateWithVisuals(
          context,
          reason: "Authorize 5 minutes of emergency use",
        );
        if (isAuthenticated) {
          await platform.invokeMethod('grantEmergencyAccess', {
            'package': pendingPackage,
            'minutes': 5,
          });
        }
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? "Swayam Prakash";
      userDOB = prefs.getString('user_dob') ?? "Not Set";
      userPhoto = prefs.getString('user_photo') ?? "";
      isGoogleSynced = prefs.getString('user_email') != null;
    });
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  void _showProfileDetails() {
    if (_isNavigating) return;
    _isNavigating = true;

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.2),
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.fastLinearToSlowEaseIn,
            reverseCurve: Curves.easeOutCubic,
          );
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18 * curve.value, sigmaY: 18 * curve.value),
            child: FadeTransition(opacity: curve, child: child),
          );
        },
        pageBuilder: (context, animation, secondaryAnimation) {
          final boxCurve = CurvedAnimation(
            parent: animation,
            curve: Curves.fastLinearToSlowEaseIn,
            reverseCurve: Curves.easeOutCubic,
          );
          return ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(boxCurve),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(boxCurve),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: _premiumContainer(
                    width: 320,
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Hero(
                          tag: 'profile_pic',
                          flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
                            return DefaultTextStyle(
                              style: DefaultTextStyle.of(toContext).style,
                              child: toContext.widget,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                              boxShadow: [
                                BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 30, spreadRadius: 5)
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.blueAccent.withOpacity(0.1),
                              backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                              child: userPhoto.isEmpty ? const Icon(Icons.person, size: 55, color: Colors.blueAccent) : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),
                        Text(
                          userName,
                          style: const TextStyle(color: Colors.white, fontSize: 26, letterSpacing: 0.5, fontWeight: FontWeight.w700),
                        ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCirc),
                        const SizedBox(height: 6),
                        Text(
                          "Born: $userDOB",
                          style: const TextStyle(color: Colors.white60, fontSize: 15),
                        ).animate().fadeIn(delay: 250.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCirc),
                        const SizedBox(height: 35),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => Navigator.maybePop(context), // ✨ Safely pop
                            child: const Text("Done", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ).animate().fadeIn(delay: 350.ms, duration: 400.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).then((_) => _isNavigating = false); // ✨ Reset flag when closed
  }

  Future<void> saveTodayUsage() async {
    final prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toString().substring(0, 10);
    await prefs.setInt("day_$today", widget.totalTime);
    await prefs.setString("apps_$today", jsonEncode(widget.apps));
  }

  Future<void> loadHistoricalData() async {
    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    for (int i = 0; i < 28; i++) {
      DateTime day = now.subtract(Duration(days: i));
      String dateStr = day.toString().substring(0, 10);
      historicalData["day_$dateStr"] = prefs.getInt("day_$dateStr") ?? 0;
      String? appsJson = prefs.getString("apps_$dateStr");
      if (appsJson != null) historicalAppsData["day_$dateStr"] = jsonDecode(appsJson);
    }
    if (mounted) setState(() {});
  }

  String formatTime(int ms) {
    int minutes = (ms / 60000).floor();
    int hours = (minutes / 60).floor();
    minutes = minutes % 60;
    return hours > 0 ? "${hours}h ${minutes}m" : "${minutes}m";
  }

  Widget _buildAppIcon(String base64String, {double radius = 25}) {
    try {
      Uint8List imageBytes = base64Decode(base64String);
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(imageBytes), backgroundColor: Colors.transparent);
    } catch (e) {
      return CircleAvatar(radius: radius, backgroundColor: Colors.white10, child: Icon(Icons.android, color: Colors.blueAccent, size: radius));
    }
  }

  double _calculateMaxY() {
    double maxVal = 8.0;
    DateTime now = DateTime.now();
    if (isWeeklyView) {
      for (int i = 0; i < 7; i++) {
        String key = "day_${now.subtract(Duration(days: i)).toString().substring(0, 10)}";
        double hours = ((historicalData[key] ?? 0) / 60000) / 60;
        if (hours > maxVal) maxVal = hours;
      }
    }
    return maxVal + 1.5;
  }

  List<BarChartGroupData> getWeeklyBarGroups(double dynamicMaxY) {
    List<BarChartGroupData> bars = [];
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      String key = "day_${now.subtract(Duration(days: i)).toString().substring(0, 10)}";
      double totalHours = ((historicalData[key] ?? 0) / 60000) / 60;
      List<dynamic> dayApps = List.from(historicalAppsData[key] ?? [])..sort((a, b) => b["time"].compareTo(a["time"]));

      double a1 = dayApps.isNotEmpty ? (dayApps[0]["time"] / 60000) / 60 : 0;
      double a2 = dayApps.length > 1 ? (dayApps[1]["time"] / 60000) / 60 : 0;
      double a3 = dayApps.length > 2 ? (dayApps[2]["time"] / 60000) / 60 : 0;
      double other = (totalHours - (a1 + a2 + a3)).clamp(0, 100);

      List<BarChartRodStackItem> items = [];
      double curY = 0, gap = 0.1;
      if (a1 > 0) {
        items.add(BarChartRodStackItem(curY, curY + a1, Colors.blueAccent));
        curY += a1 + gap;
      }
      if (a2 > 0) {
        items.add(BarChartRodStackItem(curY, curY + a2, Colors.purpleAccent));
        curY += a2 + gap;
      }
      if (a3 > 0) {
        items.add(BarChartRodStackItem(curY, curY + a3, Colors.pinkAccent));
        curY += a3 + gap;
      }
      if (other > 0) {
        items.add(BarChartRodStackItem(curY, curY + other, Colors.blueGrey.withOpacity(0.5)));
      }

      bars.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: totalHours > 0 ? totalHours + (gap * 3) : 0.1,
              width: 18,
              borderRadius: BorderRadius.circular(6),
              rodStackItems: items.isNotEmpty ? items : null,
              color: items.isEmpty ? Colors.white10 : Colors.transparent,
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: dynamicMaxY,
                color: Colors.white.withOpacity(0.04),
              ),
            )
          ],
        ),
      );
    }
    return bars;
  }

  List<FlSpot> getMonthlySpots() {
    List<FlSpot> spots = [];
    DateTime now = DateTime.now();
    for (int week = 3; week >= 0; week--) {
      int weeklyTotalMs = 0;
      for (int d = 0; d < 7; d++) {
        weeklyTotalMs += historicalData["day_${now.subtract(Duration(days: (week * 7) + d)).toString().substring(0, 10)}"] ?? 0;
      }
      spots.add(FlSpot((3 - week).toDouble(), ((weeklyTotalMs / 7) / 60000) / 60));
    }
    return spots;
  }

  Widget _buildChart() {
    double dynamicMaxY = _calculateMaxY();
    double axisInterval = dynamicMaxY > 12 ? 4 : 2;

    Widget leftTitleWidgets(double value, TitleMeta meta) {
      if (value == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Text(
          "${value.toInt()}h",
          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right,
        ),
      );
    }

    return isWeeklyView
        ? BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: dynamicMaxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueAccent.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
              "${(rod.toY - 0.3).clamp(0, 100).toStringAsFixed(1)}h",
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    days[value.toInt() % 7],
                    style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: axisInterval,
              getTitlesWidget: leftTitleWidgets,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: axisInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.03),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: getWeeklyBarGroups(dynamicMaxY),
      ),
    )
        : LineChart(
      LineChartData(
        minX: 0,
        maxX: 3,
        minY: 0,
        maxY: dynamicMaxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (group) => Colors.purpleAccent.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  "${spot.y.toStringAsFixed(1)}h avg",
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text(
                  'W${value.toInt() + 1}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: axisInterval,
              getTitlesWidget: leftTitleWidgets,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: axisInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: getMonthlySpots(),
            isCurved: true,
            curveSmoothness: 0.35,
            gradient: const LinearGradient(colors: [Colors.cyanAccent, Colors.purpleAccent]),
            barWidth: 5,
            isStrokeCapRound: true,
            shadow: const Shadow(color: Colors.purpleAccent, blurRadius: 12, offset: Offset(0, 4)),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 6,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: Colors.purpleAccent,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [Colors.purpleAccent.withOpacity(0.4), Colors.cyanAccent.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _premiumContainer({required Widget child, double? width, double? height, EdgeInsetsGeometry? padding}) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xff1e293b).withOpacity(0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: child,
    );
  }

  Widget _buildPremiumToggle() {
    return Container(
      width: 180,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: isWeeklyView ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: isWeeklyView ? Colors.blueAccent : Colors.purpleAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (isWeeklyView ? Colors.blueAccent : Colors.purpleAccent).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => isWeeklyView = true),
                  child: Center(
                    child: Text(
                      "Weekly",
                      style: TextStyle(
                        color: isWeeklyView ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => isWeeklyView = false),
                  child: Center(
                    child: Text(
                      "Monthly",
                      style: TextStyle(
                        color: !isWeeklyView ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 24, left: 40, right: 40),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 75,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xff1e293b).withOpacity(0.4),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(Icons.dashboard_rounded, "Dashboard", 0),
                _navItem(Icons.settings_rounded, "Settings", 1),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms).slideY(begin: 0.5, curve: Curves.easeOutCirc);
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastLinearToSlowEaseIn,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 20 : 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 1) : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white54, size: 26),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14))
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    double progress = (widget.totalTime / 60000) / dailyGoalMinutes;

    Map<String, dynamic> mergedAppsMap = {};
    for (var app in widget.apps) {
      String name = app["name"];
      if (mergedAppsMap.containsKey(name)) {
        mergedAppsMap[name]["time"] += app["time"];
      } else {
        mergedAppsMap[name] = Map<String, dynamic>.from(app);
      }
    }

    final List sortedApps = mergedAppsMap.values.toList()
      ..sort((a, b) => b["time"].compareTo(a["time"]));
    final displayApps = sortedApps.take(5).toList();

    return Stack(
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
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 120.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getGreeting(), style: const TextStyle(color: Colors.white70, fontSize: 16)),
                          Text(
                            userName,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: _showProfileDetails,
                      child: Hero(
                        tag: 'profile_pic',
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                            child: userPhoto.isEmpty ? const Icon(Icons.person, color: Colors.blueAccent, size: 30) : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),
                const SizedBox(height: 30),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 50, spreadRadius: 5)
                            ],
                          ),
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.1, 1.1),
                          duration: 2000.ms,
                          curve: Curves.easeInOut,
                        ),
                        SizedBox(
                          height: 220,
                          width: 220,
                          child: CircularProgressIndicator(
                            value: progress.clamp(0, 1),
                            strokeWidth: 16,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            color: Colors.blueAccent,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Total Today",
                              style: TextStyle(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1.1),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              formatTime(widget.totalTime),
                              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
                          begin: const Offset(0.98, 0.98),
                          end: const Offset(1.02, 1.02),
                          duration: 2000.ms,
                          curve: Curves.easeInOut,
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Top Apps", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        if (_isNavigating) return;
                        _isNavigating = true; // ✨ Protection lock
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AllAppsScreen(
                              apps: sortedApps,
                              maxTime: sortedApps.isNotEmpty ? sortedApps.first["time"].toDouble() : 1.0,
                              formatTime: formatTime,
                              buildIcon: _buildAppIcon,
                            ),
                          ),
                        ).then((_) => _isNavigating = false); // ✨ Unlock when back
                      },
                      child: const Text("View All", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: displayApps.length,
                    itemBuilder: (context, index) {
                      final app = displayApps[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: _premiumContainer(
                          width: 105,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
                                ),
                                child: _buildAppIcon(app["icon"], radius: 22),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  app["name"],
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatTime(app["time"]),
                                style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: 500 + (index * 100))).slideX(begin: 0.2);
                    },
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Analytics", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    _buildPremiumToggle(),
                  ],
                ).animate().fadeIn(delay: 700.ms),
                const SizedBox(height: 20),
                _premiumContainer(
                  width: double.infinity,
                  height: 300,
                  child: Column(
                    children: [
                      if (isWeeklyView && displayApps.length >= 3)
                        Padding(
                          padding: const EdgeInsets.only(top: 20, right: 24, left: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildLegendItem(Colors.blueAccent, displayApps[0]["name"]),
                              _buildLegendItem(Colors.purpleAccent, displayApps[1]["name"]),
                              _buildLegendItem(Colors.pinkAccent, displayApps[2]["name"]),
                            ],
                          ),
                        ).animate().fadeIn(delay: 800.ms),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: isWeeklyView ? 25 : 35, right: 24, left: 10, bottom: 20),
                          child: _buildChart(),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 60,
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xff0f172a),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          _buildDashboardContent(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }
}

class AllAppsScreen extends StatelessWidget {
  final List apps;
  final double maxTime;
  final Function(int) formatTime;
  final Widget Function(String, {double radius}) buildIcon;

  const AllAppsScreen({
    super.key,
    required this.apps,
    required this.maxTime,
    required this.formatTime,
    required this.buildIcon,
  });

  Widget _premiumContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff1e293b).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0f172a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("All Activity", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        // ✨ FIXED: Safe back button override
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff1e1b4b), Color(0xff0f172a)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: apps.length,
          itemBuilder: (context, index) {
            final app = apps[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _premiumContainer(
                child: Row(
                  children: [
                    buildIcon(app["icon"], radius: 20),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app["name"],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: (app["time"] / maxTime).clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 4)
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      formatTime(app["time"]),
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1);
          },
        ),
      ),
    );
  }
}