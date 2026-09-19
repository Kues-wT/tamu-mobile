import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const TamuApp());
}

class TamuApp extends StatelessWidget {
  const TamuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TAMU',
      debugShowCheckedModeBanner: false,
      theme: buildTamuTheme(),
      home: const LoginScreen(),
    );
  }
}
