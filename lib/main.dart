import 'package:flutter/material.dart';
import 'package:fypapp/screens/band/band_screen.dart';

// sab screens import karo
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/register/register_screen.dart';
import 'screens/users/user_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/map/map_screen.dart';
import 'screens/wifi_config/wifi_config_screen.dart';



void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FYP App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/add-user': (context) => const AddUserScreen(),
        '/history': (context) => const HistoryScreen(),
        '/map': (context) => const MapScreen(),
      },
    );
  }
}
