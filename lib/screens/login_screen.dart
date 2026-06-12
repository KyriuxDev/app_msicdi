import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'formulario_screen.dart';

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

  bool    _cargando = false;
  bool    _verPass  = false;
  String? _error;

  static const _urlBase = 'http://192.168.5.192/msicdi';

  @override
  void dispose() {
    _matriculaCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final matricula = _matriculaCtrl.text.trim();
    if (matricula.isEmpty) {
      setState(() => _error = 'Ingresa tu matrícula');
      return;
    }
    setState(() { _cargando = true; _error = null; });
    try {
      final response = await http.post(
        Uri.parse('$_urlBase/site/matriculaValida'),
        body: {'matricula': matricula},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final nombre =
              '${data[0]['Nombres']} ${data[0]['ApPaterno']} ${data[0]['ApMaterno']}';
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
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('matricula');
      if (saved != null && saved == matricula) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FormularioScreen(
              matricula: saved,
              nombreTecnico: prefs.getString('nombre') ?? saved,
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
    final size   = MediaQuery.of(context).size;
    final ancho  = size.width;
    final alto   = size.height;

    // Escala proporcional: todo se calcula como % del ancho
    // En teléfono (360dp) → factores pequeños
    // En Pixel Tablet (~800dp portrait) → factores grandes automáticamente
    final escala = ancho / 400; // 400dp es la base de referencia

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: SizedBox(
          width:  ancho,
          height: alto,
          child: Center(
            child: SingleChildScrollView(
              child: SizedBox(
                // La tarjeta ocupa 85% del ancho, máximo 700dp
                width: (ancho * 0.85).clamp(280, 700),
                child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 40 * escala.clamp(1, 1.8),
                  vertical:   40 * escala.clamp(1, 1.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── Logo ──────────────────────────────────────────────
                    Column(
                      children: [
                        Image.asset(
                          'assets/images/logo_imss.png',
                          width:  100 * escala.clamp(1, 1.8),
                          height: 100 * escala.clamp(1, 1.8),
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 16 * escala.clamp(1, 1.5)),
                        Text(
                          'Tu Perfil IMSS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:      26 * escala.clamp(1, 1.6),
                            fontWeight:    FontWeight.bold,
                            color:         const Color(0xFF333333),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6 * escala.clamp(1, 1.5)),
                        Text(
                          'Inicia sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize:   14 * escala.clamp(1, 1.6),
                            fontWeight: FontWeight.w500,
                            color:      const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32 * escala.clamp(1, 1.5)),

                    // ── Matrícula ─────────────────────────────────────────
                    Text(
                      'Matrícula',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize:   13 * escala.clamp(1, 1.6),
                        color:      const Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 6 * escala.clamp(1, 1.4)),
                    TextField(
                      controller:   _matriculaCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 14 * escala.clamp(1, 1.6)),
                      decoration:   _deco(
                        'Ingresa tu matrícula',
                        escala: escala,
                      ).copyWith(errorText: _error),
                      onSubmitted: (_) => _entrar(),
                    ),

                    SizedBox(height: 20 * escala.clamp(1, 1.4)),

                    // ── Contraseña ────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Contraseña',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize:   13 * escala.clamp(1, 1.6),
                            color:      const Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6 * escala.clamp(1, 1.4)),
                    TextField(
                      controller:  _passCtrl,
                      obscureText: !_verPass,
                      style: TextStyle(fontSize: 14 * escala.clamp(1, 1.6)),
                      decoration: _deco(
                        'Ingresa tu contraseña',
                        escala: escala,
                        suffix: IconButton(
                          icon: Icon(
                            _verPass
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                            size:  20 * escala.clamp(1, 1.6),
                          ),
                          onPressed: () =>
                              setState(() => _verPass = !_verPass),
                        ),
                      ),
                      onSubmitted: (_) => _entrar(),
                    ),

                    SizedBox(height: 28 * escala.clamp(1, 1.5)),

                    // ── Botón ─────────────────────────────────────────────
                    SizedBox(
                      height: 50 * escala.clamp(1, 1.6),
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _entrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _verde,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                6 * escala.clamp(1, 1.5)),
                          ),
                          elevation: 3,
                          textStyle: TextStyle(
                            fontSize:   16 * escala.clamp(1, 1.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _cargando
                            ? CircularProgressIndicator(
                                color:       Colors.white,
                                strokeWidth: 2 * escala.clamp(1, 1.5),
                              )
                            : const Text('Iniciar sesión'),
                      ),
                    ),

                    SizedBox(height: 24 * escala.clamp(1, 1.4)),

                    // ── Footer ───────────────────────────────────────────
                    SizedBox(height: 10 * escala.clamp(1, 1.4)),
                    Center(
                      child: GestureDetector(
                        onTap: () {},
                        child: Text(
                          'Aviso de privacidad',
                          style: TextStyle(
                            fontSize: 12 * escala.clamp(1, 1.6),
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
    ));
  }

  // ── Decoración de inputs ───────────────────────────────────────────────────
  InputDecoration _deco(String hint, {required double escala, Widget? suffix}) {
    return InputDecoration(
      hintText:   hint,
      hintStyle:  TextStyle(
        color:    const Color(0xFF9CA3AF),
        fontSize: 14 * escala.clamp(1, 1.6),
      ),
      filled:     true,
      fillColor:  _fondo,
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6 * escala.clamp(1, 1.5)),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6 * escala.clamp(1, 1.5)),
        borderSide: const BorderSide(color: _verde, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6 * escala.clamp(1, 1.5)),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6 * escala.clamp(1, 1.5)),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16 * escala.clamp(1, 1.5),
        vertical:   14 * escala.clamp(1, 1.5),
      ),
    );
  }
}