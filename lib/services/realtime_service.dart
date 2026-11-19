import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class RealtimeService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String deviceId = "device_001"; // 🔥 fixed device ID

  // ─────────────────────────────────────────
  // 📡 LATEST SENSOR DATA
  // ─────────────────────────────────────────
  Stream<Map<dynamic, dynamic>> getLatestData() {
    return _db
        .child("devices")
        .child(deviceId)
        .child("latest")
        .onValue
        .map((event) => (event.snapshot.value as Map?) ?? {});
  }

  // ─────────────────────────────────────────
  // 🔮 PREDICTION DATA
  // ─────────────────────────────────────────
  Stream<Map<dynamic, dynamic>> getPrediction() {
    return _db
        .child("devices")
        .child(deviceId)
        .child("prediction")
        .onValue
        .map((event) => (event.snapshot.value as Map?) ?? {});
  }

  // ─────────────────────────────────────────
  // 📅 TODAY'S USAGE
  // First reading of day - latest reading of day
  // LPG only decreases, so this is always accurate
  // ─────────────────────────────────────────
  Stream<double> getTodayUsage() {
    final now = DateTime.now();
    final startOfDaySeconds =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;

    return _db
        .child("devices")
        .child(deviceId)
        .child("history")
        .orderByChild("timestamp")
        .startAt(startOfDaySeconds)
        .limitToLast(300)
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return 0.0;

          final raw = event.snapshot.value as Map<dynamic, dynamic>;
          List<Map<String, dynamic>> readings = [];

          raw.forEach((key, value) {
            if (value is Map) {
              final weight = (value['weight'] ?? 0).toDouble();
              final ts = value['timestamp'];
              final tsInt = (ts is double ? ts.toInt() : ts as int);
              if (weight > 0 && tsInt >= startOfDaySeconds) {
                readings.add({'weight': weight, 'timestamp': tsInt});
              }
            }
          });

          if (readings.isEmpty) return 0.0;

          readings.sort(
            (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
          );

          final firstWeight = readings.first['weight'] as double;
          final latestWeight = readings.last['weight'] as double;
          final usage = firstWeight - latestWeight;
          return usage < 0 ? 0.0 : double.parse(usage.toStringAsFixed(2));
        });
  }

  // ─────────────────────────────────────────
  // 📊 AVG DAILY USAGE + META (days of data)
  // Handles fresh installs with < 7 days data
  // ─────────────────────────────────────────
  Stream<Map<String, dynamic>> getAvgDailyUsageWithMeta() {
    final now = DateTime.now();
    final sevenDaysAgoSeconds =
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/
        1000;

    return _db
        .child("devices")
        .child(deviceId)
        .child("history")
        .orderByChild("timestamp")
        .startAt(sevenDaysAgoSeconds)
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return {'avg': 0.0, 'days': 0};

          final raw = event.snapshot.value as Map<dynamic, dynamic>;
          Map<String, List<double>> byDate = {};

          raw.forEach((key, value) {
            if (value is Map) {
              final weight = (value['weight'] ?? 0).toDouble();
              final ts = value['timestamp'];
              final tsInt = (ts is double ? ts.toInt() : ts as int);
              if (weight > 0 && tsInt >= sevenDaysAgoSeconds) {
                final date = DateTime.fromMillisecondsSinceEpoch(tsInt * 1000);
                final dateKey = "${date.year}-${date.month}-${date.day}";
                byDate.putIfAbsent(dateKey, () => []).add(weight);
              }
            }
          });

          if (byDate.isEmpty) return {'avg': 0.0, 'days': 0};

          double totalUsage = 0.0;
          int validDays = 0;

          byDate.forEach((dateKey, weights) {
            weights.sort();
            final dayUsage = weights.last - weights.first;
            if (dayUsage > 0) {
              totalUsage += dayUsage;
              validDays++;
            } else if (weights.length >= 2) {
              validDays++;
            }
          });

          if (validDays == 0) return {'avg': 0.0, 'days': 0};

          return {
            'avg': double.parse((totalUsage / validDays).toStringAsFixed(2)),
            'days': validDays,
          };
        });
  }

  // ─────────────────────────────────────────
  // 🗓️ DAILY BREAKDOWN (for History page)
  // Returns list of per-day usage maps
  // sorted latest first, ready to display
  // ─────────────────────────────────────────
  // ─────────────────────────────────────────
  // 🗓️ ALL DAILY BREAKDOWN (for History page)
  // No date limit — fetches from beginning
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getDailyBreakdownAll() {
    return _db.child("devices").child(deviceId).child("history").onValue.map((
      event,
    ) {
      if (event.snapshot.value == null) return [];

      final raw = event.snapshot.value as Map<dynamic, dynamic>;
      Map<String, List<double>> byDate = {};

      raw.forEach((key, value) {
        if (value is Map) {
          final weight = (value['weight'] ?? 0).toDouble();
          final ts = value['timestamp'];
          if (ts == null || weight <= 0) return;
          final tsInt = (ts is double ? ts.toInt() : ts as int);
          final date = DateTime.fromMillisecondsSinceEpoch(tsInt * 1000);
          final dateKey = "${date.year}-${date.month}-${date.day}";
          byDate.putIfAbsent(dateKey, () => []).add(weight);
        }
      });

      List<Map<String, dynamic>> breakdown = [];

      byDate.forEach((dateKey, weights) {
        weights.sort();
        final parts = dateKey.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final dayUsage = weights.last - weights.first;
        // ✅ Use date midnight as timestamp for sorting
        final timestamp = date.millisecondsSinceEpoch ~/ 1000;
        breakdown.add({
          'date': date,
          'dateKey': dateKey,
          'usage': dayUsage < 0
              ? 0.0
              : double.parse(dayUsage.toStringAsFixed(2)),
          'startWeight': weights.last,
          'endWeight': weights.first,
          'timestamp': timestamp, // ✅ always int, never null
        });
      });

      breakdown.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
      );

      return breakdown;
    });
  }

  // ─────────────────────────────────────────
  // 📆 MONTHLY BREAKDOWN — Realtime DB
  // Kept for fallback, prefer Firestore version
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getMonthlyBreakdown() {
    final now = DateTime.now();
    final sixMonthsAgoSeconds =
        DateTime(now.year, now.month - 5, 1).millisecondsSinceEpoch ~/ 1000;

    return _db
        .child("devices")
        .child(deviceId)
        .child("history")
        .orderByChild("timestamp")
        .startAt(sixMonthsAgoSeconds)
        .onValue
        .map((event) {
          if (event.snapshot.value == null) return [];

          final raw = event.snapshot.value as Map<dynamic, dynamic>;
          Map<String, Map<String, List<double>>> byMonthByDay = {};

          raw.forEach((key, value) {
            if (value is Map) {
              final weight = (value['weight'] ?? 0).toDouble();
              final ts = value['timestamp'];
              final tsInt = (ts is double ? ts.toInt() : ts as int);
              if (weight > 0 && tsInt >= sixMonthsAgoSeconds) {
                final date = DateTime.fromMillisecondsSinceEpoch(tsInt * 1000);
                final monthKey = "${date.year}-${date.month}";
                final dayKey = "${date.year}-${date.month}-${date.day}";
                byMonthByDay.putIfAbsent(monthKey, () => {});
                byMonthByDay[monthKey]!
                    .putIfAbsent(dayKey, () => [])
                    .add(weight);
              }
            }
          });

          if (byMonthByDay.isEmpty) return [];

          List<Map<String, dynamic>> breakdown = [];

          byMonthByDay.forEach((monthKey, dayMap) {
            double monthTotal = 0.0;
            dayMap.forEach((dayKey, weights) {
              weights.sort();
              final dayUsage = weights.last - weights.first;
              if (dayUsage > 0) monthTotal += dayUsage;
            });
            final parts = monthKey.split('-');
            final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
            breakdown.add({
              'date': date,
              'monthKey': monthKey,
              'totalUsage': double.parse(monthTotal.toStringAsFixed(2)),
              'label': _monthLabel(date.month),
            });
          });

          breakdown.sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          );

          return breakdown;
        });
  }

  // ═════════════════════════════════════════
  // 🔥 FIRESTORE METHODS
  // Used for Analytics % change and History page
  // ═════════════════════════════════════════

  // ─────────────────────────────────────────
  // ─────────────────────────────────────────
  // 💾 SAVE/BACKFILL DAILY USAGE TO FIRESTORE
  // ✅ On app open, checks last 30 days
  // ✅ Fills any missing dates from Realtime DB
  // ✅ Saves 0 usage days too (holiday/no cooking)
  // ✅ Never skips days even if app wasn't opened
  // ─────────────────────────────────────────
  Future<void> saveTodayUsageToFirestore() async {
    try {
      final now = DateTime.now();
      final todayKey =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      debugPrint('🚀 saveTodayUsageToFirestore() started');
      debugPrint('📅 Today key: $todayKey');

      // ── Step 1: Check Firestore existing dates ──
      debugPrint('🔍 Step 1: Checking existing Firestore records...');
      final existingDocs = await FirebaseFirestore.instance
          .collection('daily_usage')
          .doc(deviceId)
          .collection('records')
          .orderBy('date', descending: true)
          .limit(30)
          .get();

      final existingDates = existingDocs.docs.map((d) => d.id).toSet();
      debugPrint('📋 Existing Firestore dates: $existingDates');

      // ── Step 2: Fetch from Realtime DB ──
      debugPrint('🔍 Step 2: Fetching Realtime DB history...');
      final thirtyDaysAgoSeconds =
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 30)).millisecondsSinceEpoch ~/
          1000;
      debugPrint('⏱️ Fetching from timestamp: $thirtyDaysAgoSeconds');

      final snapshot = await _db
          .child("devices")
          .child(deviceId)
          .child("history")
          .orderByChild("timestamp")
          .startAt(thirtyDaysAgoSeconds)
          .get();

      debugPrint('📦 Snapshot value is null: ${snapshot.value == null}');
      debugPrint('📦 Snapshot value type: ${snapshot.value?.runtimeType}');

      if (snapshot.value == null) {
        debugPrint('❌ STOPPING: No history data found in Realtime DB');
        debugPrint('   Check path: devices/$deviceId/history');
        return;
      }

      final raw = snapshot.value as Map<dynamic, dynamic>;
      debugPrint('📊 Total raw records fetched: ${raw.length}');

      // Print first 3 records to verify structure
      int previewCount = 0;
      raw.forEach((key, value) {
        if (previewCount < 3) {
          debugPrint('   Sample record [$key]: $value');
          previewCount++;
        }
      });

      // ── Step 3: Group by date ──
      debugPrint('🔍 Step 3: Grouping readings by date...');
      Map<String, List<Map<String, dynamic>>> byDate = {};

      raw.forEach((key, value) {
        if (value is Map) {
          // 🔥 Try both 'weight' and check actual field names
          final weight = (value['weight'] ?? 0).toDouble();
          final ts = value['timestamp'];

          if (ts == null) {
            debugPrint('⚠️ Record $key has no timestamp field');
            return;
          }

          final tsInt = (ts is double ? ts.toInt() : ts as int);

          if (weight <= 0) {
            debugPrint('⚠️ Record $key has zero/invalid weight: $weight');
            return;
          }

          if (tsInt < thirtyDaysAgoSeconds) {
            debugPrint('⚠️ Record $key timestamp too old: $tsInt');
            return;
          }

          final date = DateTime.fromMillisecondsSinceEpoch(tsInt * 1000);
          final dateKey =
              "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
          byDate.putIfAbsent(dateKey, () => []).add({
            'weight': weight,
            'timestamp': tsInt,
          });
        } else {
          debugPrint('⚠️ Record $key value is not a Map: ${value.runtimeType}');
        }
      });

      debugPrint('📅 Dates found in Realtime DB: ${byDate.keys.toList()}');

      if (byDate.isEmpty) {
        debugPrint('❌ STOPPING: No valid readings grouped by date');
        debugPrint('   Possible causes:');
        debugPrint('   1. weight field name is different');
        debugPrint('   2. timestamp field name is different');
        debugPrint('   3. timestamps are in milliseconds not seconds');
        return;
      }

      // ── Step 4: Write to Firestore ──
      debugPrint('🔍 Step 4: Writing to Firestore...');
      final batch = FirebaseFirestore.instance.batch();
      int writeCount = 0;
      int skipCount = 0;

      byDate.forEach((dateKey, readings) {
        if (dateKey != todayKey && existingDates.contains(dateKey)) {
          debugPrint('⏭️ Skipping $dateKey — already in Firestore');
          skipCount++;
          return;
        }

        readings.sort(
          (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
        );

        final firstWeight = readings.first['weight'] as double;
        final lastWeight = readings.last['weight'] as double;
        final rawUsage = firstWeight - lastWeight;
        final usage = rawUsage < 0
            ? 0.0
            : double.parse(rawUsage.toStringAsFixed(2));

        debugPrint(
          '📝 $dateKey → first: ${firstWeight}kg, last: ${lastWeight}kg, usage: ${usage}kg',
        );

        final docRef = FirebaseFirestore.instance
            .collection('daily_usage')
            .doc(deviceId)
            .collection('records')
            .doc(dateKey);

        batch.set(docRef, {
          'usage': usage,
          'date': dateKey,
          'timestamp': readings.first['timestamp'],
        }, SetOptions(merge: true));

        writeCount++;
      });

      debugPrint('📊 Write count: $writeCount, Skip count: $skipCount');

      if (writeCount > 0) {
        debugPrint('💾 Committing batch to Firestore...');
        await batch.commit();
        debugPrint('✅ SUCCESS: Wrote $writeCount day(s) to Firestore');
      } else {
        debugPrint('✅ Nothing to write — all dates already saved');
      }
    } catch (e, stackTrace) {
      // 🔥 Full error + stack trace
      debugPrint('❌ ERROR in saveTodayUsageToFirestore: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
  }

  // ─────────────────────────────────────────
  // 📅 WEEKLY USAGE FROM FIRESTORE
  // Returns last 7 days of stored daily usage
  // Only returns days that have actual records
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getWeeklyUsageFromFirestore() {
    final now = DateTime.now();

    final dateKeys = List.generate(7, (i) {
      final d = now.subtract(Duration(days: i));
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    }).reversed.toList();

    return FirebaseFirestore.instance
        .collection('daily_usage')
        .doc(deviceId)
        .collection('records')
        .where('date', whereIn: dateKeys)
        // ✅ No orderBy — sort in Dart instead
        .snapshots()
        .handleError((error) {
          debugPrint('❌ getWeeklyUsageFromFirestore error: $error');
          return [];
        })
        .map((snap) {
          final docs = snap.docs.map((doc) {
            final data = doc.data();
            final parts = (data['date'] as String).split('-');
            final rawUsage = data['usage'];
            return {
              'date': DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              ),
              'dateKey': data['date'] as String,
              'usage': rawUsage == null
                  ? 0.0
                  : rawUsage is double
                  ? rawUsage
                  : (rawUsage as num).toDouble(),
            };
          }).toList();

          // ✅ Sort in Dart — no index needed
          docs.sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          );

          return docs;
        });
  }

  Stream<List<Map<String, dynamic>>> getMonthlyUsageFromFirestore() {
    final now = DateTime.now();

    final sixMonthsAgo = DateTime(
      now.month > 6 ? now.year : now.year - 1,
      now.month > 6 ? now.month - 6 : now.month + 6,
      1,
    );
    final startKey =
        "${sixMonthsAgo.year}-${sixMonthsAgo.month.toString().padLeft(2, '0')}-01";

    return FirebaseFirestore.instance
        .collection('daily_usage')
        .doc(deviceId)
        .collection('records')
        .where('date', isGreaterThanOrEqualTo: startKey)
        // ✅ No orderBy — sort in Dart instead
        .snapshots()
        .handleError((error) {
          debugPrint('❌ getMonthlyUsageFromFirestore error: $error');
          return [];
        })
        .map((snap) {
          if (snap.docs.isEmpty) return <Map<String, dynamic>>[];

          Map<String, double> byMonth = {};

          for (final doc in snap.docs) {
            final data = doc.data();
            final dateKey = data['date'] as String? ?? '';
            if (dateKey.isEmpty) continue;
            final monthKey = dateKey.substring(0, 7);
            final rawUsage = data['usage'];
            final usage = rawUsage == null
                ? 0.0
                : rawUsage is double
                ? rawUsage
                : (rawUsage as num).toDouble();
            byMonth[monthKey] = (byMonth[monthKey] ?? 0.0) + usage;
          }

          if (byMonth.isEmpty) return <Map<String, dynamic>>[];

          final result = byMonth.entries.map((e) {
            final parts = e.key.split('-');
            final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
            return {
              'date': date,
              'monthKey': e.key,
              'totalUsage': double.parse(e.value.toStringAsFixed(2)),
              'label': _monthLabel(date.month),
            };
          }).toList();

          // ✅ Sort in Dart — no index needed
          result.sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
          );

          return result;
        });
  }

  Stream<Map<String, dynamic>> getWeeklyChangePercent() {
    final now = DateTime.now();

    final thisWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final lastWeekStartKey =
        "${lastWeekStart.year}-${lastWeekStart.month.toString().padLeft(2, '0')}-${lastWeekStart.day.toString().padLeft(2, '0')}";
    final thisWeekStartKey =
        "${thisWeekStart.year}-${thisWeekStart.month.toString().padLeft(2, '0')}-${thisWeekStart.day.toString().padLeft(2, '0')}";

    return FirebaseFirestore.instance
        .collection('daily_usage')
        .doc(deviceId)
        .collection('records')
        .where('date', isGreaterThanOrEqualTo: lastWeekStartKey)
        // ✅ No orderBy — no index needed
        .snapshots()
        .handleError((error) {
          debugPrint('❌ getWeeklyChangePercent error: $error');
          return {'change': 0.0, 'direction': 'none', 'hasData': false};
        })
        .map((snap) {
          if (snap.docs.isEmpty) {
            return {'change': 0.0, 'direction': 'none', 'hasData': false};
          }

          double thisWeekTotal = 0.0;
          int thisWeekDays = 0;
          double lastWeekTotal = 0.0;
          int lastWeekDays = 0;

          for (final doc in snap.docs) {
            final data = doc.data();
            final dateKey = data['date'] as String? ?? '';
            final rawUsage = data['usage'];
            final usage = rawUsage == null
                ? 0.0
                : rawUsage is double
                ? rawUsage
                : (rawUsage as num).toDouble();

            if (dateKey.compareTo(thisWeekStartKey) >= 0) {
              thisWeekTotal += usage;
              thisWeekDays++;
            } else if (dateKey.compareTo(lastWeekStartKey) >= 0) {
              lastWeekTotal += usage;
              lastWeekDays++;
            }
          }

          if (lastWeekDays == 0) {
            return {'change': 0.0, 'direction': 'none', 'hasData': false};
          }

          final thisAvg = thisWeekDays > 0 ? thisWeekTotal / thisWeekDays : 0.0;
          final lastAvg = lastWeekTotal / lastWeekDays;
          final changePercent = double.parse(
            ((thisAvg - lastAvg) / lastAvg * 100).toStringAsFixed(1),
          );

          return {
            'change': changePercent.abs(),
            'direction': changePercent <= 0 ? 'down' : 'up',
            'hasData': true,
          };
        });
  }

  // ─────────────────────────────────────────
  // 🔧 HELPER
  // ─────────────────────────────────────────
  String _monthLabel(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
