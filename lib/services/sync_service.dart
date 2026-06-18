import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/app_config.dart';
import '../db/database_helper.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper();

  // ── Singleton ──────────────────────────────────────────────────────────
  static SyncService? _instance;
  static StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Evita que dos syncs corran al mismo tiempo
  static bool _syncEnCurso = false;

  factory SyncService() {
    _instance ??= SyncService._internal();
    return _instance!;
  }
  SyncService._internal();

  // ── Listener de conectividad ───────────────────────────────────────────

  void iniciarEscuchaConectividad() {
    _connSub?.cancel();

    // distinct() evita el doble disparo cuando la red sube
    final redStream = Connectivity()
        .onConnectivityChanged
        .map((results) => results.any((r) => r != ConnectivityResult.none))
        .distinct();

    redStream.listen((tieneRed) {
      if (tieneRed) _sincronizarSilencioso();
    });
  }

  void detenerEscucha() {
    _connSub?.cancel();
    _connSub = null;
  }

  // ── Sync silencioso (background) ───────────────────────────────────────

  Future<void> _sincronizarSilencioso() async {
    if (_syncEnCurso) return; // ya hay un sync corriendo, ignorar
    _syncEnCurso = true;
    try {
      final pendientes = await _db.obtenerPendientes();
      if (pendientes.isEmpty) return;
      _log('Enviando ${pendientes.length} reporte(s) pendiente(s)...');
      for (final reporte in pendientes) {
        await _enviarReporte(reporte);
      }
    } catch (e) {
      _log('Error en sync silencioso: $e');
    } finally {
      _syncEnCurso = false;
    }
  }

  // ── API pública ────────────────────────────────────────────────────────

  Future<bool> hayConexion() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Lanza sync en background sin bloquear la UI.
  void enviarEnBackground() {
    unawaited(_sincronizarSilencioso());
  }

  /// Sync manual desde el botón de historial — sí espera resultado.
  Future<Map<String, int>> sincronizar() async {
    if (!await hayConexion()) {
      return {'enviados': 0, 'fallidos': 0, 'sinConexion': 1};
    }
    if (_syncEnCurso) {
      return {'enviados': 0, 'fallidos': 0};
    }

    _syncEnCurso = true;
    int enviados = 0;
    int fallidos = 0;

    try {
      final pendientes = await _db.obtenerPendientes();
      for (final reporte in pendientes) {
        final exito = await _enviarReporte(reporte);
        exito ? enviados++ : fallidos++;
      }
    } finally {
      _syncEnCurso = false;
    }

    return {'enviados': enviados, 'fallidos': fallidos};
  }

  // ── Envío individual ───────────────────────────────────────────────────

  Future<bool> _enviarReporte(reporte) async {
    try {
      final uri     = Uri.parse(AppConfig.urlReporte);
      final request = http.MultipartRequest('POST', uri);

      request.headers['X-Api-Token'] = AppConfig.apiToken;

      request.fields.addAll({
        'token':      AppConfig.apiToken,
        'matricula':  reporte.matricula,
        'nserie':     reporte.nserie,
        'falla':      reporte.falla,
        'telefono':   reporte.telefono,
        'correo':     reporte.correo,
        'usuario':    reporte.usuario,
        'contrasena': reporte.contrasena,
        'ipEquipo':   reporte.ipEquipo,
        'depto':      reporte.depto,
        'ipOrigen':   reporte.ipOrigen,
      });

      // Fotos adjuntas
      final adjuntos = reporte.adjuntos as List<String>;
      for (int i = 0; i < adjuntos.length && i < 3; i++) {
        final archivo = File(adjuntos[i]);
        if (!archivo.existsSync()) continue;
        request.files.add(
          await http.MultipartFile.fromPath('adjunto$i', adjuntos[i]),
        );
      }

      final streamed  = await request.send().timeout(AppConfig.timeoutLargo);
      final response  = await http.Response.fromStream(streamed);
      final body      = response.body;

      if (response.statusCode == 200) {
        final data = jsonDecode(body);
        if (data['ok'] == true) {
          final nRastreo = data['nRastreo']?.toString() ?? '';
          await _db.marcarEnviado(reporte.id!, nRastreo);
          _log('Reporte ${reporte.id} enviado → folio $nRastreo');
          return true;
        }
        _log('Servidor rechazó reporte ${reporte.id}: ${data['error']}');
        // ok=false del servidor = error de datos → marcar como error permanente
        // para que no se reintente indefinidamente
        await _db.marcarErrorPermanente(reporte.id!);
        return false;
      }

      // 4xx = error de datos (no reintentar), 5xx = error de servidor (reintentar)
      if (response.statusCode >= 400 && response.statusCode < 500) {
        _log('Error ${response.statusCode} en reporte ${reporte.id} — '
             'marcando como error permanente. Body: $body');
        await _db.marcarErrorPermanente(reporte.id!);
      } else {
        _log('HTTP ${response.statusCode} en reporte ${reporte.id} — se reintentará');
      }
      return false;

    } on TimeoutException catch (_) {
      _log('Timeout en reporte ${reporte.id} — se reintentará');
      return false;
    } on SocketException catch (_) {
      _log('Sin red en reporte ${reporte.id} — se reintentará');
      return false;
    } catch (e) {
      _log('Error inesperado en reporte ${reporte.id}: $e');
      return false;
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[SyncService] $msg');
  }
}

void unawaited(Future<void> future) {
  future.catchError((_) {});
}