// lib/services/usuario_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';      // pubspec: crypto: ^3.0.3
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../db/database_helper.dart';
import '../models/usuario_local.dart';

class UsuarioService {
  final _db = DatabaseHelper();

  static const _kUltimoSync = 'usuarios_ultimo_sync';

  Map<String, String> get _headers => {
        'X-Api-Token': AppConfig.apiToken,
        'Content-Type': 'application/json',
      };

  // ─── Sync desde servidor ─────────────────────────────────────────────────

  /// Trae todos los usuarios habilitados desde el servidor y los guarda
  /// en SQLite local. Usa sync incremental (?desde=) cuando ya hubo un sync
  /// previo, igual que el patrón de personal/directorio.
  Future<bool> sincronizar() async {
    final conn = await Connectivity().checkConnectivity();
    if (conn.any((r) => r == ConnectivityResult.none)) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final ultimoSync = prefs.getInt(_kUltimoSync) ?? 0;

      final uri = ultimoSync > 0
          ? Uri.parse('${AppConfig.baseUrl}/api/v1/usuarios?desde=$ultimoSync')
          : Uri.parse('${AppConfig.baseUrl}/api/v1/usuarios?pagina=1&limite=1000');

      final res = await http
          .get(uri, headers: _headers)
          .timeout(AppConfig.timeoutLargo);

      if (res.statusCode != 200) return false;

      final data  = jsonDecode(res.body);
      final lista = (data['usuarios'] as List)
          .map((j) => UsuarioLocal.fromApi(j as Map<String, dynamic>))
          .toList();

      await _db.upsertUsuarios(lista);

      // Si el primer sync trajo el total completo y eran más de 1000,
      // habría que paginar; para <1000 usuarios esto basta.
      await prefs.setInt(
          _kUltimoSync, DateTime.now().millisecondsSinceEpoch ~/ 1000);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Login local ──────────────────────────────────────────────────────────

  /// Valida matrícula + contraseña contra la BD local.
  /// La contraseña se hashea con SHA1 igual que el servidor (sha1($pass)).
  Future<UsuarioLocal?> loginLocal(String matricula, String contrasena) async {
    final usuario = await _db.buscarUsuario(matricula);
    if (usuario == null) return null;

    final hashIngresado = _sha1(contrasena);
    if (hashIngresado == usuario.password) return usuario;

    return null;
  }

  String _sha1(String input) {
    final bytes  = utf8.encode(input);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }

  Future<bool> hayUsuariosLocales() async {
    final total = await _db.contarUsuarios();
    return total > 0;
  }
}
