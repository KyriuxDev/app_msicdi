import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import 'home_screen.dart';

const _verde    = Color(0xFF588b22);
const _azulLink = Color(0xFF2c4b8b);
const _fondo    = Color(0xFFF7F8FA);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _matriculaCtrl = TextEditingController();
  final _passCtrl      = TextEditingController();

  bool    _cargando    = false;
  bool    _verPass     = false;
  String? _errorGeneral;
  String? _errorPass;

  @override
  void dispose() {
    _matriculaCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final matricula  = _matriculaCtrl.text.trim();
    final contrasena = _passCtrl.text;

    // Validación local rápida
    if (matricula.isEmpty) {
      setState(() { _errorGeneral = 'Ingresa tu matrícula'; _errorPass = null; });
      return;
    }
    if (contrasena.isEmpty) {
      setState(() { _errorGeneral = null; _errorPass = 'Ingresa tu contraseña'; });
      return;
    }

    setState(() { _cargando = true; _errorGeneral = null; _errorPass = null; });

    try {
      final response = await http.post(
        Uri.parse(AppConfig.urlLogin),
        body: {
          'matricula':  matricula,
          'contrasena': contrasena,         // ← ahora se manda al servidor
        },
      ).timeout(AppConfig.timeoutCorto);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // El endpoint devuelve lista vacía o error si la contraseña no coincide
        if (data is List && data.isNotEmpty) {
          final nombre =
              '${data[0]['Nombres']} ${data[0]['ApPaterno']} ${data[0]['ApMaterno']}';
          await _guardarSesion(matricula, nombre, contrasena);
          if (!mounted) return;
          _irAHome(matricula, nombre);
          return;
        }

        // Si data['error'] o lista vacía → credenciales incorrectas
        setState(() => _errorGeneral = 'Matrícula o contraseña incorrectos');
      } else {
        setState(() => _errorGeneral = 'Error del servidor (${response.statusCode})');
      }
    } catch (_) {
      // Sin red → intento con sesión guardada
      final prefs    = await SharedPreferences.getInstance();
      final savedMat = prefs.getString('matricula');
      final savedPass= prefs.getString('pass_hash'); // guardamos hash, no plain

      if (savedMat == matricula && savedPass == _hashSimple(contrasena)) {
        if (!mounted) return;
        _irAHome(savedMat!, prefs.getString('nombre') ?? savedMat);
        return;
      }
      setState(() => _errorGeneral = 'Sin conexión y credenciales no reconocidas');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Hash muy simple (XOR + base64) para no guardar la contraseña en texto plano.
  /// En producción usa bcrypt o similar, pero para SharedPreferences local
  /// con acceso ya a la app es suficiente como capa básica.
  String _hashSimple(String pass) {
    final bytes = pass.codeUnits.map((c) => c ^ 0x5A).toList();
    return base64Encode(bytes);
  }

  Future<void> _guardarSesion(
      String matricula, String nombre, String contrasena) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('matricula', matricula);
    await prefs.setString('nombre',    nombre);
    await prefs.setString('pass_hash', _hashSimple(contrasena));
  }

  void _irAHome(String matricula, String nombre) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(matricula: matricula, nombreTecnico: nombre),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ancho  = MediaQuery.of(context).size.width;
    final escala = ancho / 400;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: SizedBox(
              width: (ancho * 0.85).clamp(280, 700),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (40 * escala).clamp(40, 72),
                  vertical:   (40 * escala).clamp(40, 72),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // Logo
                    Column(
                      children: [
                        Image.asset(
                          'assets/images/logo_imss.png',
                          width:  (100 * escala).clamp(100, 180),
                          height: (100 * escala).clamp(100, 180),
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: (16 * escala).clamp(16, 24)),
                        Text(
                          'Tu Perfil IMSS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:      (26 * escala).clamp(26, 42),
                            fontWeight:    FontWeight.bold,
                            color:         const Color(0xFF333333),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: (6 * escala).clamp(6, 10)),
                        Text(
                          'Inicia sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:   (14 * escala).clamp(14, 22),
                            fontWeight: FontWeight.w500,
                            color:      const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: (32 * escala).clamp(32, 48)),

                    // Matrícula
                    _label('Matrícula', escala),
                    SizedBox(height: (6 * escala).clamp(6, 10)),
                    TextField(
                      controller:   _matriculaCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: (14 * escala).clamp(14, 22)),
                      decoration: _deco('Ingresa tu matrícula', escala)
                          .copyWith(errorText: _errorGeneral),
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),

                    SizedBox(height: (20 * escala).clamp(20, 30)),

                    // Contraseña
                    _label('Contraseña', escala),
                    SizedBox(height: (6 * escala).clamp(6, 10)),
                    TextField(
                      controller:  _passCtrl,
                      obscureText: !_verPass,
                      style: TextStyle(fontSize: (14 * escala).clamp(14, 22)),
                      decoration: _deco('Ingresa tu contraseña', escala,
                        suffix: IconButton(
                          icon: Icon(
                            _verPass ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                            size:  (20 * escala).clamp(20, 28),
                          ),
                          onPressed: () => setState(() => _verPass = !_verPass),
                        ),
                      ).copyWith(errorText: _errorPass),
                      onSubmitted: (_) => _entrar(),
                    ),

                    SizedBox(height: (28 * escala).clamp(28, 44)),

                    // Botón
                    SizedBox(
                      height: (50 * escala).clamp(50, 72),
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _entrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _verde,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          elevation: 3,
                          textStyle: TextStyle(
                            fontSize:   (16 * escala).clamp(16, 24),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _cargando
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)
                            : const Text('Iniciar sesión'),
                      ),
                    ),

                    SizedBox(height: (24 * escala).clamp(24, 36)),

                    // Aviso de privacidad
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Text(
                          'Aviso de privacidad',
                          style: TextStyle(
                            fontSize: (12 * escala).clamp(12, 18),
                            color:    _azulLink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String texto, double escala) => Text(
        texto,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize:   (13 * escala).clamp(13, 20),
          color:      const Color(0xFF333333),
        ),
      );

  InputDecoration _deco(String hint, double escala, {Widget? suffix}) =>
      InputDecoration(
        hintText:   hint,
        hintStyle:  TextStyle(
          color:    const Color(0xFF9CA3AF),
          fontSize: (14 * escala).clamp(14, 22),
        ),
        filled:     true,
        fillColor:  _fondo,
        suffixIcon: suffix,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: _verde, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: (16 * escala).clamp(16, 24),
          vertical:   (14 * escala).clamp(14, 20),
        ),
      );
}