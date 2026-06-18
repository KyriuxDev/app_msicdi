// lib/screens/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/imss_qr_service.dart';

/// Pantalla de escaneo QR IMSS.
/// Retorna un Map<String,String> con los campos descifrados,
/// o null si el usuario canceló.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _ctrl    = MobileScannerController();
  bool  _leido   = false;
  String _estado = 'Apunta al código QR del equipo';

  static const _verde = Color(0xFF1a6e2e);
  static const _rojo  = Color(0xFFd32f2f);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_leido) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    final datos = ImssQrService.descifrar(raw);

    if (datos == null) {
      // QR no es IMSS — mostrar error y seguir escaneando
      setState(() => _estado = '⚠️ QR no reconocido, intenta otro');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _estado = 'Apunta al código QR del equipo');
      });
      return;
    }

    setState(() { _leido = true; _estado = '✅ Datos leídos correctamente'; });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Navigator.of(context).pop(datos);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear QR del Equipo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Linterna',
            onPressed: () => _ctrl.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Cámara ──────────────────────────────────────────────────
          MobileScanner(
            controller: _ctrl,
            onDetect:   _onDetect,
          ),

          // ── Marco de enfoque ─────────────────────────────────────────
          Center(
            child: Container(
              width:  260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _leido ? Colors.green : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // ── Esquinas decorativas ──────────────────────────────────────
          Center(child: _esquinas(_leido ? Colors.green : _verde)),

          // ── Texto de estado ───────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _estado,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // ── Indicador de éxito ────────────────────────────────────────
          if (_leido)
            const Center(
              child: Icon(Icons.check_circle, color: Colors.green, size: 80),
            ),
        ],
      ),
    );
  }

  Widget _esquinas(Color color) {
    const size   = 260.0;
    const arm    = 28.0;
    const stroke = 4.0;
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(painter: _CornerPainter(color, arm, stroke)),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double arm, stroke;
  _CornerPainter(this.color, this.arm, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = color
      ..strokeWidth = stroke
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    final r = 16.0;
    // Esquina superior-izquierda
    canvas.drawLine(Offset(r, 0), Offset(arm, 0), p);
    canvas.drawLine(Offset(0, r), Offset(0, arm), p);
    // Esquina superior-derecha
    canvas.drawLine(Offset(size.width - arm, 0), Offset(size.width - r, 0), p);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, arm), p);
    // Esquina inferior-izquierda
    canvas.drawLine(Offset(0, size.height - arm), Offset(0, size.height - r), p);
    canvas.drawLine(Offset(r, size.height), Offset(arm, size.height), p);
    // Esquina inferior-derecha
    canvas.drawLine(Offset(size.width, size.height - arm), Offset(size.width, size.height - r), p);
    canvas.drawLine(Offset(size.width - arm, size.height), Offset(size.width - r, size.height), p);
  }

  @override
  bool shouldRepaint(_) => false;
}