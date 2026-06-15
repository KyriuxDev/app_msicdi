import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../db/database_helper.dart';
import '../models/personal.dart';

class PersonalService {
  static const _limite = 500;

  final _db = DatabaseHelper();

  Map<String, String> get _headers => {
        'X-Api-Token': AppConfig.apiToken,
        'Content-Type': 'application/json',
      };

  // ─── Sincronización ───────────────────────────────────────────────────────

  Future<SyncPersonalResult> sincronizar() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      return SyncPersonalResult(sinConexion: true);
    }

    try {
      final ultimoTs = await _db.ultimoTsSyncPersonal();
      int total = 0;

      if (ultimoTs > 0) {
        // Sync incremental
        final uri =
            Uri.parse('${AppConfig.urlPersonal}?desde=$ultimoTs');
        final res = await http
            .get(uri, headers: _headers)
            .timeout(AppConfig.timeoutLargo);

        if (res.statusCode == 200) {
          final data  = jsonDecode(res.body);
          final lista = (data['personal'] as List)
              .map((j) => Personal.fromApi(j as Map<String, dynamic>))
              .toList();
          await _db.upsertPersonal(lista);
          total = lista.length;
        }
      } else {
        // Primera sync — descarga paginada completa
        int pagina  = 1;
        bool hayMas = true;

        while (hayMas) {
          final uri = Uri.parse(
              '${AppConfig.urlPersonal}?pagina=$pagina&limite=$_limite');
          final res = await http
              .get(uri, headers: _headers)
              .timeout(AppConfig.timeoutLargo);

          if (res.statusCode != 200) break;

          final data  = jsonDecode(res.body);
          final lista = (data['personal'] as List)
              .map((j) => Personal.fromApi(j as Map<String, dynamic>))
              .toList();

          await _db.upsertPersonal(lista);
          total += lista.length;

          final totalServidor = data['total'] as int? ?? 0;
          hayMas = total < totalServidor;
          pagina++;
        }
      }

      final totalLocal = await _db.contarPersonal();
      await _guardarFechaSync();

      return SyncPersonalResult(descargados: total, totalLocal: totalLocal);
    } catch (e) {
      return SyncPersonalResult(error: e.toString());
    }
  }

  Future<void> _guardarFechaSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        'personal_sync_ts', DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  Future<DateTime?> ultimaSincronizacion() async {
    final prefs = await SharedPreferences.getInstance();
    final ts    = prefs.getInt('personal_sync_ts');
    return ts != null
        ? DateTime.fromMillisecondsSinceEpoch(ts * 1000)
        : null;
  }

  // ─── Búsqueda local ───────────────────────────────────────────────────────

  /// Busca por matrícula en personal_local (join ya resuelto desde API).
  Future<Personal?> buscarPorMatricula(String matricula) =>
      _db.buscarPersonalPorMatricula(matricula);

  Future<int> totalLocal() => _db.contarPersonal();
}

// ─── Result ───────────────────────────────────────────────────────────────────

class SyncPersonalResult {
  final int    descargados;
  final int    totalLocal;
  final bool   sinConexion;
  final String error;

  const SyncPersonalResult({
    this.descargados = 0,
    this.totalLocal  = 0,
    this.sinConexion = false,
    this.error       = '',
  });

  bool get ok => !sinConexion && error.isEmpty;
}