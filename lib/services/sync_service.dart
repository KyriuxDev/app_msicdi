import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import '../db/database_helper.dart';

class SyncService {
  static const String _urlServidor =
      'http://192.168.5.192/msicdi/soporte/apiReporte';
  static const String _token = 'B1n4r10';

  final DatabaseHelper _db = DatabaseHelper();

  // Verifica si hay conexión a internet
  Future<bool> hayConexion() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // Intenta enviar todos los reportes pendientes
  Future<Map<String, int>> sincronizar() async {
    int enviados = 0;
    int fallidos = 0;

    if (!await hayConexion()) {
      return {'enviados': 0, 'fallidos': 0, 'sinConexion': 1};
    }

    final pendientes = await _db.obtenerPendientes();

    for (final reporte in pendientes) {
      final exito = await _enviarReporte(reporte);
      if (exito) {
        enviados++;
      } else {
        fallidos++;
      }
    }

    return {'enviados': enviados, 'fallidos': fallidos};
  }

  // Envía un reporte individual al servidor
  Future<bool> _enviarReporte(reporte) async {
    try {
      final response = await http.post(
        Uri.parse(_urlServidor),
        body: {
          'token': _token,
          'matricula': reporte.matricula,
          'nserie': reporte.nserie,
          'falla': reporte.falla,
          'telefono': reporte.telefono,
          'correo': reporte.correo,
          'usuario': reporte.usuario,
          'contrasena': reporte.contrasena,
          'ipEquipo': reporte.ipEquipo,
          'depto': reporte.depto,
          'ipOrigen': reporte.ipOrigen,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ok'] == true) {
          await _db.marcarEnviado(reporte.id!, data['nRastreo']);
          return true;
        }
      }
      return false;
    } catch (e) {
      // Sin conexión o timeout — se reintentará después
      return false;
    }
  }
}