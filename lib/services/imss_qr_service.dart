// lib/services/imss_qr_service.dart
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

/// Descifra el HEX generado por IMSS_TrayApp y retorna un Map con los campos.
class ImssQrService {
  static const _llaveStr = "IMSS_OAX_2024_QR";

  /// Devuelve null si el QR no es válido o no se puede descifrar.
  static Map<String, String>? descifrar(String hexCifrado) {
    try {
      final bytes = _hexToBytes(hexCifrado.trim());
      if (bytes.length < 17) return null;

      final iv     = IV(Uint8List.fromList(bytes.sublist(0, 16)));
      final datos  = Uint8List.fromList(bytes.sublist(16));
      final llave  = Key.fromUtf8(_llaveStr);
      final enc    = Encrypter(AES(llave, mode: AESMode.cbc));
      final texto  = enc.decrypt(Encrypted(datos), iv: iv);

      return _parsear(texto);
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _parsear(String texto) {
    final result = <String, String>{};
    for (final linea in texto.split('\n')) {
      final i = linea.indexOf(':');
      if (i < 0) continue;
      final clave = linea.substring(0, i).trim();
      final valor = linea.substring(i + 1).trim();
      result[clave] = valor;
    }

    // Normalizar claves compuestas: "IP: 1.2.3.4 | MAC: AA:BB..."
    final ipMac = result['IP'] ?? '';
    if (ipMac.contains('|')) {
      final partes = ipMac.split('|');
      result['IP']  = partes[0].trim();
      final mac     = partes[1].trim();
      final macVal  = mac.contains(':') ? mac.substring(mac.indexOf(':') + 1).trim() : mac;
      result['MAC'] = macVal;
    }

    // "SN: ABC | MOD: HP EliteBook"
    final snMod = result['SN'] ?? '';
    if (snMod.contains('|')) {
      final partes  = snMod.split('|');
      result['SN']  = partes[0].trim();
      final mod     = partes[1].trim();
      final modVal  = mod.contains(':') ? mod.substring(mod.indexOf(':') + 1).trim() : mod;
      result['MOD'] = modVal;
    }

    return result;
  }

  static Uint8List _hexToBytes(String hex) {
    hex = hex.toLowerCase();
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}