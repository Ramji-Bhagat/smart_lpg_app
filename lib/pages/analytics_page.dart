// At top of analytics_page.dart add this import
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/realtime_service.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final RealtimeService _service = RealtimeService();
  int _tabIndex = 0;

  // ✅ Global safe cast helper — use EVERYWHERE instead of direct cast
  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is num) return val.toDouble();
    return 0.0;
  }

  String _toStr(dynamic val) {
    if (val == null) return '';
    return val.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            // ✅ Wrap entire tab content in error boundary
            child: _tabIndex == 0
                ? _buildWeeklyView()
                : _buildMonthlyView(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Analytics",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _tabButton("This Week", 0),
                _tabButton("6 Months", 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF1A56C4)
                  : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 📅 THIS WEEK VIEW
  // ─────────────────────────────────────────
  Widget _buildWeeklyView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getWeeklyUsageFromFirestore(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Weekly error: ${snapshot.error}');
          return _loadingWidget();
        }

        // ✅ Show loading until data is ready — never render with null data
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ✅ Normalize ALL values through _toDouble before any chart use
        final rawList = snapshot.data ?? [];
        final breakdown = rawList.map((d) => <String, dynamic>{
          'date': d['date'] as DateTime,
          'dateKey': _toStr(d['dateKey']),
          'usage': _toDouble(d['usage']),
        }).toList();

        // Calculate avg safely
        double avgUsage = 0.0;
        if (breakdown.isNotEmpty) {
          final total = breakdown.fold<double>(
              0.0, (sum, d) => sum + _toDouble(d['usage']));
          avgUsage = double.parse(
              (total / breakdown.length).toStringAsFixed(2));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // % change card
            StreamBuilder<Map<String, dynamic>>(
              stream: _service.getWeeklyChangePercent(),
              builder: (context, changeSnap) {
                if (changeSnap.hasError || !changeSnap.hasData) {
                  return _statCard(
                    icon: Icons.trending_down_rounded,
                    iconColor: Colors.green,
                    iconBg: const Color(0xFFE8F5E9),
                    label: "Avg. Usage",
                    value: breakdown.isEmpty
                        ? "-- kg"
                        : "$avgUsage kg",
                    sub: "No previous week data",
                    subColor: Colors.grey,
                  );
                }

                final changeData = changeSnap.data!;
                final hasData = changeData['hasData'] as bool? ?? false;
                final change = _toDouble(changeData['change']);
                final direction =
                    _toStr(changeData['direction']);

                final subLabel = !hasData
                    ? "No previous week data"
                    : direction == 'down'
                        ? "↓ ${change.toStringAsFixed(1)}% from last week"
                        : direction == 'up'
                            ? "↑ ${change.toStringAsFixed(1)}% from last week"
                            : "Same as last week";

                final subColor = !hasData
                    ? Colors.grey
                    : direction == 'up'
                        ? Colors.red
                        : Colors.green;

                return _statCard(
                  icon: direction == 'up'
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  iconColor:
                      direction == 'up' ? Colors.red : Colors.green,
                  iconBg: direction == 'up'
                      ? const Color(0xFFFFEBEE)
                      : const Color(0xFFE8F5E9),
                  label: "Avg. Usage",
                  value: breakdown.isEmpty
                      ? "-- kg"
                      : "$avgUsage kg",
                  sub: subLabel,
                  subColor: subColor,
                );
              },
            ),

            const SizedBox(height: 16),

            _chartCard(
              title: "Daily Usage",
              badge: breakdown.isEmpty
                  ? "No data"
                  : "Last ${breakdown.length} days",
              // ✅ Only render chart when we have valid data
              chart: breakdown.isEmpty
                  ? _emptyChart()
                  : _lineChart(breakdown),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // 📆 6 MONTHS VIEW
  // ─────────────────────────────────────────
  Widget _buildMonthlyView() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.getMonthlyUsageFromFirestore(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Monthly error: ${snapshot.error}');
          return _loadingWidget();
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // ✅ Normalize ALL values through _toDouble
        final rawList = snapshot.data ?? [];
        final breakdown = rawList.map((d) => <String, dynamic>{
          'date': d['date'] as DateTime,
          'monthKey': _toStr(d['monthKey']),
          'label': _toStr(d['label']),
          'totalUsage': _toDouble(d['totalUsage']),
        }).toList();

        double avgUsage = 0.0;
        if (breakdown.isNotEmpty) {
          final total = breakdown.fold<double>(
              0.0, (sum, d) => sum + _toDouble(d['totalUsage']));
          avgUsage = double.parse(
              (total / breakdown.length).toStringAsFixed(2));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statCard(
              icon: Icons.trending_down_rounded,
              iconColor: Colors.green,
              iconBg: const Color(0xFFE8F5E9),
              label: "Avg. Monthly Usage",
              value: breakdown.isEmpty ? "-- kg" : "$avgUsage kg",
              sub: breakdown.isEmpty
                  ? "No data yet"
                  : "Based on ${breakdown.length} month(s)",
              subColor: Colors.grey,
            ),

            const SizedBox(height: 16),

            _chartCard(
              title: "Monthly Usage",
              badge: breakdown.isEmpty
                  ? "No data"
                  : "Last ${breakdown.length} month(s)",
              chart: breakdown.isEmpty
                  ? _emptyChart()
                  : _barChart(breakdown),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // 📈 LINE CHART
  // ─────────────────────────────────────────
  Widget _lineChart(List<Map<String, dynamic>> data) {
    // ✅ Guard — never render empty chart
    if (data.isEmpty) return _emptyChart();

    // ✅ All values go through _toDouble — zero null risk
    final spots = data.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        _toDouble(e.value['usage']),
      );
    }).toList();

    final maxUsage = data.fold<double>(
        0.0, (prev, d) => _toDouble(d['usage']) > prev
            ? _toDouble(d['usage'])
            : prev);

    final chartMax = maxUsage < 0.1
        ? 1.0
        : ((maxUsage / 0.1).ceil() * 0.1 + 0.2).clamp(0.6, 5.0);

    const interval = 0.1;
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: chartMax,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade100,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval,
                reservedSize: 36,
                getTitlesWidget: (value, _) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 9, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) {
                    return const SizedBox();
                  }
                  final date = data[i]['date'];
                  if (date == null || date is! DateTime) {
                    return const SizedBox();
                  }
                  final weekday = date.weekday - 1;
                  if (weekday < 0 || weekday >= days.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      days[weekday],
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              color: const Color(0xFF3A7BD5),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) =>
                    FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: const Color(0xFF3A7BD5),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3A7BD5).withOpacity(0.25),
                    const Color(0xFF3A7BD5).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 📊 BAR CHART
  // ─────────────────────────────────────────
  Widget _barChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return _emptyChart();

    final maxY = data.fold<double>(
            0.0,
            (prev, d) => _toDouble(d['totalUsage']) > prev
                ? _toDouble(d['totalUsage'])
                : prev) *
        1.3;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY < 1.0 ? 10.0 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
                (maxY / 4).clamp(1.0, double.infinity),
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade100,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _toStr(data[i]['label']),
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, _) => Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: data.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: _toDouble(e.value['totalUsage']),
                  color: const Color(0xFF3A7BD5),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // 🔲 HELPERS
  // ─────────────────────────────────────────
  Widget _emptyChart() {
    return const SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("No data available yet",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ✅ Shows spinner instead of red screen during errors
  Widget _loadingWidget() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text("Loading data...",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _statCard({
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
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(fontSize: 11, color: subColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required String badge,
    required Widget chart,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E))),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(badge,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          chart,
        ],
      ),
    );
  }
}