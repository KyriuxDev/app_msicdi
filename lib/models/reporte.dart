import 'dart:convert';

class Reporte {
  int? id;
  String matricula;
  String nombreReportador;
  String nserie;
  String falla;
  String telefono;
  String correo;
  String usuario;
  String contrasena;
  String ipEquipo;
  String depto;
  String ipOrigen;
  String estado;
  String? nRastreo;
  String fechaCreacion;

  /// Rutas locales de fotos adjuntas.
  /// Se guardan en SQLite como JSON array de strings.
  /// El envío al servidor queda pendiente para cuando el endpoint exista.
  List<String> adjuntos;

  Reporte({
    this.id,
    required this.matricula,
    required this.nombreReportador,
    required this.nserie,
    required this.falla,
    this.telefono    = 'S/N',
    this.correo      = 'sin@correo',
    this.usuario     = '',
    this.contrasena  = '',
    this.ipEquipo    = '',
    this.depto       = '',
    this.ipOrigen    = '0.0.0.0',
    this.estado      = 'pendiente',
    this.nRastreo,
    String? fechaCreacion,
    List<String>? adjuntos,
  })  : fechaCreacion = fechaCreacion ?? DateTime.now().toIso8601String(),
        adjuntos      = adjuntos ?? [];

  Map<String, dynamic> toMap() => {
        'id':              id,
        'matricula':       matricula,
        'nombreReportador':nombreReportador,
        'nserie':          nserie,
        'falla':           falla,
        'telefono':        telefono,
        'correo':          correo,
        'usuario':         usuario,
        'contrasena':      contrasena,
        'ipEquipo':        ipEquipo,
        'depto':           depto,
        'ipOrigen':        ipOrigen,
        'estado':          estado,
        'nRastreo':        nRastreo,
        'fechaCreacion':   fechaCreacion,
        // Serializa la lista como JSON string para SQLite
        'adjuntos':        adjuntos.isEmpty ? null : jsonEncode(adjuntos),
      };

  factory Reporte.fromMap(Map<String, dynamic> map) {
    // Deserializa la lista de adjuntos desde JSON string
    List<String> adj = [];
    if (map['adjuntos'] != null) {
      try {
        adj = List<String>.from(jsonDecode(map['adjuntos'] as String));
      } catch (_) {
        adj = [];
      }
    }

    return Reporte(
      id:              map['id'],
      matricula:       map['matricula']        ?? '',
      nombreReportador:map['nombreReportador'] ?? '',
      nserie:          map['nserie']           ?? '',
      falla:           map['falla']            ?? '',
      telefono:        map['telefono']         ?? 'S/N',
      correo:          map['correo']           ?? 'sin@correo',
      usuario:         map['usuario']          ?? '',
      contrasena:      map['contrasena']       ?? '',
      ipEquipo:        map['ipEquipo']         ?? '',
      depto:           map['depto']            ?? '',
      ipOrigen:        map['ipOrigen']         ?? '0.0.0.0',
      estado:          map['estado']           ?? 'pendiente',
      nRastreo:        map['nRastreo'],
      fechaCreacion:   map['fechaCreacion']    ?? '',
      adjuntos:        adj,
    );
  }
}