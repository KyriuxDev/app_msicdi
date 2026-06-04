import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/formulario_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const AppMsicdi());
}

class AppMsicdi extends StatelessWidget {
  const AppMsicdi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reportes IMSS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1a6e2e)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _matriculaCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;

  // URL de tu servidor para validar matrícula
  static const String _urlBase = 'http://192.168.5.192/msicdi';

  Future<void> _entrar() async {
    final matricula = _matriculaCtrl.text.trim();
    if (matricula.isEmpty) {
      setState(() => _error = 'Ingresa tu matrícula');
      return;
    }

    setState(() { _cargando = true; _error = null; });

    try {
      // Validar matrícula contra tu servidor existente
      final response = await http.post(
        Uri.parse('$_urlBase/site/matriculaValida'),
        body: {'matricula': matricula},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final nombre =
              '${data[0]['Nombres']} ${data[0]['ApPaterno']} ${data[0]['ApMaterno']}';

          // Guardar sesión local
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('matricula', matricula);
          await prefs.setString('nombre', nombre);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FormularioScreen(
                matricula: matricula,
                nombreTecnico: nombre,
              ),
            ),
          );
          return;
        }
      }
      setState(() => _error = 'Matrícula no encontrada');
    } catch (e) {
      // Sin conexión: revisar si ya hay sesión guardada
      final prefs = await SharedPreferences.getInstance();
      final savedMatr = prefs.getString('matricula');
      final savedNombre = prefs.getString('nombre');

      if (savedMatr != null && savedMatr == matricula) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FormularioScreen(
              matricula: savedMatr,
              nombreTecnico: savedNombre ?? savedMatr,
            ),
          ),
        );
        return;
      }
      setState(() => _error = 'Sin conexión y matrícula no reconocida');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a6e2e),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_hospital, size: 72, color: Colors.white),
              const SizedBox(height: 12),
              const Text(
                'IMSS Oaxaca',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Soporte Técnico',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 40),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _matriculaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Matrícula',
                          prefixIcon: const Icon(Icons.badge),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorText: _error,
                        ),
                        onSubmitted: (_) => _entrar(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _entrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1a6e2e),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _cargando
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Entrar'),
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
    );
  }
}