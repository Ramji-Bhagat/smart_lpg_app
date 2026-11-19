import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/alert_service.dart';
import '../services/realtime_service.dart';
import 'analytics_page.dart';
import 'alerts_page.dart';
import 'history_page.dart';
import 'new_refill_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // 🔥 Pages linked to bottom nav tabs
  final List<Widget> _pages = [
    const HomeContent(),
    const AnalyticsPage(),
    const AlertsPage(),
    const HistoryPage(),
    const SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),

      // ───────────── BOTTOM NAV ─────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF3A7BD5),
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),

      // ✅ Switch between pages via IndexedStack
      // IndexedStack keeps all pages alive (no reload on tab switch)
      body: IndexedStack(index: _selectedIndex, children: _pages),
    );
  }
}

// ─────────────────────────────────────────────────────
// 🏠 HOME CONTENT — extracted as separate widget
// so IndexedStack can manage it cleanly
// ─────────────────────────────────────────────────────
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final RealtimeService _service = RealtimeService();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _service.saveTodayUsageToFirestore());
    AlertService().startAlertListener();
  }

  // 🔥 Fetch name from Firestore
  Stream<String> getUserName() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value('User');
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 'User';
          return doc.data()?['name'] ?? 'User';
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ───────────── HEADER ─────────────
        StreamBuilder<String>(
          stream: getUserName(),
          builder: (context, snapshot) {
            final name = snapshot.data ?? 'User';
            return Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A56C4), Color(0xFF3A7BD5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome back,",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // 🔔 Notification Bell with badge
                  InkWell(
  borderRadius: BorderRadius.circular(12),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertsPage(), // your target page
      ),
    );
  },
  child: Stack(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.notifications_outlined,
          color: Colors.white,
          size: 22,
        ),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ],
  ),
)
                ],
              ),
            );
          },
        ),

        // ───────────── SCROLLABLE BODY ─────────────
        Expanded(
          child: StreamBuilder<Map<dynamic, dynamic>>(
            stream: _service.getLatestData(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!;

              // ✅ tare weight subtracted (cylinder body = 18kg)
              double weight = ((data['weight'] ?? 0).toDouble() - 18).clamp(
                0.0,
                14.2,
              );
              double capacity = 14.2;
              double percent = ((weight / capacity) * 100).clamp(0.0, 100.0);
              bool gasDetected = data['gas_detected'] ?? false;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  // ── GAS LEVEL CARD ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  "Current Gas Level",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "LPG Cylinder #1",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF3FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_fire_department_outlined,
                                color: Color(0xFF3A7BD5),
                                size: 20,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 🔵 Circular Progress
                        Center(
                          child: SizedBox(
                            width: 150,
                            height: 150,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: CircularProgressIndicator(
                                    value: percent / 100,
                                    strokeWidth: 12,
                                    backgroundColor: Colors.grey.shade100,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF2DCB73),
                                        ),
                                    strokeCap: StrokeCap.round,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${percent.toStringAsFixed(0)}%",
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2DCB73),
                                      ),
                                    ),
                                    const Text(
                                      "Remaining",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Weight / Capacity row
                        Row(
                          children: [
                            Expanded(
                              child: _infoTile(
                                "Weight",
                                "${weight.toStringAsFixed(1)} kg",
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _infoTile("Capacity", "$capacity kg"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── PREDICTION CARD ──
                  StreamBuilder<Map<dynamic, dynamic>>(
                    stream: _service.getPrediction(),
                    builder: (context, predSnap) {
                      final pred = predSnap.data ?? {};
                      final refillDate =
                          pred['predicted_refill_date'] ?? 'Calculating...';
                      final daysLeft = pred['days_remaining'] ?? '--';
                      final avgFromPred = (pred['avg_daily'] ?? 0.0)
                          .toStringAsFixed(1);

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2FF7), Color(0xFFE040A0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2FF7).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "AI Prediction",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Refill Estimate",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Next refill on",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              refillDate,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.trending_down,
                                  color: Colors.white70,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$daysLeft days remaining",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  "$avgFromPred kg/day",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── TODAY'S USAGE + AVG DAILY ──
                  // ✅ Both now use realtime_service streams
                  Row(
                    children: [
                      // 🔵 Today's Usage — from history data
                      Expanded(
                        child: StreamBuilder<double>(
                          stream: _service.getTodayUsage(),
                          builder: (context, snap) {
                            final todayUsage = snap.data ?? 0.0;
                            return _usageTile(
                              icon: Icons.water_drop_outlined,
                              iconColor: const Color(0xFF3A7BD5),
                              iconBg: const Color(0xFFEEF3FF),
                              label: "Today's Usage",
                              value: "${todayUsage.toStringAsFixed(2)} kg",
                              sub: todayUsage > 0
                                  ? "Live from sensor"
                                  : "No data yet",
                              subColor: todayUsage > 0
                                  ? Colors.green
                                  : Colors.grey,
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 12),

                      // 🟠 Avg Daily — smart: uses actual days not hardcoded 7
                      Expanded(
                        child: StreamBuilder<Map<String, dynamic>>(
                          stream: _service.getAvgDailyUsageWithMeta(),
                          builder: (context, snap) {
                            final avg = snap.data?['avg'] ?? 0.0;
                            final days = snap.data?['days'] ?? 0;

                            final subLabel = days == 0
                                ? "No data yet"
                                : days == 1
                                ? "Based on today"
                                : "Last $days days"; // ✅ accurate label

                            return _usageTile(
                              icon: Icons.show_chart_rounded,
                              iconColor: Colors.orange,
                              iconBg: const Color(0xFFFFF3E0),
                              label: "Avg. Daily",
                              value: days == 0 ? "-- kg" : "$avg kg",
                              sub: subLabel,
                              subColor: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── STATUS CARD ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: gasDetected
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: gasDetected
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: gasDetected
                                ? Colors.red.withOpacity(0.1)
                                : Colors.green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            gasDetected
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            color: gasDetected
                                ? Colors.red
                                : const Color(0xFF2DCB73),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gasDetected
                                    ? "Gas Leak Detected!"
                                    : "All Systems Normal",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: gasDetected
                                      ? Colors.red
                                      : const Color(0xFF1B5E20),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                gasDetected
                                    ? "Please check your cylinder immediately"
                                    : "No gas leaks detected",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: gasDetected
                                      ? Colors.red.shade300
                                      : Colors.green.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: gasDetected
                                ? Colors.red
                                : const Color(0xFF2DCB73),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── QUICK ACTIONS ──
                  const Text(
                    "Quick Actions",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Order Refill Now → opens NewRefillPage
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewRefillPage(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color(0xFF3A7BD5).withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "Order Refill Now",
                        style: TextStyle(
                          color: Color(0xFF3A7BD5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        "View Usage Report",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Helper: Info Tile ──
  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: Usage Tile ──
  Widget _usageTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    required String sub,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(fontSize: 11, color: subColor)),
        ],
      ),
    );
  }
}
