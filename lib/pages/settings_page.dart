import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Settings State ──
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _darkMode = false;
  String _language = "English";
  String _lowGasThreshold = "15";

  // ── User Data ──
  String _userName = '';
  String _userEmail = '';
  bool _loadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  // ─────────────────────────────────────────
  // 🔥 Load user data from Firestore
  // ─────────────────────────────────────────
  Future<void> _loadUserData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final doc =
          await _firestore.collection('users').doc(uid).get();
      if (!mounted) return;

      setState(() {
        _userName = doc.data()?['name'] ?? '';
        _userEmail =
            doc.data()?['email'] ?? _auth.currentUser?.email ?? '';
        _loadingUser = false;
      });
    } catch (e) {
      setState(() => _loadingUser = false);
    }
  }

  // ─────────────────────────────────────────
  // 🔥 Load settings from Firestore
  // ─────────────────────────────────────────
  Future<void> _loadSettings() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences')
          .get();

      if (!mounted) return;
      if (!doc.exists) return;

      final d = doc.data()!;
      setState(() {
        _pushNotifications = d['push_notifications'] as bool? ?? true;
        _emailNotifications =
            d['email_notifications'] as bool? ?? true;
        _darkMode = d['dark_mode'] as bool? ?? false;
        _language = d['language'] as String? ?? 'English';
        _lowGasThreshold =
            (d['low_gas_threshold'] ?? 15).toString();
      });
    } catch (e) {
      debugPrint('❌ loadSettings error: $e');
    }
  }

  // ─────────────────────────────────────────
  // 🔥 Save a single setting to Firestore
  // ─────────────────────────────────────────
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences')
          .set({key: value}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ saveSetting error: $e');
    }
  }

  // ─────────────────────────────────────────
  // 🔥 Logout
  // ─────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text("Logout",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel",
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.signOut();
      // authStateChanges in main.dart auto-redirects to LoginPage
    }
  }

  // ─────────────────────────────────────────
  // 🔥 Change Password
  // ─────────────────────────────────────────
  Future<void> _changePassword() async {
    final email = _auth.currentUser?.email;
    if (email == null) return;

    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Password reset email sent to $email'),
          backgroundColor: const Color(0xFF2DCB73),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─────────────────────────────────────────
  // 🔥 Change Low Gas Alert Threshold
  // ─────────────────────────────────────────
  Future<void> _changeLowGasThreshold() async {
    final controller =
        TextEditingController(text: _lowGasThreshold);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text("Low Gas Alert",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                "Set the gas level % to trigger a low gas alert:"),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: "%",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel",
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0 && val <= 100) {
                setState(
                    () => _lowGasThreshold = val.toString());
                await _saveSetting(
                    'low_gas_threshold', val);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              }
            },
            child: const Text("Save",
                style:
                    TextStyle(color: Color(0xFF3A7BD5))),
          ),
        ],
      ),
    );
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

                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 28),
                ),

                const SizedBox(width: 14),

                // Name + email
                Expanded(
                  child: _loadingUser
                      ? const SizedBox(
                          height: 16,
                          width: 100,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                          ),
                        )
                      : Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userName.isEmpty
                                  ? 'User'
                                  : _userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _userEmail,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // ── SCROLLABLE BODY ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [

                // ── Account Section ──
                _sectionLabel("Account"),
                _settingsCard(children: [
                  _navTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF3A7BD5),
                    iconBg: const Color(0xFFEEF3FF),
                    title: "Change Password",
                    onTap: _changePassword,
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Cylinder Management ──
                _sectionLabel("Cylinder Management"),
                _settingsCard(children: [
                  _navTile(
                    icon: Icons.local_fire_department_outlined,
                    iconColor: const Color(0xFF2DCB73),
                    iconBg: const Color(0xFFE8F5E9),
                    title: "My Cylinders",
                    trailing: "1 Active",
                    onTap: () {},
                  ),
                  _divider(),
                  _navTile(
                    icon: Icons.notifications_outlined,
                    iconColor: Colors.orange,
                    iconBg: const Color(0xFFFFF3E0),
                    title: "Low Gas Alert",
                    trailing: "$_lowGasThreshold%",
                    onTap: _changeLowGasThreshold,
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Notifications ──
                _sectionLabel("Notifications"),
                _settingsCard(children: [
                  _toggleTile(
                    icon: Icons.notifications_outlined,
                    iconColor: const Color(0xFF3A7BD5),
                    iconBg: const Color(0xFFEEF3FF),
                    title: "Push Notifications",
                    subtitle: "Receive alerts on your device",
                    value: _pushNotifications,
                    onChanged: (val) {
                      setState(() => _pushNotifications = val);
                      _saveSetting('push_notifications', val);
                    },
                  ),
                  _divider(),
                  _toggleTile(
                    icon: Icons.email_outlined,
                    iconColor: Colors.purple,
                    iconBg: const Color(0xFFF3E8FF),
                    title: "Email Notifications",
                    subtitle: "Get updates via email",
                    value: _emailNotifications,
                    onChanged: (val) {
                      setState(() => _emailNotifications = val);
                      _saveSetting('email_notifications', val);
                    },
                  ),
                ]),

                const SizedBox(height: 16),

                // ── App Settings ──
                _sectionLabel("App Settings"),
                _settingsCard(children: [
                  _toggleTile(
                    icon: Icons.dark_mode_outlined,
                    iconColor: Colors.indigo,
                    iconBg: const Color(0xFFEEF0FF),
                    title: "Dark Mode",
                    value: _darkMode,
                    onChanged: (val) {
                      setState(() => _darkMode = val);
                      _saveSetting('dark_mode', val);
                    },
                  ),
                  _divider(),
                  _navTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.teal,
                    iconBg: const Color(0xFFE0F7F4),
                    title: "Language",
                    trailing: _language,
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 16),

                // ── Support & About ──
                _sectionLabel("Support & About"),
                _settingsCard(children: [
                  _navTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: Colors.grey,
                    iconBg: const Color(0xFFF5F5F5),
                    title: "Help Center",
                    onTap: () {},
                  ),
                  _divider(),
                  _navTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.grey,
                    iconBg: const Color(0xFFF5F5F5),
                    title: "About",
                    trailing: "v1.0.0",
                    onTap: () => _showAboutDialog(),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── LOGOUT BUTTON ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded,
                        color: Colors.red, size: 20),
                    label: const Text(
                      "Logout",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.red.withOpacity(0.3)),
                      backgroundColor:
                          Colors.red.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Footer ──
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.local_fire_department,
                            color: Color(0xFF3A7BD5), size: 18),
                        SizedBox(width: 6),
                        Text(
                          "Smart LPG",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Intelligent Gas Monitoring System",
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "© 2026 All rights reserved",
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
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

  Widget _navTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
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
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing,
                style: const TextStyle(
                    fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right,
                color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _toggleTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? subtitle,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
                ],
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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A56C4), Color(0xFF3A7BD5)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "Smart LPG",
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text("Version 1.0.0",
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text(
              "Intelligent Gas Monitoring System",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              "© 2026 All rights reserved",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close",
                style: TextStyle(color: Color(0xFF3A7BD5))),
          ),
        ],
      ),
    );
  }
}