import 'package:flutter/material.dart';

class AddUserScreen extends StatelessWidget {
  const AddUserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add User")),
      body: const Center(
        child: Text("Add User Screen"),
      ),
    );
  }
}
