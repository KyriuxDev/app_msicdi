import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() => runApp(const AppMsicdi());

class AppMsicdi extends StatelessWidget {
  const AppMsicdi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF588b22)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}