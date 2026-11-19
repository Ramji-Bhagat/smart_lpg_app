import 'package:flutter/material.dart';
import '../services/refill_service.dart';

class NewRefillPage extends StatefulWidget {
  const NewRefillPage({super.key});

  @override
  State<NewRefillPage> createState() => _NewRefillPageState();
}

class _NewRefillPageState extends State<NewRefillPage> {
  final RefillService _refillService = RefillService();
  final TextEditingController _weightController = TextEditingController();
  bool _isSaving = false;
  String? _errorText;

  double get _grossWeight => double.tryParse(_weightController.text) ?? 0.0;
  double get _tareWeight => (_grossWeight - 14.2).clamp(0.0, double.infinity);
  double get _netWeight => 14.2; // ✅ always fixed
  double get _percent => 100.0; // ✅ always 100% on new refill

  Future<void> _saveRefill() async {
    final gross = _grossWeight;

    if (gross <= 0) {
      setState(() => _errorText = "Please enter a valid weight");
      return;
    }
    if (gross <= 15) {
      setState(() => _errorText = "Gross weight must be greater than 15 kg");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final success = await _refillService.saveRefill(grossWeight: gross);

      if (success) {
        if (mounted) Navigator.pop(context); // ✅ go back after save
      } else {
        setState(() {
          _errorText = "Failed to save refill";
        });
      }
    } catch (e) {
      setState(() {
        _errorText = "Something went wrong";
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
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
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  "New Cylinder Refill",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── INFO CARD ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF3FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF3A7BD5).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF3A7BD5),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Enter the total weight shown on the scale after installing the new cylinder (cylinder + gas).",
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A56C4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── WEIGHT INPUT ──
                  const Text(
                    "Gross Weight (kg)",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() => _errorText = null),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "e.g. 28.5",
                      suffixText: "kg",
                      errorText: _errorText,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF3A7BD5),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── LIVE PREVIEW ──
                  if (_grossWeight >= 19.0)
                    Container(
                      padding: const EdgeInsets.all(20),
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
                        children: [
                          const Text(
                            "Breakdown",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _breakdownRow(
                            "Gross Weight",
                            "${_grossWeight.toStringAsFixed(1)} kg",
                            Colors.grey,
                          ),
                          const Divider(height: 20),
                          _breakdownRow(
                            "Tare (Cylinder Body)",
                            "− ${_tareWeight.toStringAsFixed(1)} kg", // ✅ dynamic = gross - 14.2
                            Colors.orange,
                          ),
                          const Divider(height: 20),
                          _breakdownRow(
                            "Net Gas Weight",
                            "${_netWeight.toStringAsFixed(1)} kg", // ✅ always fixed
                            const Color(0xFF2DCB73),
                            bold: true,
                          ),
                          const SizedBox(height: 16),

                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _percent / 100,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF2DCB73),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${_percent.toStringAsFixed(0)}% full",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2DCB73),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 28),

                  // ── SAVE BUTTON ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveRefill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3A7BD5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "Save Refill",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  Widget _breakdownRow(
    String label,
    String value,
    Color valueColor, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
