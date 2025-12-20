import 'package:flutter/material.dart';
import 'dart:async';

import 'package:fypapp/screens/band/home_screen.dart';
import 'package:fypapp/screens/home/home_screen.dart'; // apni home screen import karo

class ConnectBandScreen extends StatefulWidget {
  const ConnectBandScreen({super.key});

  @override
  State<ConnectBandScreen> createState() => _ConnectBandScreenState();
}

class _ConnectBandScreenState extends State<ConnectBandScreen> {
  bool _isConnecting = false;

  void _connectBand() {
    setState(() {
      _isConnecting = true;
    });

    // 3 second ka delay simulate
    Timer(const Duration(seconds: 3), () {
      setState(() {
        _isConnecting = false;
      });
      // Navigate to HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text("Connect Your Band"),
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon placeholder
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withOpacity(0.1),
              ),
              padding: const EdgeInsets.all(24),
              child: const Icon(
                Icons.watch,
                size: 100,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Please connect your wrist band first",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Button / Loading widget
            _isConnecting
                ? Column(
              children: const [
                CircularProgressIndicator(
                  color: Colors.blue, // loading circle blue
                ),
                SizedBox(height: 10),
                Text(
                  "Connecting...",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            )
                : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, // button red
                padding: const EdgeInsets.symmetric(
                    horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _connectBand,
              icon: const Icon(Icons.bluetooth, color: Colors.black),
              label: const Text(
                "Connect Band",
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
