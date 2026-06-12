import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/trabajador.dart';

class DirectorioService {
  static const _base   = 'http://192.168.5.192/api/v1';
  static const _token  = 'B1n4r10';
  static const _limite = 500;

  final _db = DatabaseHelper();

  Map<String, String> get _headers => {
        'X-Api-Token': _token,
        'Content-Type': 'application/json',
      };

  // ─── Sincronización ───────────────────────────────────────────────────────

  Future<SyncDirectorioResult> sincronizar() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      return SyncDirectorioResult(sinConexion: true);
    }

    try {
      final ultimoTs = await _db.ultimoTsSync();
      int total = 0;

      if (ultimoTs > 0) {
        // Sync incremental — solo cambios desde último sync
        final uri = Uri.parse('$_base/directorio?desde=$ultimoTs');
        final res = await http.get(uri, headers: _headers)
            .timeout(const Duration(seconds: 30));

        if (res.statusCode == 200) {
          final data    = jsonDecode(res.body);
          final lista   = (data['trabajadores'] as List)
              .map((j) => Trabajador.fromApi(j as Map<String, dynamic>))
              .toList();
          await _db.upsertTrabajadores(lista);
          total = lista.length;
        }
      } else {
        // Primera sync — descarga paginada completa
        int pagina = 1;
        bool hayMas = true;

        while (hayMas) {
          final uri = Uri.parse('$_base/directorio?pagina=$pagina&limite=$_limite');
          final res = await http.get(uri, headers: _headers)
              .timeout(const Duration(seconds: 30));

          if (res.statusCode != 200) break;

          final data  = jsonDecode(res.body);
          final lista = (data['trabajadores'] as List)
              .map((j) => Trabajador.fromApi(j as Map<String, dynamic>))
              .toList();

          await _db.upsertTrabajadores(lista);
          total += lista.length;

          final totalServidor = data['total'] as int? ?? 0;
          hayMas = total < totalServidor;
          pagina++;
        }
      }

      final totalLocal = await _db.contarDirectorio();
      await _guardarFechaSync();

      return SyncDirectorioResult(
        descargados: total,
        totalLocal:  totalLocal,
      );
    } catch (e) {
      return SyncDirectorioResult(error: e.toString());
    }
  }

  Future<void> _guardarFechaSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('directorio_sync_ts', DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  Future<DateTime?> ultimaSincronizacion() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt('directorio_sync_ts');
    return ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : null;
  }

  // ─── Búsqueda local ───────────────────────────────────────────────────────

  Future<Trabajador?> buscarPorCorreo(String correo) =>
      _db.buscarPorCorreo(correo);

  Future<Trabajador?> buscarPorMatricula(String matricula) =>
      _db.buscarPorMatricula(matricula);

  Future<List<Trabajador>> sugerencias(String texto) =>
      _db.buscarPorTexto(texto);

  Future<int> totalLocal() => _db.contarDirectorio();
}

class SyncDirectorioResult {
  final int    descargados;
  final int    totalLocal;
  final bool   sinConexion;
  final String error;

  const SyncDirectorioResult({
    this.descargados = 0,
    this.totalLocal  = 0,
    this.sinConexion = false,
    this.error       = '',
  });

  bool get ok => !sinConexion && error.isEmpty;
}