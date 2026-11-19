import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/realtime_service.dart';
import '../services/alert_service.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final RealtimeService _realtimeService = RealtimeService();
  final AlertService _alertService = AlertService();
  final String deviceId = "device_001";

  // ── Settings state (from Firestore) ──
  bool _pushNotifications = true;
  bool _gasLeakAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadAlertSettings();
  }

  Future<void> _loadAlertSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(deviceId)
          .collection('settings')
          .doc('preferences')
          .get();
      if (!mounted) return;
      if (!doc.exists) return;
      setState(() {
        _pushNotifications =
            doc.data()?['push_notifications'] as bool? ?? true;
        _gasLeakAlerts =
            doc.data()?['gas_leak_alerts'] as bool? ?? true;
      });
    } catch (e) {
      debugPrint('❌ loadAlertSettings error: $e');
    }
  }

  Future<void> _saveAlertSetting(String key, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(deviceId)
          .collection('settings')
          .doc('preferences')
          .set({key: value}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ saveAlertSetting error: $e');
    }
  }

  // ─────────────────────────────────────────
  // 🕐 Format relative time
  // ─────────────────────────────────────────
  String _relativeTime(int timestamp) {
    final now = DateTime.now();
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min ago";
    if (diff.inHours < 24) return "${diff.inHours} hours ago";
    if (diff.inDays == 1) return "Yesterday";
    if (diff.inDays < 7) return "${diff.inDays} days ago";
    return "${dt.day}/${dt.month}/${dt.year}";
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [

          // ── HEADER ──
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _alertService.getAlerts(),
            builder: (context, alertSnap) {
              // Count unread — alerts from last 24 hours
              final alerts = alertSnap.data ?? [];
              final now = DateTime.now();
              final unread = alerts.where((a) {
                final ts = a['timestamp'] as int? ?? 0;
                final dt =
                    DateTime.fromMillisecondsSinceEpoch(ts * 1000);
                return now.difference(dt).inHours < 24;
              }).length;

              return Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  right: 20,
                  bottom: 24,
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
                          "Alerts",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            "$unread unread",
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                    // Bell icon with badge
                    Stack(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            unread > 0
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_off_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        if (unread > 0)
                          Positioned(
                            top: 6,
                            right: 6,
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
                  ],
                ),
              );
            },
          ),

          // ── BODY ──
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // ✅ Combine all data streams
    return StreamBuilder<Map<dynamic, dynamic>>(
      stream: _realtimeService.getLatestData(),
      builder: (context, liveSnap) {
        return StreamBuilder<Map<dynamic, dynamic>>(
          stream: _realtimeService.getPrediction(),
          builder: (context, predSnap) {
            return StreamBuilder<Map<String, dynamic>>(
              // ✅ Get weekly change for usage alert
              stream: _realtimeService.getWeeklyChangePercent(),
              builder: (context, weeklySnap) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _alertService.getAlerts(),
                  builder: (context, alertSnap) {

                    // ── Extract live sensor data ──
                    final live = liveSnap.data ?? {};
                    final gasDetected =
                        live['gas_detected'] as bool? ?? false;
                    final lowWeight =
                        live['low_weight'] as bool? ?? false;
                    final rawWeight =
                        _toDouble(live['weight']);
                    final netWeight =
                        (rawWeight - 18.0).clamp(0.0, 14.2);
                    final gasPercent =
                        (netWeight / 14.2 * 100).clamp(0.0, 100.0);
                    final lastCheckedTs =
                        live['timestamp'] as int? ?? 0;

                    // ── Extract prediction data ──
                    final pred = predSnap.data ?? {};
                    final daysLeft =
                        pred['days_remaining'] ?? '--';
                    final refillDate =
                        pred['predicted_refill_date'] ?? '--';

                    // ── Extract weekly usage change ──
                    final weeklyData = weeklySnap.data;
                    final hasWeeklyData =
                        weeklyData?['hasData'] as bool? ?? false;
                    final weeklyChange =
                        _toDouble(weeklyData?['change']);
                    final weeklyDir =
                        weeklyData?['direction'] as String? ??
                            'none';

                    // ── Recent alerts from Firestore ──
                    final recentAlerts = alertSnap.data ?? [];

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [

                        // ── GAS LEAK MONITOR CARD ──
                        _gasMonitorCard(
                          gasDetected: gasDetected,
                          gasPercent: gasPercent,
                          lastCheckedTs: lastCheckedTs,
                        ),

                        const SizedBox(height: 16),

                        // ── ALERT SETTINGS ──
                        _sectionLabel("Alert Settings"),
                        _settingsCard(children: [
                          _toggleTile(
                            icon: Icons.notifications_outlined,
                            iconColor: const Color(0xFF3A7BD5),
                            iconBg: const Color(0xFFEEF3FF),
                            title: "Push Notifications",
                            subtitle:
                                "Get notified about important updates",
                            value: _pushNotifications,
                            onChanged: (val) {
                              setState(
                                  () => _pushNotifications = val);
                              _saveAlertSetting(
                                  'push_notifications', val);
                            },
                          ),
                          _divider(),
                          _toggleTile(
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.red,
                            iconBg: const Color(0xFFFFEBEE),
                            title: "Gas Leak Alerts",
                            subtitle: "Critical safety notifications",
                            value: _gasLeakAlerts,
                            onChanged: (val) {
                              setState(() => _gasLeakAlerts = val);
                              _saveAlertSetting(
                                  'gas_leak_alerts', val);
                            },
                          ),
                        ]),

                        const SizedBox(height: 16),

                        // ── RECENT ALERTS ──
                        _sectionLabel("Recent Alerts"),

                        // ✅ All Clear (shown when no gas leak)
                        if (!gasDetected)
                          _alertTile(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF2DCB73),
                            iconBg: const Color(0xFFE8F5E9),
                            borderColor: const Color(0xFF2DCB73)
                                .withOpacity(0.2),
                            title: "All Clear",
                            subtitle:
                                "No gas leaks detected. All systems operating normally.",
                            time: lastCheckedTs > 0
                                ? _relativeTime(lastCheckedTs)
                                : "Just now",
                            showDot: true,
                          ),

                        // ✅ Gas Leak Alert (shown when detected)
                        if (gasDetected)
                          _alertTile(
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.red,
                            iconBg: const Color(0xFFFFEBEE),
                            borderColor:
                                Colors.red.withOpacity(0.2),
                            title: "⚠️ Gas Leak Detected!",
                            subtitle:
                                "Immediately ventilate the area and check your cylinder connections.",
                            time: lastCheckedTs > 0
                                ? _relativeTime(lastCheckedTs)
                                : "Just now",
                            showDot: true,
                          ),

                        const SizedBox(height: 10),

                        // ✅ Low Gas Level (shown when low_weight true OR < 20%)
                        if (lowWeight || gasPercent < 20)
                          _alertTile(
                            icon: Icons.battery_alert_rounded,
                            iconColor: Colors.orange,
                            iconBg: const Color(0xFFFFF3E0),
                            borderColor:
                                Colors.orange.withOpacity(0.2),
                            title: "Low Gas Level",
                            // ✅ Real % from sensor
                            subtitle:
                                "Your gas level is at ${gasPercent.toStringAsFixed(0)}%. Consider ordering a refill soon.",
                            time: lastCheckedTs > 0
                                ? _relativeTime(lastCheckedTs)
                                : "Just now",
                            showDot: gasPercent < 20,
                          ),

                        if (lowWeight || gasPercent < 20)
                          const SizedBox(height: 10),

                        // ✅ Usage Update (from Firestore weekly change)
                        if (hasWeeklyData)
                          _alertTile(
                            icon: Icons.show_chart_rounded,
                            iconColor: const Color(0xFF3A7BD5),
                            iconBg: const Color(0xFFEEF3FF),
                            borderColor: const Color(0xFF3A7BD5)
                                .withOpacity(0.2),
                            title: "Usage Update",
                            // ✅ Real % change from Firestore
                            subtitle: weeklyDir == 'down'
                                ? "Your daily usage is ${weeklyChange.toStringAsFixed(1)}% lower than average. Great job!"
                                : weeklyDir == 'up'
                                    ? "Your daily usage is ${weeklyChange.toStringAsFixed(1)}% higher than average this week."
                                    : "Your usage is on par with last week.",
                            time: "This week",
                            showDot: false,
                          ),

                        if (hasWeeklyData) const SizedBox(height: 10),

                        // ✅ Refill Reminder (from prediction)
                        if (daysLeft != '--')
                          _alertTile(
                            icon: Icons.notifications_outlined,
                            iconColor: const Color(0xFF3A7BD5),
                            iconBg: const Color(0xFFEEF3FF),
                            borderColor: const Color(0xFF3A7BD5)
                                .withOpacity(0.2),
                            title: "Refill Reminder",
                            // ✅ Real days from prediction
                            subtitle:
                                "Based on AI prediction, you'll need a refill in $daysLeft days ($refillDate).",
                            time: "Yesterday",
                            showDot: false,
                          ),

                        if (daysLeft != '--')
                          const SizedBox(height: 10),

                        // ✅ Past alerts from Firestore (gas/low_weight events)
                        if (recentAlerts.isNotEmpty) ...[
                          _sectionLabel("Past Alerts"),
                          ...recentAlerts.take(5).map((alert) {
                            final isGas =
                                alert['gas_detected'] as bool? ??
                                    false;
                            final ts =
                                alert['timestamp'] as int? ?? 0;
                            final netW =
                                _toDouble(alert['net_weight']);
                            final pct =
                                (netW / 14.2 * 100).clamp(0, 100);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: _alertTile(
                                icon: isGas
                                    ? Icons.warning_amber_rounded
                                    : Icons.battery_alert_rounded,
                                iconColor: isGas
                                    ? Colors.red
                                    : Colors.orange,
                                iconBg: isGas
                                    ? const Color(0xFFFFEBEE)
                                    : const Color(0xFFFFF3E0),
                                borderColor: isGas
                                    ? Colors.red.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                title: isGas
                                    ? "Gas Leak Alert"
                                    : "Low Gas Alert",
                                subtitle: alert['message']
                                        as String? ??
                                    (isGas
                                        ? "Gas leak was detected."
                                        : "Gas dropped to ${pct.toStringAsFixed(0)}%."),
                                time: ts > 0
                                    ? _relativeTime(ts)
                                    : "--",
                                showDot: false,
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 16),

                        // ── SAFETY TIPS ──
                        _safetyTipsCard(),

                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // 🔥 GAS MONITOR CARD
  // ─────────────────────────────────────────
  Widget _gasMonitorCard({
    required bool gasDetected,
    required double gasPercent,
    required int lastCheckedTs,
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
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: gasDetected
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: gasDetected ? Colors.red : const Color(0xFF2DCB73),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Gas Leak Monitor",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gasDetected
                          ? "⚠️ Gas leak detected!"
                          : "Real-time detection active",
                      style: TextStyle(
                        fontSize: 12,
                        color: gasDetected
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              // Live indicator dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: gasDetected
                      ? Colors.red
                      : const Color(0xFF2DCB73),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (gasDetected
                              ? Colors.red
                              : const Color(0xFF2DCB73))
                          .withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ Status banner — real data
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: gasDetected
                  ? Colors.red.withOpacity(0.06)
                  : const Color(0xFF2DCB73).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: gasDetected
                    ? Colors.red.withOpacity(0.2)
                    : const Color(0xFF2DCB73).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      gasDetected
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                      size: 15,
                      color: gasDetected
                          ? Colors.red
                          : const Color(0xFF2DCB73),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gasDetected
                          ? "Gas leak detected!"
                          : "No gas leaks detected",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: gasDetected
                            ? Colors.red
                            : const Color(0xFF2DCB73),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  lastCheckedTs > 0
                      ? "Last checked: ${_relativeTime(lastCheckedTs)}"
                      : "Last checked: Just now",
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 🔲 ALERT TILE
  // ─────────────────────────────────────────
  Widget _alertTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    required String title,
    required String subtitle,
    required String time,
    required bool showDot,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          if (showDot)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF3A7BD5),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 💡 SAFETY TIPS CARD
  // ─────────────────────────────────────────
  Widget _safetyTipsCard() {
    const tips = [
      "Always check for gas leaks regularly",
      "Keep the cylinder in a well-ventilated area",
      "Replace the regulator every 5 years",
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A56C4), Color(0xFF3A7BD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Safety Tips",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // 🔲 HELPER WIDGETS
  // ─────────────────────────────────────────
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A2E),
        ),
      ),
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3A7BD5),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 66,
      endIndent: 16,
      color: Colors.grey.shade100,
    );
  }
}