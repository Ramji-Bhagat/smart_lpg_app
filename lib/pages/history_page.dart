import 'package:flutter/material.dart';
import '../services/realtime_service.dart';
import '../services/refill_service.dart';
import '../services/alert_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final RealtimeService _realtimeService = RealtimeService();
  final RefillService _refillService = RefillService();
  final AlertService _alertService = AlertService();

  int _tabIndex = 0;

  // ✅ Pagination — each tab tracks its own visible count
  final Map<int, int> _visibleCount = {0: 10, 1: 10, 2: 10, 3: 10};
  static const int _pageSize = 10;

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();
    return 0.0;
  }

  // ✅ Safe int cast — never throws
  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is num) return val.toInt();
    return 0;
  }

  String _formatDate(String dateKey) {
    if (dateKey.isEmpty) return '';
    try {
      final parts = dateKey.split('-');
      final dt = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    } catch (_) {
      return dateKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [

          // ── HEADER ──
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Usage History",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterTab("All", 0),
                      const SizedBox(width: 8),
                      _filterTab("Refills", 1),
                      const SizedBox(width: 8),
                      _filterTab("Usage", 2),
                      const SizedBox(width: 8),
                      _filterTab("Alerts", 3),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _filterTab(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _tabIndex = index;
        // ✅ Reset pagination when switching tabs
        _visibleCount[index] = _pageSize;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF1A56C4) : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // ✅ Use getDailyBreakdownAll() — no 7-day limit
      stream: _realtimeService.getDailyBreakdownAll(),
      builder: (context, usageSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _refillService.getRefills(),
          builder: (context, refillSnap) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _alertService.getAlerts(),
              builder: (context, alertSnap) {
                // ✅ Safe data extraction
                final usageList = usageSnap.data ?? [];
                final refillList = refillSnap.data ?? [];
                final alertList = alertSnap.data ?? [];

                // ── Stats ──
                final totalRefills = refillList.length;

                // ✅ Days tracked = total unique days ever recorded
                final daysTracked = usageList.length;

                double avgKgPerDay = 0.0;
                if (usageList.isNotEmpty) {
                  final total = usageList.fold<double>(
                      0.0, (sum, d) => sum + _toDouble(d['usage']));
                  avgKgPerDay = double.parse(
                      (total / usageList.length).toStringAsFixed(1));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [

                    // ── STATS ROW ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 8),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statTile(
                            icon: Icons.local_fire_department_outlined,
                            iconColor: const Color(0xFF2DCB73),
                            value: "$totalRefills",
                            label: "Refills",
                          ),
                          _verticalDivider(),
                          _statTile(
                            icon: Icons.trending_down_rounded,
                            iconColor: const Color(0xFF3A7BD5),
                            value: "$daysTracked",
                            label: "Days\nTracked",
                          ),
                          _verticalDivider(),
                          _statTile(
                            icon: Icons.calendar_month_outlined,
                            iconColor: Colors.purple,
                            value: "$avgKgPerDay",
                            label: "Avg kg/day",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── FILTERED LIST WITH PAGINATION ──
                    ..._buildFilteredList(
                      tabIndex: _tabIndex,
                      usageList: usageList,
                      refillList: refillList,
                      alertList: alertList,
                    ),

                    if (_tabIndex == 1 || _tabIndex == 3) ...[
                      const SizedBox(height: 16),
                      _exportCard(),
                    ],

                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buildFilteredList({
    required int tabIndex,
    required List<Map<String, dynamic>> usageList,
    required List<Map<String, dynamic>> refillList,
    required List<Map<String, dynamic>> alertList,
  }) {
    List<Widget> widgets = [];
    List<Map<String, dynamic>> fullList = [];

    if (tabIndex == 0) {
      // ✅ ALL — safe merge with guaranteed int timestamps
      final all = [
        ...usageList.map((d) => {
              ...d,
              '_type': 'usage',
              'timestamp': _toInt(d['timestamp']),
            }),
        ...refillList.map((d) => {
              ...d,
              '_type': 'refill',
              'timestamp': _toInt(d['timestamp']),
            }),
        ...alertList.map((d) => {
              ...d,
              '_type': 'alert',
              'timestamp': _toInt(d['timestamp']),
            }),
      ];
      // ✅ Safe sort — _toInt guarantees no null
      all.sort((a, b) =>
          (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      fullList = all;
    } else if (tabIndex == 1) {
      fullList = refillList;
    } else if (tabIndex == 2) {
      fullList = usageList;
    } else if (tabIndex == 3) {
      fullList = alertList;
    }

    if (fullList.isEmpty) {
      widgets.add(_emptyState(_emptyMessage(tabIndex)));
      return widgets;
    }

    // ✅ Paginate — show only _visibleCount[tabIndex] items
    final visible = _visibleCount[tabIndex] ?? _pageSize;
    final showItems = fullList.take(visible).toList();
    final hasMore = fullList.length > visible;

    for (final item in showItems) {
      final type = tabIndex == 0
          ? item['_type'] as String
          : tabIndex == 1
              ? 'refill'
              : tabIndex == 2
                  ? 'usage'
                  : 'alert';
      widgets.add(_buildItem(item, type));
      widgets.add(const SizedBox(height: 10));
    }

    // ✅ Load More button
    if (hasMore) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _visibleCount[tabIndex] =
                      (_visibleCount[tabIndex] ?? _pageSize) +
                          _pageSize;
                });
              },
              icon: const Icon(Icons.expand_more,
                  color: Color(0xFF3A7BD5)),
              label: Text(
                "Load More  (${fullList.length - visible} remaining)",
                style: const TextStyle(
                  color: Color(0xFF3A7BD5),
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: const Color(0xFF3A7BD5).withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      );
    } else if (fullList.length > _pageSize) {
      // ✅ Show "All caught up" when everything is loaded
      widgets.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              "All records loaded ✓",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildItem(Map<String, dynamic> item, String type) {
    if (type == 'usage') {
      final usage = _toDouble(item['usage']);
      const avgKgPerDay = 2.3;
      final isBelow = usage < avgKgPerDay;
      return _historyTile(
        icon: Icons.trending_down_rounded,
        iconColor: const Color(0xFF3A7BD5),
        iconBg: const Color(0xFFEEF3FF),
        title: "Daily Usage",
        subtitle: isBelow
            ? "Below average consumption"
            : usage > 3.0
                ? "High consumption day"
                : "Normal consumption",
        date: _formatDate(item['dateKey'] as String? ?? ''),
        value: "${usage.toStringAsFixed(1)} kg",
        valueColor: isBelow ? Colors.green : Colors.orange,
        valueIcon:
            isBelow ? Icons.trending_down : Icons.trending_up,
      );
    } else if (type == 'refill') {
      final netWeight = _toDouble(item['net_weight']);
      return _historyTile(
        icon: Icons.local_fire_department_outlined,
        iconColor: const Color(0xFF2DCB73),
        iconBg: const Color(0xFFE8F5E9),
        title: "Cylinder Refilled",
        subtitle:
            "New ${netWeight.toStringAsFixed(1)} kg cylinder installed",
        date: _formatDate(item['date'] as String? ?? ''),
        value: "${netWeight.toStringAsFixed(1)} kg",
        valueColor: const Color(0xFF2DCB73),
        valueIcon: null,
      );
    } else {
      final isGas = item['gas_detected'] as bool? ?? false;
      final weight = _toDouble(item['net_weight']);
      return _historyTile(
        icon: isGas
            ? Icons.warning_amber_rounded
            : Icons.battery_alert_rounded,
        iconColor: Colors.orange,
        iconBg: const Color(0xFFFFF3E0),
        title: isGas ? "Gas Leak Alert" : "Low Gas Alert",
        subtitle: item['message'] as String? ?? '',
        date: _formatDate(item['date'] as String? ?? ''),
        value: "${weight.toStringAsFixed(1)} kg",
        valueColor: Colors.orange,
        valueIcon: null,
      );
    }
  }

  String _emptyMessage(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return "No refills recorded yet";
      case 2:
        return "No usage data yet";
      case 3:
        return "No alerts triggered yet";
      default:
        return "No history yet";
    }
  }

  Widget _historyTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String date,
    required String value,
    required Color valueColor,
    IconData? valueIcon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
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
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(date,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  if (valueIcon != null)
                    Icon(valueIcon, size: 14, color: valueColor),
                  if (valueIcon != null) const SizedBox(width: 2),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: valueColor)),
                ],
              ),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E))),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(height: 50, width: 1, color: Colors.grey.shade100);
  }

  Widget _exportCard() {
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
          const Text("Export Your Data",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
              "Download your complete usage history as a CSV file",
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Export coming soon!')));
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Download Report",
                  style: TextStyle(
                      color: Color(0xFF3A7BD5),
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.history, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}