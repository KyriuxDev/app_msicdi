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
  String estado; // 'pendiente' o 'enviado'
  String? nRastreo; // llega del servidor al sincronizar
  String fechaCreacion;

  Reporte({
    this.id,
    required this.matricula,
    required this.nombreReportador,
    required this.nserie,
    required this.falla,
    this.telefono = 'S/N',
    this.correo = 'sin@correo',
    this.usuario = '',
    this.contrasena = '',
    this.ipEquipo = '',
    this.depto = '',
    this.ipOrigen = '0.0.0.0',
    this.estado = 'pendiente',
    this.nRastreo,
    String? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now().toIso8601String();

  // Convierte a Map para guardar en SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matricula': matricula,
      'nombreReportador': nombreReportador,
      'nserie': nserie,
      'falla': falla,
      'telefono': telefono,
      'correo': correo,
      'usuario': usuario,
      'contrasena': contrasena,
      'ipEquipo': ipEquipo,
      'depto': depto,
      'ipOrigen': ipOrigen,
      'estado': estado,
      'nRastreo': nRastreo,
      'fechaCreacion': fechaCreacion,
    };
  }

  // Crea un Reporte desde un Map de SQLite
  factory Reporte.fromMap(Map<String, dynamic> map) {
    return Reporte(
      id: map['id'],
      matricula: map['matricula'] ?? '',
      nombreReportador: map['nombreReportador'] ?? '',
      nserie: map['nserie'] ?? '',
      falla: map['falla'] ?? '',
      telefono: map['telefono'] ?? 'S/N',
      correo: map['correo'] ?? 'sin@correo',
      usuario: map['usuario'] ?? '',
      contrasena: map['contrasena'] ?? '',
      ipEquipo: map['ipEquipo'] ?? '',
      depto: map['depto'] ?? '',
      ipOrigen: map['ipOrigen'] ?? '0.0.0.0',
      estado: map['estado'] ?? 'pendiente',
      nRastreo: map['nRastreo'],
      fechaCreacion: map['fechaCreacion'] ?? '',
    );
  }
}