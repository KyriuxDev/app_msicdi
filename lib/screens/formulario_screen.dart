import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/reporte.dart';
import '../db/database_helper.dart';
import '../services/sync_service.dart';

class FormularioScreen extends StatefulWidget {
  final String matricula;
  final String nombreTecnico;

  const FormularioScreen({
    super.key,
    required this.matricula,
    required this.nombreTecnico,
  });

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper();
  final _sync = SyncService();
  bool _enviando = false;

  // Controladores de texto
  final _nserieCtrl    = TextEditingController();
  final _fallaCtrl     = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _correoCtrl    = TextEditingController();
  final _usuarioCtrl   = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _ipEquipoCtrl  = TextEditingController();
  final _deptoCtrl     = TextEditingController();

  @override
  void dispose() {
    _nserieCtrl.dispose();
    _fallaCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _usuarioCtrl.dispose();
    _contrasenaCtrl.dispose();
    _ipEquipoCtrl.dispose();
    _deptoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarYEnviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);

    // Crear el reporte
    final reporte = Reporte(
      matricula:        widget.matricula,
      nombreReportador: widget.nombreTecnico,
      nserie:           _nserieCtrl.text.trim(),
      falla:            _fallaCtrl.text.trim(),
      telefono:         _telefonoCtrl.text.trim().isEmpty ? 'S/N' : _telefonoCtrl.text.trim(),
      correo:           _correoCtrl.text.trim().isEmpty ? 'sin@correo' : _correoCtrl.text.trim(),
      usuario:          _usuarioCtrl.text.trim(),
      contrasena:       _contrasenaCtrl.text.trim(),
      ipEquipo:         _ipEquipoCtrl.text.trim(),
      depto:            _deptoCtrl.text.trim(),
    );

    // Guardar localmente primero (siempre)
    await _db.insertarReporte(reporte);

    // Intentar sincronizar si hay conexión
    final resultado = await _sync.sincronizar();
    setState(() => _enviando = false);

    if (!mounted) return;

    if (resultado.containsKey('sinConexion')) {
      _mostrarMensaje(
        icono: Icons.wifi_off,
        color: Colors.orange,
        titulo: 'Guardado sin conexión',
        mensaje: 'El reporte se envíará automáticamente cuando haya señal.',
      );
    } else if (resultado['enviados']! > 0) {
      _mostrarMensaje(
        icono: Icons.check_circle,
        color: Colors.green,
        titulo: '¡Reporte enviado!',
        mensaje: 'El reporte llegó al servidor correctamente.',
      );
    } else {
      _mostrarMensaje(
        icono: Icons.cloud_queue,
        color: Colors.orange,
        titulo: 'Guardado localmente',
        mensaje: 'Se intentará enviar al servidor en cuanto haya conexión.',
      );
    }
  }

  void _mostrarMensaje({
    required IconData icono,
    required Color color,
    required String titulo,
    required String mensaje,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(icono, color: color, size: 48),
        title: Text(titulo, textAlign: TextAlign.center),
        content: Text(mensaje, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // cierra dialog
              _limpiarFormulario();
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _nserieCtrl.clear();
    _fallaCtrl.clear();
    _telefonoCtrl.clear();
    _correoCtrl.clear();
    _usuarioCtrl.clear();
    _contrasenaCtrl.clear();
    _ipEquipoCtrl.clear();
    _deptoCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Reporte'),
        backgroundColor: const Color(0xFF1a6e2e),
        foregroundColor: Colors.white,
        actions: [
          // Indicador de conexión en tiempo real
          StreamBuilder<ConnectivityResult>(
            stream: Connectivity().onConnectivityChanged.map(
              (list) => list.isNotEmpty ? list.first : ConnectivityResult.none,
            ),
            builder: (context, snapshot) {
              final conectado = snapshot.data != ConnectivityResult.none;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  conectado ? Icons.wifi : Icons.wifi_off,
                  color: conectado ? Colors.greenAccent : Colors.red[200],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info del técnico
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFe8f5e9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Color(0xFF1a6e2e)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.nombreTecnico} — ${widget.matricula}',
                        style: const TextStyle(
                          color: Color(0xFF1a6e2e),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _seccion('Datos del equipo'),
              _campo(
                controller: _nserieCtrl,
                label: 'Número de serie / NNI *',
                icono: Icons.computer,
                requerido: true,
              ),
              _campo(
                controller: _ipEquipoCtrl,
                label: 'IP del equipo',
                icono: Icons.lan,
                teclado: TextInputType.number,
              ),
              _campo(
                controller: _usuarioCtrl,
                label: 'Usuario de Windows',
                icono: Icons.account_circle,
              ),
              _campo(
                controller: _contrasenaCtrl,
                label: 'Contraseña',
                icono: Icons.lock,
                esContrasena: true,
              ),
              const SizedBox(height: 8),

              _seccion('Datos del reportador'),
              _campo(
                controller: _deptoCtrl,
                label: 'Departamento *',
                icono: Icons.business,
                requerido: true,
              ),
              _campo(
                controller: _telefonoCtrl,
                label: 'Teléfono',
                icono: Icons.phone,
                teclado: TextInputType.phone,
              ),
              _campo(
                controller: _correoCtrl,
                label: 'Correo electrónico',
                icono: Icons.email,
                teclado: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),

              _seccion('Descripción de la falla'),
              TextFormField(
                controller: _fallaCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Describa detalladamente el problema...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1a6e2e), width: 2),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'La descripción es requerida' : null,
              ),
              const SizedBox(height: 24),

              // Botón enviar
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _guardarYEnviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a6e2e),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_enviando ? 'Guardando...' : 'Guardar Reporte'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1a6e2e),
        ),
      ),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    bool requerido = false,
    bool esContrasena = false,
    TextInputType teclado = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        obscureText: esContrasena,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icono, color: const Color(0xFF1a6e2e)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1a6e2e), width: 2),
          ),
        ),
        validator: requerido
            ? (v) => (v == null || v.trim().isEmpty) ? 'Este campo es requerido' : null
            : null,
      ),
    );
  }
}