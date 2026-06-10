import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ─────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────

class EmergencyContact {
  final String id;
  String name;
  String email;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        email: json['email'] ?? '',
      );
}

// ─────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen>
    with TickerProviderStateMixin {
  List<EmergencyContact> _contacts = [];
  bool _isSaving = false;
  bool _isTesting = false;
  String _fcmToken = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Change this to your actual API endpoint ──
  static const String _apiBase =
      'https://tqxls80iih.execute-api.ap-south-1.amazonaws.com/prod';

  static const String _deviceId = 'esp32-health-monitor';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 1.0, end: 1.08).animate(_pulseController);
    _loadLocalContacts();
    _getFCMToken();
  }

  // ── FCM TOKEN ──────────────────────────────────────────────

  Future<void> _getFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Permission maango (iOS ke liye zaroor)
    await messaging.requestPermission();

    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Is token ko contacts ke saath AWS pe save karo
    setState(() => _fcmToken = token ?? '');
  }

  // ── LOCAL STORAGE ──────────────────────────────────────────

  Future<void> _loadLocalContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('emergency_contacts');
    if (raw != null) {
      final List decoded = json.decode(raw);
      setState(() {
        _contacts =
            decoded.map((e) => EmergencyContact.fromJson(e)).toList();
      });
    }
  }

  Future<void> _saveLocalContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'emergency_contacts',
      json.encode(_contacts.map((c) => c.toJson()).toList()),
    );
  }

  // ── VALIDATION ─────────────────────────────────────────────

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  bool _isDuplicate(String email, {String? excludeId}) {
    for (final c in _contacts) {
      if (c.id == excludeId) continue;
      if (email.isNotEmpty && c.email.toLowerCase() == email.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  // ── ADD / EDIT DIALOG ──────────────────────────────────────

  void _showContactDialog({EmergencyContact? existing}) {
    final nameCtrl =
    TextEditingController(text: existing?.name ?? '');
    final emailCtrl =
    TextEditingController(text: existing?.email ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              existing == null ? Icons.person_add : Icons.edit,
              color: Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(
              existing == null ? 'Add Contact' : 'Edit Contact',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildField(
                  controller: nameCtrl,
                  label: 'Full Name',
                  icon: Icons.person,
                  validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 14),
                _buildField(
                  controller: emailCtrl,
                  label: 'Email Address',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!_isValidEmail(v.trim())) return 'Invalid email format';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();

              if (_isDuplicate(email, excludeId: existing?.id)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                    Text('Duplicate email already exists!'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              setState(() {
                if (existing == null) {
                  _contacts.add(EmergencyContact(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    email: email,
                  ));
                } else {
                  existing.name = name;
                  existing.email = email;
                }
              });

              Navigator.pop(ctx);
            },
            child: Text(
              existing == null ? 'Add' : 'Save',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.redAccent),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }

  // ── DELETE ─────────────────────────────────────────────────

  void _deleteContact(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact?'),
        content:
        const Text('This contact will be removed from emergency alerts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() => _contacts.removeWhere((c) => c.id == id));
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── SAVE TO AWS ────────────────────────────────────────────

  Future<void> _saveToAWS() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one contact first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _saveLocalContacts(); // save locally first

      final response = await http.post(
        Uri.parse('$_apiBase/contacts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': _deviceId,
          'contacts': _contacts.map((c) => c.toJson()).toList(),
          'fcm_token': _fcmToken,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Contacts saved to AWS successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      await _saveLocalContacts(); // ensure local save even on AWS failure
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Saved locally. AWS sync failed: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── TEST ALERT ─────────────────────────────────────────────

  Future<void> _sendTestAlert() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add contacts before sending test alert!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Send Test Alert?'),
          ],
        ),
        content: const Text(
          'This will send a TEST emergency alert to all your contacts via SMS and Email.\n\nAWS SNS charges apply per message.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Test',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isTesting = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBase/trigger-emergency'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': _deviceId,
          'heart_rate': 45,
          'spo2': 88,
          'latitude': 24.8607,
          'longitude': 67.0011,
          'is_test': true,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🚨 Test alert sent to all contacts!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('Status: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  // ── BUILD ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveToAWS,
            icon: _isSaving
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_upload),
            tooltip: 'Save to AWS',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Header Info Card ──
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700, Colors.red.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: const Icon(Icons.notifications_active,
                      color: Colors.white, size: 40),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Alert System',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Contacts receive SMS + Email when vitals are critical',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Contacts Count ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_contacts.length} Contact(s)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                Text(
                  'Max recommended: 5',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Contact List ──
          Expanded(
            child: _contacts.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_add,
                      size: 80,
                      color: Colors.red.shade200),
                  const SizedBox(height: 16),
                  const Text(
                    'No emergency contacts yet',
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap + to add family members',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _contacts.length,
              itemBuilder: (ctx, i) =>
                  _buildContactCard(_contacts[i]),
            ),
          ),

          // ── Bottom Buttons ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _showContactDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    label: const Text(
                      'Add Contact',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveToAWS,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save, color: Colors.white),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Contacts to AWS',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isTesting ? null : _sendTestAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    icon: _isTesting
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white),
                    label: Text(
                      _isTesting ? 'Sending...' : '🚨 Send Test Alert',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red.shade100,
              radius: 24,
              child: Text(
                contact.name.isNotEmpty
                    ? contact.name[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.email,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(contact.email,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black87),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () =>
                      _showContactDialog(existing: contact),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteContact(contact.id),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}