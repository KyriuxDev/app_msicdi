import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'services/sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Escucha cambios de red en segundo plano durante toda la sesión.
  // Cuando el dispositivo recupere WiFi o datos, enviará los pendientes
  // automáticamente sin que el usuario tenga que hacer nada.
  SyncService().iniciarEscuchaConectividad();

  runApp(const AppMsicdi());
}

class AppMsicdi extends StatelessWidget {
  const AppMsicdi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                     'MSICDI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF588b22)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}