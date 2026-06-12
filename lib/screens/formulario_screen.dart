import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/reporte.dart';
import '../models/trabajador.dart';
import '../db/database_helper.dart';
import '../services/sync_service.dart';
import '../services/directorio_service.dart';

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
  final _formKey       = GlobalKey<FormState>();
  final _db            = DatabaseHelper();
  final _sync          = SyncService();
  final _dirService    = DirectorioService();

  bool _enviando       = false;
  bool _buscando       = false;
  Trabajador? _trabajadorSeleccionado;
  List<Trabajador> _sugerencias = [];
  Timer? _debounce;

  // Controladores
  final _busquedaCtrl   = TextEditingController(); // correo o matrícula
  final _nombreCtrl     = TextEditingController(); // read-only si viene del directorio
  final _nserieCtrl     = TextEditingController();
  final _fallaCtrl      = TextEditingController();
  final _telefonoCtrl   = TextEditingController();
  final _correoCtrl     = TextEditingController();
  final _usuarioCtrl    = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _ipEquipoCtrl   = TextEditingController();
  final _deptoCtrl      = TextEditingController();

  // Estado directorio
  int    _totalDirectorio = 0;
  String _estadoDirectorio = '';

  @override
  void initState() {
    super.initState();
    _cargarEstadoDirectorio();
    _sincronizarDirectorio();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaCtrl.dispose();
    _nombreCtrl.dispose();
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

  // ─── Directorio ───────────────────────────────────────────────────────────

  Future<void> _cargarEstadoDirectorio() async {
    final total  = await _dirService.totalLocal();
    final ultima = await _dirService.ultimaSincronizacion();

    if (!mounted) return;
    setState(() {
      _totalDirectorio = total;
      if (ultima != null) {
        final diff = DateTime.now().difference(ultima);
        final label = diff.inHours < 1
            ? 'hace ${diff.inMinutes} min'
            : diff.inHours < 24
                ? 'hace ${diff.inHours}h'
                : 'hace ${diff.inDays}d';
        _estadoDirectorio = '$total trabajadores · $label';
      } else {
        _estadoDirectorio = total > 0
            ? '$total trabajadores'
            : 'Sin directorio local';
      }
    });
  }

  Future<void> _sincronizarDirectorio() async {
    final result = await _dirService.sincronizar();
    if (result.ok && result.descargados > 0) {
      await _cargarEstadoDirectorio();
    }
  }

  // ─── Autocompletado ───────────────────────────────────────────────────────

  void _onBusquedaChanged(String texto) {
    _debounce?.cancel();
    if (texto.length < 3) {
      setState(() => _sugerencias = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _buscando = true);
      final lista = await _dirService.sugerencias(texto);
      if (mounted) setState(() { _sugerencias = lista; _buscando = false; });
    });
  }

  void _seleccionarTrabajador(Trabajador t) {
    setState(() {
      _trabajadorSeleccionado = t;
      _sugerencias            = [];
      _busquedaCtrl.text      = t.correo ?? t.matricula;
      _nombreCtrl.text        = t.nombreCompleto;
      _correoCtrl.text        = t.correo ?? '';
      _telefonoCtrl.text      = t.telefono ?? t.extension ?? '';
      _deptoCtrl.text         = t.departamento ?? t.adscripcion ?? '';
    });
    FocusScope.of(context).unfocus();
  }

  void _limpiarTrabajador() {
    setState(() {
      _trabajadorSeleccionado = null;
      _sugerencias            = [];
      _busquedaCtrl.clear();
      _nombreCtrl.clear();
      _correoCtrl.clear();
      _telefonoCtrl.clear();
      _deptoCtrl.clear();
    });
  }

  // ─── Envío ────────────────────────────────────────────────────────────────

  Future<void> _guardarYEnviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final reporte = Reporte(
      matricula:        widget.matricula,
      nombreReportador: widget.nombreTecnico,
      nserie:           _nserieCtrl.text.trim(),
      falla:            _fallaCtrl.text.trim(),
      telefono:  _telefonoCtrl.text.trim().isEmpty  ? 'S/N'        : _telefonoCtrl.text.trim(),
      correo:    _correoCtrl.text.trim().isEmpty     ? 'sin@correo' : _correoCtrl.text.trim(),
      usuario:          _usuarioCtrl.text.trim(),
      contrasena:       _contrasenaCtrl.text.trim(),
      ipEquipo:         _ipEquipoCtrl.text.trim(),
      depto:            _deptoCtrl.text.trim(),
    );

    await _db.insertarReporte(reporte);

    final resultado = await _sync.sincronizar();
    setState(() => _enviando = false);

    if (!mounted) return;

    if (resultado.containsKey('sinConexion')) {
      _mostrarMensaje(
        icono: Icons.wifi_off,
        color: Colors.orange,
        titulo: 'Guardado sin conexión',
        mensaje: 'El reporte se enviará automáticamente cuando haya señal.',
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
        mensaje: 'Se enviará al servidor en cuanto haya conexión.',
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
              Navigator.of(context).pop();
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
    _limpiarTrabajador();
    _nserieCtrl.clear();
    _fallaCtrl.clear();
    _usuarioCtrl.clear();
    _contrasenaCtrl.clear();
    _ipEquipoCtrl.clear();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Reporte'),
        backgroundColor: const Color(0xFF1a6e2e),
        foregroundColor: Colors.white,
        actions: [
          // Indicador de conectividad
          StreamBuilder<ConnectivityResult>(
            stream: Connectivity().onConnectivityChanged
                .map((l) => l.isNotEmpty ? l.first : ConnectivityResult.none),
            builder: (context, snap) {
              final ok = snap.data != ConnectivityResult.none;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  ok ? Icons.wifi : Icons.wifi_off,
                  color: ok ? Colors.greenAccent : Colors.red[200],
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

              // ── Técnico ──────────────────────────────────────────────────
              _infoTecnico(),
              const SizedBox(height: 16),

              // ── Directorio ───────────────────────────────────────────────
              _bannerDirectorio(),
              const SizedBox(height: 20),

              // ── Buscar trabajador ─────────────────────────────────────────
              _seccion('Trabajador reportante'),
              _campoBusqueda(),
              if (_trabajadorSeleccionado != null) _tarjetaTrabajador(),
              const SizedBox(height: 8),

              // ── Si no hay trabajador seleccionado, mostrar campos manuales
              if (_trabajadorSeleccionado == null) ...[
                _campo(
                  controller: _nombreCtrl,
                  label: 'Nombre completo',
                  icono: Icons.person_outline,
                ),
                _campo(
                  controller: _correoCtrl,
                  label: 'Correo electrónico',
                  icono: Icons.email_outlined,
                  teclado: TextInputType.emailAddress,
                ),
                _campo(
                  controller: _telefonoCtrl,
                  label: 'Teléfono / extensión',
                  icono: Icons.phone_outlined,
                  teclado: TextInputType.phone,
                ),
                _campo(
                  controller: _deptoCtrl,
                  label: 'Departamento *',
                  icono: Icons.business_outlined,
                  requerido: true,
                ),
              ],

              const SizedBox(height: 16),

              // ── Equipo ───────────────────────────────────────────────────
              _seccion('Datos del equipo'),
              _campo(
                controller: _nserieCtrl,
                label: 'Número de serie / NNI *',
                icono: Icons.computer_outlined,
                requerido: true,
              ),
              _campo(
                controller: _ipEquipoCtrl,
                label: 'IP del equipo',
                icono: Icons.lan_outlined,
                teclado: TextInputType.number,
              ),
              _campo(
                controller: _usuarioCtrl,
                label: 'Usuario de Windows',
                icono: Icons.account_circle_outlined,
              ),
              _campo(
                controller: _contrasenaCtrl,
                label: 'Contraseña',
                icono: Icons.lock_outline,
                esContrasena: true,
              ),
              const SizedBox(height: 16),

              // ── Falla ────────────────────────────────────────────────────
              _seccion('Descripción de la falla'),
              TextFormField(
                controller: _fallaCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Describa detalladamente el problema...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: Color(0xFF1a6e2e), width: 2),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'La descripción es requerida'
                    : null,
              ),
              const SizedBox(height: 24),

              // ── Botón ────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _guardarYEnviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a6e2e),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _enviando
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(_enviando ? 'Guardando...' : 'Guardar Reporte'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets internos ─────────────────────────────────────────────────────

  Widget _infoTecnico() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFe8f5e9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Color(0xFF1a6e2e)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.nombreTecnico} · ${widget.matricula}',
                style: const TextStyle(
                    color: Color(0xFF1a6e2e), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

  Widget _bannerDirectorio() => GestureDetector(
        onTap: () async {
          setState(() => _estadoDirectorio = 'Actualizando...');
          await _sincronizarDirectorio();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _totalDirectorio > 0
                ? const Color(0xFFe3f2fd)
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _totalDirectorio > 0
                  ? const Color(0xFF90caf9)
                  : Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _totalDirectorio > 0
                    ? Icons.people_alt_outlined
                    : Icons.sync_problem_outlined,
                size: 18,
                color: _totalDirectorio > 0
                    ? const Color(0xFF1565c0)
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Directorio: $_estadoDirectorio',
                  style: TextStyle(
                    fontSize: 12,
                    color: _totalDirectorio > 0
                        ? const Color(0xFF1565c0)
                        : Colors.orange.shade800,
                  ),
                ),
              ),
              Icon(Icons.refresh,
                  size: 16,
                  color: _totalDirectorio > 0
                      ? const Color(0xFF1565c0)
                      : Colors.orange),
            ],
          ),
        ),
      );

  Widget _campoBusqueda() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _busquedaCtrl,
            onChanged: _onBusquedaChanged,
            decoration: InputDecoration(
              labelText: 'Buscar por correo o matrícula',
              hintText: 'juan.perez@imss.gob.mx  ó  99213800',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF1a6e2e)),
              suffixIcon: _busquedaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _limpiarTrabajador,
                    )
                  : _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1a6e2e), width: 2),
              ),
            ),
          ),

          // Dropdown de sugerencias
          if (_sugerencias.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: const Color(0xFF1a6e2e).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3))
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sugerencias.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 56),
                itemBuilder: (_, i) {
                  final t = _sugerencias[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor:
                          const Color(0xFF1a6e2e).withOpacity(0.1),
                      child: Text(
                        t.nombreCompleto.isNotEmpty
                            ? t.nombreCompleto[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Color(0xFF1a6e2e),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(t.nombreCompleto,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      t.correo ?? t.matricula,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    trailing: t.departamento != null
                        ? Text(
                            t.departamento!,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () => _seleccionarTrabajador(t),
                  );
                },
              ),
            ),

          if (_totalDirectorio == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sin directorio local — ingresa los datos manualmente',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
              ),
            ),
          const SizedBox(height: 12),
        ],
      );

  Widget _tarjetaTrabajador() {
    final t = _trabajadorSeleccionado!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFe8f5e9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF81c784)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF1a6e2e), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.nombreCompleto,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a6e2e)),
                ),
              ),
              GestureDetector(
                onTap: _limpiarTrabajador,
                child: const Icon(Icons.close,
                    size: 18, color: Color(0xFF1a6e2e)),
              ),
            ],
          ),
          if (t.correo != null) ...[
            const SizedBox(height: 4),
            Text(t.correo!,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
          if (t.departamento != null) ...[
            const SizedBox(height: 2),
            Text(t.departamento!,
                style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
          if (t.telefono != null || t.extension != null) ...[
            const SizedBox(height: 2),
            Text(
              [t.telefono, t.extension]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' · '),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          titulo,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a6e2e)),
        ),
      );

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    bool requerido = false,
    bool esContrasena = false,
    TextInputType teclado = TextInputType.text,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          obscureText: esContrasena,
          keyboardType: teclado,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icono, color: const Color(0xFF1a6e2e)),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF1a6e2e), width: 2),
            ),
          ),
          validator: requerido
              ? (v) => (v == null || v.trim().isEmpty)
                  ? 'Este campo es requerido'
                  : null
              : null,
        ),
      );
}