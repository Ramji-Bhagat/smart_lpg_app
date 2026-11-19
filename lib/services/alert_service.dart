import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AlertService {
  final String deviceId = "device_001";
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ─────────────────────────────────────────
  // 👂 LISTEN TO REALTIME DB & SAVE ALERTS
  // Call once from main app — listens forever
  // Saves alert when gas_detected or low_weight = true
  // ─────────────────────────────────────────
  void startAlertListener() {
    _db.child("devices").child(deviceId).child("latest").onValue.listen((
      event,
    ) async {
      if (event.snapshot.value == null) return;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final gasDetected = data['gas_detected'] as bool? ?? false;
      final lowWeight = data['low_weight'] as bool? ?? false;
      final status = data['status'] as String? ?? 'UNKNOWN';
      final weight = _toDouble(data['weight']);
      final mq6Value = (data['mq6_value'] ?? 0) is int
          ? data['mq6_value'] as int
          : (data['mq6_value'] as num?)?.toInt() ?? 0;
      final timestamp = (data['timestamp'] ?? 0) is int
          ? data['timestamp'] as int
          : (data['timestamp'] as num?)?.toInt() ?? 0;

      // Only save if there's an actual alert condition
      if (!gasDetected && !lowWeight) return;

      await _saveAlert(
        type: gasDetected ? 'gas_detected' : 'low_weight',
        gasDetected: gasDetected,
        lowWeight: lowWeight,
        weight: weight,
        status: status,
        mq6Value: mq6Value,
        timestamp: timestamp,
      );
    });
  }

  // ─────────────────────────────────────────
  // 💾 SAVE ALERT TO FIRESTORE
  // Uses timestamp as doc ID to prevent duplicates
  // ─────────────────────────────────────────
  Future<void> _saveAlert({
    required String type,
    required bool gasDetected,
    required bool lowWeight,
    required double weight,
    required String status,
    required int mq6Value,
    required int timestamp,
  }) async {
    try {
      final now = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      final dateKey =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Use timestamp as doc ID — prevents saving same alert twice
      final docId = timestamp.toString();

      await FirebaseFirestore.instance
          .collection('alerts')
          .doc(deviceId)
          .collection('records')
          .doc(docId)
          .set({
            'type': type,
            'gas_detected': gasDetected,
            'low_weight': lowWeight,
            'weight': double.parse(weight.toStringAsFixed(2)),
            'net_weight': double.parse(
              (weight - 18.0).clamp(0.0, 14.2).toStringAsFixed(2),
            ),
            'status': status,
            'mq6_value': mq6Value,
            'message': gasDetected
                ? 'Gas leak detected!'
                : 'Gas level dropped to ${((weight - 18.0) / 14.2 * 100).clamp(0, 100).toStringAsFixed(0)}%',
            'timestamp': timestamp,
            'date': dateKey,
          }, SetOptions(merge: true));

      debugPrint('✅ Alert saved: $type at $dateKey');
    } catch (e) {
      debugPrint('❌ _saveAlert error: $e');
    }
  }

  // ─────────────────────────────────────────
  // 📋 GET ALL ALERTS (for History page)
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getAlerts() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .doc(deviceId)
        .collection('records')
        // ✅ No .limit() — fetch all alerts
        .snapshots()
        .handleError((e) => debugPrint('❌ getAlerts error: $e'))
        .map((snap) {
          final docs = snap.docs.map((doc) {
            final d = doc.data();
            // ✅ Safe timestamp — never null
            final ts = d['timestamp'];
            final tsInt = ts == null
                ? 0
                : ts is int
                ? ts
                : (ts as num).toInt();
            return {
              'id': doc.id,
              'type': d['type'] as String? ?? 'low_weight',
              'gas_detected': d['gas_detected'] as bool? ?? false,
              'low_weight': d['low_weight'] as bool? ?? false,
              'weight': _toDouble(d['weight']),
              'net_weight': _toDouble(d['net_weight']),
              'status': d['status'] as String? ?? '',
              'mq6_value': (d['mq6_value'] ?? 0) is int
                  ? d['mq6_value'] as int
                  : (d['mq6_value'] as num?)?.toInt() ?? 0,
              'message': d['message'] as String? ?? '',
              'date': d['date'] as String? ?? '',
              'timestamp': tsInt, // ✅ always int
              'datetime': DateTime.fromMillisecondsSinceEpoch(tsInt * 1000),
            };
          }).toList();

          docs.sort(
            (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int),
          );
          return docs;
        });
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    return 0.0;
  }
}
