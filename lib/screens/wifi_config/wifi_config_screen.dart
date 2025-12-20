import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class WiFiConfigScreen extends StatefulWidget {
  const WiFiConfigScreen({super.key});

  @override
  State<WiFiConfigScreen> createState() => _WiFiConfigScreenState();
}

class _WiFiConfigScreenState extends State<WiFiConfigScreen> {
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  String statusMessage = "Detecting WiFi networks...";
  Color statusColor = Colors.orange;

  String? currentWiFiSSID;
  String? selectedSSID;
  List<String> savedNetworks = [];
  bool showManualInput = false;
  final TextEditingController manualSSIDController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    await _loadSavedNetworks();
    await _detectCurrentWiFi();
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
  }

  Future<void> _detectCurrentWiFi() async {
    try {
      final info = NetworkInfo();
      final wifiName = await info.getWifiName();

      if (wifiName != null) {
        // Remove quotes if present
        String cleanSSID = wifiName.replaceAll('"', '');

        setState(() {
          currentWiFiSSID = cleanSSID;
          selectedSSID = cleanSSID;
          statusMessage = "Current WiFi detected: $cleanSSID";
          statusColor = Colors.green;
        });
      } else {
        setState(() {
          statusMessage = "No WiFi detected. Please select from saved networks or enter manually.";
          statusColor = Colors.orange;
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = "Could not detect WiFi. Please select manually.";
        statusColor = Colors.orange;
      });
      print('WiFi detection error: $e');
    }
  }

  Future<void> _loadSavedNetworks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('saved_wifi_networks') ?? [];
      setState(() {
        savedNetworks = saved;
      });
    } catch (e) {
      print('Error loading saved networks: $e');
    }
  }

  Future<void> _saveNetwork(String ssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!savedNetworks.contains(ssid)) {
        savedNetworks.add(ssid);
        await prefs.setStringList('saved_wifi_networks', savedNetworks);
      }
    } catch (e) {
      print('Error saving network: $e');
    }
  }

  Future<void> _sendCredentials() async {
    String ssidToSend = showManualInput
        ? manualSSIDController.text
        : (selectedSSID ?? '');

    if (ssidToSend.isEmpty || passwordController.text.isEmpty) {
      _showMessage("Please enter both SSID and Password", Colors.red);
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = "Sending credentials to ESP32...";
      statusColor = Colors.blue;
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.4.1/connect'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'ssid': ssidToSend,
          'password': passwordController.text,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _saveNetwork(ssidToSend);

        setState(() {
          isLoading = false;
          statusMessage = "Credentials sent successfully!";
          statusColor = Colors.green;
        });

        _showSuccessDialog();
      } else {
        setState(() {
          isLoading = false;
          statusMessage = "Failed to send credentials. Error: ${response.statusCode}";
          statusColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = "Connection error. Make sure you're connected to ESP32_Config network.";
        statusColor = Colors.red;
      });
      print('Error: $e');
    }
  }

  void _showMessage(String message, Color color) {
    setState(() {
      statusMessage = message;
      statusColor = color;
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 10),
            Text("Success!"),
          ],
        ),
        content: const Text(
          "WiFi credentials have been sent to ESP32.\n\n"
              "The device is now connecting to your WiFi network and AWS IoT.\n\n"
              "Please reconnect your phone to your home WiFi network.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    manualSSIDController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Combine current WiFi with saved networks (avoid duplicates)
    List<String> allNetworks = [];
    if (currentWiFiSSID != null && !savedNetworks.contains(currentWiFiSSID)) {
      allNetworks.add(currentWiFiSSID!);
    }
    allNetworks.addAll(savedNetworks);

    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("Configure ESP32"),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh WiFi",
            onPressed: _detectCurrentWiFi,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Card
            Card(
              elevation: 6,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 28),
                        const SizedBox(width: 10),
                        const Text(
                          "Setup Instructions",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildInstructionStep("1", "Power on your ESP32 device"),
                    _buildInstructionStep("2", "Go to phone's WiFi settings"),
                    _buildInstructionStep("3", "Connect to 'ESP32_Config' network"),
                    _buildInstructionStep("4", "Password: 12345678"),
                    _buildInstructionStep("5", "Return to this app"),
                    _buildInstructionStep("6", "Select your home WiFi & enter password"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Status Card
            Card(
              elevation: 4,
              color: statusColor.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: statusColor, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(
                      isLoading ? Icons.sync : Icons.info,
                      color: statusColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // WiFi Selection Card
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select WiFi Network",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Network Selection Dropdown
                    if (!showManualInput && allNetworks.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedSSID,
                            hint: const Text("Select WiFi Network"),
                            icon: const Icon(Icons.arrow_drop_down),
                            items: allNetworks.map((String network) {
                              bool isCurrent = network == currentWiFiSSID;
                              return DropdownMenuItem<String>(
                                value: network,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.wifi,
                                      color: isCurrent ? Colors.green : Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        network,
                                        style: TextStyle(
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isCurrent
                                              ? Colors.green.shade700
                                              : Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          "Current",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                selectedSSID = newValue;
                              });
                            },
                          ),
                        ),
                      ),

                    // Manual Input Field
                    if (showManualInput)
                      TextField(
                        controller: manualSSIDController,
                        decoration: InputDecoration(
                          labelText: "WiFi Network Name (SSID)",
                          prefixIcon: const Icon(Icons.wifi, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),

                    const SizedBox(height: 15),

                    // Toggle Manual Input Button
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          showManualInput = !showManualInput;
                          if (showManualInput) {
                            manualSSIDController.clear();
                          }
                        });
                      },
                      icon: Icon(
                        showManualInput ? Icons.list : Icons.edit,
                        size: 20,
                      ),
                      label: Text(
                        showManualInput
                            ? "Select from saved networks"
                            : "Enter network name manually",
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Password Field
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "WiFi Password",
                        prefixIcon: const Icon(Icons.lock, color: Colors.orange),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _sendCredentials,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: isLoading
                            ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 15),
                            Text(
                              "Sending...",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              "Configure ESP32",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Help Text
            Card(
              elevation: 2,
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.orange.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tip: Make sure you're connected to ESP32_Config WiFi network before submitting.",
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}