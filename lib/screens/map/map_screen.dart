import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // abhi sirf UI hai
            // baad me yahan map API lagana
          },
          child: const Text("Open Map"),
        ),
      ),
    );
  }
}
