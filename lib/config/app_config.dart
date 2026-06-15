/// Configuración global de la app.
/// Cambia aquí la IP/URL y el token — no toques los servicios individualmente.
class AppConfig {
  AppConfig._();

  // ── Servidor ──────────────────────────────────────────────────────────────
  static const String baseUrl  = 'http://192.168.5.192';
  static const String apiToken = 'B1n4r10';

  // ── Endpoints derivados ───────────────────────────────────────────────────
  static const String urlLogin      = '$baseUrl/msicdi/site/matriculaValida';
  static const String urlReporte    = '$baseUrl/msicdi/soporte/apiReporte';
  static const String urlDirectorio = '$baseUrl/api/v1/directorio';
  static const String urlPersonal   = '$baseUrl/api/v1/personal';   // ← NUEVO

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration timeoutCorto = Duration(seconds: 8);
  static const Duration timeoutLargo = Duration(seconds: 30);
}