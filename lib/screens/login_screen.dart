import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'formulario_screen.dart';

// ─── Colores globales del archivo ─────────────────────────────────────────────
const _verde    = Color(0xFF588b22);
const _azulLink = Color(0xFF2c4b8b);
const _fondo    = Color(0xFFF7F8FA);

// ─── Pantalla principal ───────────────────────────────────────────────────────
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 428),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  const _Logo(),
                  const SizedBox(height: 40),
                  _Formulario(
                    matriculaCtrl: _matriculaCtrl,
                    passCtrl:      _passCtrl,
                    verPass:       _verPass,
                    error:         _error,
                    cargando:      _cargando,
                    onTogglePass:  () => setState(() => _verPass = !_verPass),
                    onEntrar:      _entrar,
                  ),
                  const SizedBox(height: 32),
                  const _Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/logo_imss.png',
          width: 120,
          height: 120,
          fit: BoxFit.contain,   // respeta proporciones sin recortar
        ),
        const SizedBox(height: 24),
        const Text(
          'Inicia Sesión',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold,
            color: Color(0xFF333333), letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ─── Painter del logo ─────────────────────────────────────────────────────────
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _verde..style = PaintingStyle.fill;
    final s = size.width / 100;

    canvas.drawCircle(Offset(50 * s, 25 * s), 10 * s, paint);

    canvas.drawPath(
      Path()
        ..moveTo(50 * s, 40 * s)
        ..lineTo(25 * s, 60 * s)
        ..lineTo(35 * s, 75 * s)
        ..lineTo(50 * s, 65 * s)
        ..lineTo(65 * s, 75 * s)
        ..lineTo(75 * s, 60 * s)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _Formulario extends StatelessWidget {
  final TextEditingController matriculaCtrl;
  final TextEditingController passCtrl;
  final bool     verPass;
  final String?  error;
  final bool     cargando;
  final VoidCallback onTogglePass;
  final VoidCallback onEntrar;

  const _Formulario({
    required this.matriculaCtrl,
    required this.passCtrl,
    required this.verPass,
    required this.error,
    required this.cargando,
    required this.onTogglePass,
    required this.onEntrar,
  });

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
    filled: true,
    fillColor: _fondo,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: _verde, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Matrícula ──
        const Text('Matrícula',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                color: Color(0xFF333333))),
        const SizedBox(height: 6),
        TextField(
          controller: matriculaCtrl,
          keyboardType: TextInputType.number,
          decoration: _deco('Ingresa tu matrícula').copyWith(errorText: error),
          onSubmitted: (_) => onEntrar(),
        ),
        const SizedBox(height: 20),

        // ── Contraseña ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Contraseña',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: Color(0xFF333333))),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: passCtrl,
          obscureText: !verPass,
          decoration: _deco('Ingresa tu contraseña').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                verPass ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey, size: 20,
              ),
              onPressed: onTogglePass,
            ),
          ),
          onSubmitted: (_) => onEntrar(),
        ),
        const SizedBox(height: 32),

        // ── Botón ──
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: cargando ? null : onEntrar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              elevation: 3,
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            child: cargando
                ? const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)
                : const Text('Iniciar sesión'),
          ),
        ),
      ],
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text('Aviso de privacidad',
            style: TextStyle(fontSize: 12, color: _azulLink)),
        const SizedBox(height: 24),
        Container(
          width: 128, height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}