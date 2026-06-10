import 'package:flutter/material.dart';
import 'package:fypapp/screens/login/login_screen.dart';
import 'package:fypapp/screens/map/map_screen.dart';
import 'package:fypapp/screens/wifi_config/wifi_config_screen.dart';
import 'package:fypapp/screens/history/history_screen.dart';
import 'package:fypapp/screens/emergency/emergency_contacts_screen.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _dataTimer;
  String heartRate = "-- bpm";
  String spo2 = "-- %";
  String deviceStatus = "Connecting...";
  bool isConnected = false;

  // API Gateway URL
  final String apiUrl = "https://u2yktmh1zg.execute-api.ap-south-1.amazonaws.com/prod/vitals";
  //final String apiUrl = "https://a1sdvq1q3j.execute-api.me-central-1.amazonaws.com/prod/vitals";
  //final String apiUrl = "https://82x4ep0iwi.execute-api.me-central-1.amazonaws.com/prod/vitals";

  @override
  void initState() {
    super.initState();
    _startFetchingData();
  }

  void _startFetchingData() {
    _fetchVitalsData();
    _dataTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted) {
        _fetchVitalsData();
      }
    });
  }

  Future<void> _fetchVitalsData() async {
    try {
      setState(() {
        deviceStatus = "Fetching data...";
      });

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('DEBUG: Raw response: $data');

        // Handle Lambda response format
        var vitalsData = data;

        // If response has 'body' field (Lambda response), parse it
        if (data['body'] != null) {
          try {
            vitalsData = json.decode(data['body']);
            print('DEBUG: Parsed from body: $vitalsData');
          } catch (e) {
            vitalsData = data;
            print('DEBUG: Could not parse body, using raw: $vitalsData');
          }
        }

        print('DEBUG: Final vitalsData: $vitalsData');
        print('DEBUG: heart_rate: ${vitalsData['heart_rate']}');
        print('DEBUG: spo2: ${vitalsData['spo2']}');

        // Check if we have valid heart_rate data
        final heartRateValue = vitalsData['heart_rate'];
        final spo2Value = vitalsData['spo2'];

        if (heartRateValue != null && heartRateValue != 0) {
          setState(() {
            heartRate = "$heartRateValue bpm";
            spo2 = "$spo2Value %";
            deviceStatus = "AWS Connected - Live Data";
            isConnected = true;
          });
          print('✅ Data Updated: HR=$heartRateValue, SpO2=$spo2Value');
        } else {
          setState(() {
            deviceStatus = "No data available";
            isConnected = false;
          });
          print('❌ Invalid data: HR=$heartRateValue, SpO2=$spo2Value');
        }
      } else {
        setState(() {
          deviceStatus = "API Error: ${response.statusCode}";
          isConnected = false;
        });
        print('❌ API Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        deviceStatus = "Connection Error";
        isConnected = false;
      });
      print('Error fetching data: $e');
    }
  }

  @override
  void dispose() {
    _dataTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("Heart Vitals"),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.redAccent),
              child: const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_remote, color: Colors.blue),
              title: const Text('Configure ESP32 WiFi'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WiFiConfigScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.app_registration),
              title: const Text('Register yourself'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add users'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History of vitals'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency, color: Colors.red),
              title: const Text('Emergency Contacts'),
              subtitle: const Text('Configure alert recipients'),
              // Change 1 — Drawer Emergency Contacts navigate with heartRate & spo2
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmergencyContactsScreen(
                      heartRate: int.tryParse(heartRate.replaceAll(' bpm', '')) ?? 0,
                      spo2: int.tryParse(spo2.replaceAll(' %', '')) ?? 0,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Device Status Card
            Card(
              elevation: 6,
              color: isConnected
                  ? Colors.green.shade50
                  : Colors.red.shade100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isConnected
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      radius: 28,
                      child: Icon(
                        isConnected ? Icons.cloud_done : Icons.cloud_off,
                        color: isConnected ? Colors.green : Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Device Status",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            deviceStatus,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _fetchVitalsData();
                      },
                      icon: const Icon(Icons.refresh, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Heart Rate Card - CLICKABLE
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(
                      vitalType: 'heart_rate',
                    ),
                  ),
                );
              },
              child: VitalCard(
                icon: Icons.favorite,
                iconColor: Colors.red,
                title: "Heart Rate",
                value: heartRate,
                isLive: isConnected,
              ),
            ),
            const SizedBox(height: 16),

            // SpO2 Card - CLICKABLE
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(
                      vitalType: 'spo2',
                    ),
                  ),
                );
              },
              child: VitalCard(
                icon: Icons.bubble_chart,
                iconColor: Colors.green,
                title: "SpO₂ Level",
                value: spo2,
                isLive: isConnected,
              ),
            ),
            const SizedBox(height: 20),

            // GPS Location Card
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        radius: 28,
                        child: const Icon(Icons.location_on,
                            color: Colors.orange, size: 32),
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Text(
                          "GPS Location\nTap to open map",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // CONFIGURE ESP32 BUTTON
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 6,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WiFiConfigScreen()),
                  );
                },
                icon: const Icon(Icons.settings_remote, color: Colors.white, size: 28),
                label: const Text(
                  "Configure ESP32 WiFi",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Quick Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // Add User logic
                  },
                  icon: const Icon(Icons.person_add, color: Colors.black),
                  label: const Text(
                    "Add User",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history, color: Colors.black),
                  label: const Text(
                    "History",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  // Change 2 — Quick Action "Alerts" button with heartRate & spo2
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmergencyContactsScreen(
                          heartRate: int.tryParse(heartRate.replaceAll(' bpm', '')) ?? 0,
                          spo2: int.tryParse(spo2.replaceAll(' %', '')) ?? 0,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.emergency, color: Colors.white),
                  label: const Text('Alerts', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class VitalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final bool isLive;

  const VitalCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.1),
              radius: 28,
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (isLive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            "LIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}