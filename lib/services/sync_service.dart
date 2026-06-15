import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../config/app_config.dart';
import '../db/database_helper.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<bool> hayConexion() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Intenta enviar todos los reportes pendientes.
  /// Retorna mapa con claves: 'enviados', 'fallidos'.
  /// Si no hay conexión incluye 'sinConexion': 1.
  Future<Map<String, int>> sincronizar() async {
    if (!await hayConexion()) {
      return {'enviados': 0, 'fallidos': 0, 'sinConexion': 1};
    }

    int enviados = 0;
    int fallidos = 0;

    final pendientes = await _db.obtenerPendientes();
    for (final reporte in pendientes) {
      final exito = await _enviarReporte(reporte);
      exito ? enviados++ : fallidos++;
    }

    return {'enviados': enviados, 'fallidos': fallidos};
  }

  Future<bool> _enviarReporte(reporte) async {
    try {
      final response = await http.post(
        Uri.parse(AppConfig.urlReporte),
        body: {
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
          // TODO: cuando el endpoint de fotos esté listo,
          // adjuntar reporte.adjuntos como multipart aquí.
        },
      ).timeout(AppConfig.timeoutCorto);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          await _db.marcarEnviado(reporte.id!, data['nRastreo']);
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}