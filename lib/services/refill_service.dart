import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RefillService {
  final String deviceId = "device_001";

  // ─────────────────────────────────────────
  // 💾 SAVE NEW REFILL TO FIRESTORE
  // ─────────────────────────────────────────
  Future<bool> saveRefill({required double grossWeight}) async {
    try {
      final now = DateTime.now();
      final netWeight = 14.2; // ✅ always fixed
      final tareWeight = grossWeight - netWeight; // ✅ dynamic
      final dateKey =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      await FirebaseFirestore.instance
          .collection('refills')
          .doc(deviceId)
          .collection('records')
          .add({
            'gross_weight': grossWeight,
            'net_weight': netWeight, // ✅ always 14.2
            'tare_weight': double.parse(tareWeight.toStringAsFixed(2)),
            'timestamp': now.millisecondsSinceEpoch ~/ 1000,
            'date': dateKey,
          });

      debugPrint(
        '✅ Refill saved: gross=$grossWeight tare=$tareWeight net=14.2',
      );
      return true;
    } catch (e) {
      debugPrint('❌ saveRefill error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────
  // 📋 GET ALL REFILLS (for History page)
  // ─────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> getRefills() {
    return FirebaseFirestore.instance
        .collection('refills')
        .doc(deviceId)
        .collection('records')
        .snapshots()
        .handleError((e) => debugPrint('❌ getRefills error: $e'))
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
              'gross_weight': _toDouble(d['gross_weight']),
              'net_weight': _toDouble(d['net_weight']),
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
