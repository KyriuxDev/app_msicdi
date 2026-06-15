import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../models/reporte.dart';
import '../models/trabajador.dart';
import '../models/personal.dart';
import '../db/database_helper.dart';
import '../services/sync_service.dart';
import '../services/directorio_service.dart';
import '../services/personal_service.dart';

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
  final _formKey    = GlobalKey<FormState>();
  final _db         = DatabaseHelper();
  final _sync       = SyncService();
  final _dirService = DirectorioService();
  final _perService = PersonalService();

  bool _enviando  = false;
  bool _buscando  = false;

  // ── Directorio (búsqueda por correo/nombre) ────────────────────────────────
  Trabajador? _trabajadorSeleccionado;
  List<Trabajador> _sugerencias = [];
  Timer? _debounce;

  // ── Personal (autorellenado por matrícula) ─────────────────────────────────
  Personal? _personalEncontrado;
  bool _buscandoMatricula = false;
  Timer? _debounceMatricula;

  // ── Checkboxes ──────────────────────────────────────────────────────────────
  bool _sinMatricula = false;
  bool _sinCorreo    = false;

  // ── Adjuntos ────────────────────────────────────────────────────────────────
  final List<File?> _adjuntos = [null, null, null];

  // ── Controladores ──────────────────────────────────────────────────────────
  final _matriculaCtrl  = TextEditingController();
  final _nserieCtrl     = TextEditingController();
  final _correoCtrl     = TextEditingController();
  final _telefonoCtrl   = TextEditingController();
  final _usuarioCtrl    = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  final _ipEquipoCtrl   = TextEditingController();
  final _deptoCtrl      = TextEditingController();
  final _fallaCtrl      = TextEditingController();
  final _busquedaCtrl   = TextEditingController();
  final _nombreCtrl     = TextEditingController(); // nombre manual si no hay match

  String _estadoDirectorio = '';
  String _estadoPersonal   = '';

  static const _verde = Color(0xFF1a6e2e);
  static const _azul  = Color(0xFF1565c0);
  static const _rojo  = Color(0xFFd32f2f);

  @override
  void initState() {
    super.initState();
    _cargarEstadoDirectorio();
    _cargarEstadoPersonal();
    _sincronizarDirectorio();
    _sincronizarPersonal();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounceMatricula?.cancel();
    for (final c in [
      _matriculaCtrl, _nserieCtrl, _correoCtrl, _telefonoCtrl,
      _usuarioCtrl, _contrasenaCtrl, _ipEquipoCtrl, _deptoCtrl,
      _fallaCtrl, _busquedaCtrl, _nombreCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Estado directorio / personal ─────────────────────────────────────────

  Future<void> _cargarEstadoDirectorio() async {
    final total  = await _dirService.totalLocal();
    final ultima = await _dirService.ultimaSincronizacion();
    if (!mounted) return;
    setState(() {
      if (ultima != null) {
        final diff  = DateTime.now().difference(ultima);
        final label = diff.inHours < 1
            ? 'hace ${diff.inMinutes} min'
            : diff.inHours < 24
                ? 'hace ${diff.inHours}h'
                : 'hace ${diff.inDays}d';
        _estadoDirectorio = '$total contactos · $label';
      } else {
        _estadoDirectorio =
            total > 0 ? '$total contactos' : 'Sin directorio local';
      }
    });
  }

  Future<void> _cargarEstadoPersonal() async {
    final total = await _perService.totalLocal();
    if (!mounted) return;
    setState(() {
      _estadoPersonal = total > 0 ? '$total empleados en BD local' : '';
    });
  }

  Future<void> _sincronizarDirectorio() async {
    final result = await _dirService.sincronizar();
    if (result.ok && result.descargados > 0) await _cargarEstadoDirectorio();
  }

  Future<void> _sincronizarPersonal() async {
    final result = await _perService.sincronizar();
    if (result.ok && result.descargados > 0) await _cargarEstadoPersonal();
  }

  // ─── Búsqueda por matrícula (personal) ────────────────────────────────────

  void _onMatriculaChanged(String texto) {
    // Limpiamos match anterior si el usuario borra
    if (_personalEncontrado != null) {
      setState(() => _personalEncontrado = null);
    }

    if (_sinMatricula) return;

    _debounceMatricula?.cancel();

    // Solo buscar cuando la matrícula tenga al menos 6 dígitos
    if (texto.trim().length < 6) return;

    _debounceMatricula = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _buscandoMatricula = true);

      final personal = await _perService.buscarPorMatricula(texto.trim());

      if (!mounted) return;
      setState(() => _buscandoMatricula = false);

      if (personal != null) {
        _aplicarDatosPersonal(personal);
      } else {
        // Sin match: limpiar campos autorellenados (excepto la matrícula)
        _limpiarAutorelleno();
      }
    });
  }

  void _aplicarDatosPersonal(Personal p) {
    setState(() => _personalEncontrado = p);

    // Nombre completo → campo manual de nombre
    _nombreCtrl.text = p.nombreCompleto;

    // Si el join con directorio trajo datos extra, rellenarlos también
    if (p.correo != null && p.correo!.isNotEmpty) {
      _correoCtrl.text = p.correo!;
      setState(() => _sinCorreo = false);
    } else {
      // Sin correo en directorio → activar checkbox automáticamente
      setState(() => _sinCorreo = true);
      _correoCtrl.clear();
    }

    if (p.telefono != null && p.telefono!.isNotEmpty) {
      _telefonoCtrl.text = p.telefono!;
    } else if (p.extension != null && p.extension!.isNotEmpty) {
      _telefonoCtrl.text = p.extension!;
    }

    if (p.departamento != null && p.departamento!.isNotEmpty) {
      _deptoCtrl.text = p.departamento!;
    } else if (p.adscripcion != null && p.adscripcion!.isNotEmpty) {
      _deptoCtrl.text = p.adscripcion!;
    }

    // Limpiar búsqueda de directorio si ya tenemos datos de personal
    if (_trabajadorSeleccionado != null) _limpiarTrabajador();
  }

  void _limpiarAutorelleno() {
    setState(() => _personalEncontrado = null);
    _nombreCtrl.clear();
    _correoCtrl.clear();
    _telefonoCtrl.clear();
    _deptoCtrl.clear();
    setState(() => _sinCorreo = false);
  }

  // ─── Búsqueda directorio (por correo/nombre) ──────────────────────────────

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
    });
    // Solo limpiar correo/tel/depto si no vienen de personal
    if (_personalEncontrado == null) {
      _correoCtrl.clear();
      _telefonoCtrl.clear();
      _deptoCtrl.clear();
    }
  }

  // ─── Fotos ────────────────────────────────────────────────────────────────

  Future<void> _tomarFoto(int index) async {
    final picker = ImagePicker();
    final foto   = await picker.pickImage(
      source:       ImageSource.camera,
      imageQuality: 80,
    );
    if (foto != null) {
      setState(() => _adjuntos[index] = File(foto.path));
    }
  }

  // ─── Guardar y enviar ─────────────────────────────────────────────────────

  Future<void> _guardarYEnviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    final rutasAdjuntos = _adjuntos
        .where((f) => f != null)
        .map((f) => f!.path)
        .toList();

    // Nombre: si encontramos en personal usamos ese; si no, el campo manual
    final nombreReportador = _personalEncontrado != null
        ? _personalEncontrado!.nombreCompleto
        : _nombreCtrl.text.trim();

    final reporte = Reporte(
      matricula: _sinMatricula ? 'SIN_MATRICULA' : _matriculaCtrl.text.trim(),
      nombreReportador: widget.nombreTecnico,
      nserie:    _nserieCtrl.text.trim(),
      falla:     _fallaCtrl.text.trim(),
      telefono:  _telefonoCtrl.text.trim().isEmpty
          ? 'S/N'
          : _telefonoCtrl.text.trim(),
      correo: _sinCorreo
          ? 'sin@correo'
          : (_correoCtrl.text.trim().isEmpty
              ? 'sin@correo'
              : _correoCtrl.text.trim()),
      usuario:   _usuarioCtrl.text.trim(),
      contrasena: _contrasenaCtrl.text.trim(),
      ipEquipo:  _ipEquipoCtrl.text.trim(),
      depto:     _deptoCtrl.text.trim(),
      adjuntos:  rutasAdjuntos,
    );

    await _db.insertarReporte(reporte);
    final resultado = await _sync.sincronizar();
    setState(() => _enviando = false);
    if (!mounted) return;

    if (resultado.containsKey('sinConexion')) {
      _mostrarMensaje(
        icono:   Icons.wifi_off,
        color:   Colors.orange,
        titulo:  'Guardado sin conexión',
        mensaje: 'El reporte se enviará automáticamente cuando haya señal.',
      );
    } else if (resultado['enviados']! > 0) {
      _mostrarMensaje(
        icono:   Icons.check_circle,
        color:   Colors.green,
        titulo:  '¡Reporte enviado!',
        mensaje: 'El reporte llegó al servidor correctamente.',
      );
    } else {
      _mostrarMensaje(
        icono:   Icons.cloud_queue,
        color:   Colors.orange,
        titulo:  'Guardado localmente',
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
        icon:    Icon(icono, color: color, size: 48),
        title:   Text(titulo, textAlign: TextAlign.center),
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
    setState(() {
      _personalEncontrado = null;
      _sinMatricula       = false;
      _sinCorreo          = false;
      for (int i = 0; i < _adjuntos.length; i++) _adjuntos[i] = null;
    });
    for (final c in [
      _matriculaCtrl, _nserieCtrl, _correoCtrl, _telefonoCtrl,
      _usuarioCtrl, _contrasenaCtrl, _ipEquipoCtrl, _deptoCtrl,
      _fallaCtrl, _nombreCtrl,
    ]) {
      c.clear();
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        titleSpacing: 16,
        title: const Text(
          'Reporte de Incidencia',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
        bottom: _estadoDirectorio.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _estadoDirectorio,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── 1. Matrícula con autorellenado ──────────────────────────
              _seccion('Número de matrícula:'),
              TextFormField(
                controller:   _matriculaCtrl,
                keyboardType: TextInputType.number,
                enabled:      !_sinMatricula,
                onChanged:    _onMatriculaChanged,
                decoration: _inputDeco('Introduce tu matrícula').copyWith(
                  suffixIcon: _buscandoMatricula
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _personalEncontrado != null
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF1a6e2e), size: 20)
                          : null,
                ),
                validator: _sinMatricula
                    ? null
                    : (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa tu matrícula o marca la casilla'
                        : null,
              ),
              _checkRojo(
                value:     _sinMatricula,
                label:     'No cuento con matrícula',
                onChanged: (v) {
                  setState(() {
                    _sinMatricula = v ?? false;
                    if (_sinMatricula) {
                      _matriculaCtrl.clear();
                      _limpiarAutorelleno();
                    }
                  });
                },
              ),

              // ── Tarjeta de personal encontrado ──────────────────────────
              if (_personalEncontrado != null) ...[
                const SizedBox(height: 8),
                _tarjetaPersonal(_personalEncontrado!),
              ],
              const SizedBox(height: 16),

              // ── 2. Nombre (se rellena solo o manual) ────────────────────
              _seccion('Nombre completo del usuario:'),
              _campoTexto(
                controller: _nombreCtrl,
                hint:       'Nombre completo del usuario que reporta',
                requerido:  true,
                enabled:    _personalEncontrado == null,
              ),
              const SizedBox(height: 16),

              // ── 3. Número de serie ──────────────────────────────────────
              _seccion('Número de Serie del equipo'),
              _campoTexto(
                controller: _nserieCtrl,
                hint:       'Número de serie del equipo a reportar',
                requerido:  true,
              ),
              const SizedBox(height: 16),

              // ── 4. Correo / búsqueda directorio ────────────────────────
              _seccion('Correo Electrónico:', labelColor: _verde),
              _campoBusqueda(),
              if (_trabajadorSeleccionado != null) _tarjetaTrabajador(),
              if (_trabajadorSeleccionado == null)
                _campoTexto(
                  controller: _correoCtrl,
                  hint:       'Correo electrónico institucional',
                  teclado:    TextInputType.emailAddress,
                  enabled:    !_sinCorreo,
                ),
              _checkRojo(
                value:     _sinCorreo,
                label:     'Sin correo institucional',
                onChanged: (v) => setState(() {
                  _sinCorreo = v ?? false;
                  if (_sinCorreo) {
                    _correoCtrl.clear();
                    _limpiarTrabajador();
                  }
                }),
              ),
              const SizedBox(height: 16),

              // ── 5. Teléfono ─────────────────────────────────────────────
              _seccion('Teléfono:'),
              _campoTexto(
                controller: _telefonoCtrl,
                hint:       'Teléfono local para contacto',
                teclado:    TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // ── 6. Cuenta de usuario ────────────────────────────────────
              _seccion('Cuenta de usuario del equipo', labelColor: _verde),
              _campoTexto(
                controller: _usuarioCtrl,
                hint:       'Ej. juan.perez, siap01.01803',
                requerido:  true,
              ),
              const SizedBox(height: 16),

              // ── 7. Contraseña ───────────────────────────────────────────
              _seccion('Contraseña de usuario', labelColor: _verde),
              _campoTexto(
                controller:   _contrasenaCtrl,
                hint:         'Contraseña CORRECTA al encender el equipo',
                esContrasena: true,
                requerido:    true,
              ),
              const SizedBox(height: 16),

              // ── 8. IP ───────────────────────────────────────────────────
              _seccion('IP del Equipo', labelColor: _verde),
              _campoTexto(
                controller: _ipEquipoCtrl,
                hint:       'Dirección IP del equipo a reportar',
                teclado:    TextInputType.number,
                requerido:  true,
              ),
              const SizedBox(height: 16),

              // ── 9. Departamento ─────────────────────────────────────────
              _seccion('Departamento al que pertenece', labelColor: _verde),
              _campoTexto(
                controller: _deptoCtrl,
                hint:       'Área donde se encuentra el equipo',
                requerido:  true,
              ),
              const SizedBox(height: 8),

              const Divider(height: 32, color: Color(0xFFE5E7EB)),

              // ── 10. Descripción ─────────────────────────────────────────
              _seccion('Descripción del servicio:'),
              TextFormField(
                controller: _fallaCtrl,
                maxLines:   5,
                decoration: _inputDeco(
                  'Describa detalladamente la incidencia',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'La descripción es requerida'
                        : null,
              ),
              const SizedBox(height: 20),

              // ── 11. Adjuntos ────────────────────────────────────────────
              Text(
                'Archivos adjuntos (fotos del equipo):',
                style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      _azul,
                ),
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < 3; i++) ...[
                _filaAdjunto(i),
                if (i < 2) const SizedBox(height: 8),
              ],
              const SizedBox(height: 24),

              // ── Botón enviar ────────────────────────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _enviando ? null : _guardarYEnviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: _enviando
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                  label: Text(
                    _enviando ? 'Guardando...' : 'Enviar Reporte.',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Botón limpiar ───────────────────────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _limpiarFormulario,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azul,
                    side: BorderSide(color: _azul.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon:  const Icon(Icons.cleaning_services_outlined,
                      size: 18),
                  label: const Text('Limpiar Formulario',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Nota legal ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        const Color(0xFFFFFDE7),
                  borderRadius: BorderRadius.circular(8),
                  border:       Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'NOTA: Todos los reportes son controlados mediante '
                        'la dirección IP de origen, por lo que cualquier '
                        'reporte inválido repercutirá en próximos reportes '
                        'y serán candidatos a las sanciones establecidas '
                        'por la coordinación de informática.',
                        style: TextStyle(
                          fontSize: 10,
                          color:    Colors.brown.shade700,
                          height:   1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets de UI ────────────────────────────────────────────────────────

  Widget _seccion(String titulo,
          {Color labelColor = const Color(0xFF374151)}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(titulo,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: labelColor)),
      );

  Widget _campoTexto({
    required TextEditingController controller,
    required String hint,
    bool requerido    = false,
    bool esContrasena = false,
    bool enabled      = true,
    TextInputType teclado = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller:   controller,
        obscureText:  esContrasena,
        keyboardType: teclado,
        enabled:      enabled,
        decoration:   _inputDeco(hint),
        validator: validator ??
            (requerido
                ? (v) => (v == null || v.trim().isEmpty)
                    ? 'Este campo es requerido'
                    : null
                : null),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(
            fontSize: 13, color: Color(0xFF9CA3AF)),
        filled:    true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFF1a6e2e), width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFd32f2f))),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: Color(0xFFE5E7EB))),
      );

  Widget _checkRojo({
    required bool value,
    required String label,
    required void Function(bool?) onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            SizedBox(
              width: 20, height: 20,
              child: Checkbox(
                value:       value,
                onChanged:   onChanged,
                activeColor: _rojo,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _rojo)),
          ],
        ),
      );

  Widget _campoBusqueda() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _busquedaCtrl,
            onChanged:  _onBusquedaChanged,
            enabled:    !_sinCorreo,
            decoration: _inputDeco(
              'Buscar por correo o nombre (ej. juan.perez@imss.gob.mx)',
            ).copyWith(
              prefixIcon: const Icon(Icons.search,
                  color: Color(0xFF1a6e2e), size: 20),
              suffixIcon: _busquedaCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _limpiarTrabajador)
                  : _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)))
                      : null,
            ),
          ),
          if (_sugerencias.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF1a6e2e).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                      color:      Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset:     const Offset(0, 3))
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics:    const NeverScrollableScrollPhysics(),
                itemCount:  _sugerencias.length,
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
                            color:      Color(0xFF1a6e2e),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(t.nombreCompleto,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(t.correo ?? t.matricula,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600])),
                    trailing: t.departamento != null
                        ? Text(t.departamento!,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[500]),
                            maxLines:  1,
                            overflow:  TextOverflow.ellipsis)
                        : null,
                    onTap: () => _seleccionarTrabajador(t),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      );

  /// Tarjeta verde cuando se encontró al trabajador en directorio_local
  Widget _tarjetaTrabajador() {
    final t = _trabajadorSeleccionado!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFFe8f5e9),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: const Color(0xFF81c784)),
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
                child: Text(t.nombreCompleto,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1a6e2e))),
              ),
              GestureDetector(
                onTap:  _limpiarTrabajador,
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
        ],
      ),
    );
  }

  /// Tarjeta azul cuando se encontró al empleado en personal_local
  Widget _tarjetaPersonal(Personal p) {
    final tieneDirectorio = p.correo != null && p.correo!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_search,
                  color: Color(0xFF1565c0), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  p.nombreCompleto,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565c0)),
                ),
              ),
              GestureDetector(
                onTap: _limpiarAutorelleno,
                child: const Icon(Icons.close,
                    size: 18, color: Color(0xFF1565c0)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            tieneDirectorio
                ? 'Datos completados desde directorio'
                : 'Empleado encontrado · sin correo en directorio',
            style: TextStyle(
                fontSize: 11,
                color: tieneDirectorio
                    ? Colors.blue[700]
                    : Colors.orange[700]),
          ),
        ],
      ),
    );
  }

  Widget _filaAdjunto(int index) {
    final archivo = _adjuntos[index];
    return Row(
      children: [
        if (archivo != null)
          Container(
            width: 42, height: 42,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF81c784)),
              image: DecorationImage(
                  image: FileImage(archivo), fit: BoxFit.cover),
            ),
          ),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color:        Colors.white,
              borderRadius: BorderRadius.circular(8),
              border:       Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                archivo != null
                    ? 'Foto ${index + 1} capturada ✓'
                    : 'Sin foto',
                style: TextStyle(
                  fontSize: 12,
                  color: archivo != null
                      ? Colors.black87
                      : const Color(0xFF9CA3AF),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _tomarFoto(index),
          child: Container(
            height:  42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color:        _azul,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.camera_alt, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Tomar foto',
                    style: TextStyle(
                        color:      Colors.white,
                        fontSize:   13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}