class Trabajador {
  final String matricula;
  final String nombreCompleto;
  final String? correo;
  final String? extension;
  final String? telefono;
  final String? departamento;
  final String? adscripcion;
  final bool   activo;
  final int    tsSync;

  const Trabajador({
    required this.matricula,
    required this.nombreCompleto,
    this.correo,
    this.extension,
    this.telefono,
    this.departamento,
    this.adscripcion,
    this.activo = true,
    this.tsSync = 0,
  });

  factory Trabajador.fromMap(Map<String, dynamic> m) => Trabajador(
        matricula:      m['matricula']       ?? '',
        nombreCompleto: m['nombre_completo'] ?? '',
        correo:         m['correo']      as String?,
        extension:      m['extension']   as String?,
        telefono:       m['telefono']    as String?,
        departamento:   m['departamento'] as String?,
        adscripcion:    m['adscripcion'] as String?,
        activo:         (m['activo'] ?? 1) == 1,
        tsSync:         m['ts_sync']     ?? 0,
      );

  factory Trabajador.fromApi(Map<String, dynamic> j) => Trabajador(
        matricula:      j['matricula']       ?? '',
        nombreCompleto: j['nombre_completo'] ?? '',
        correo:         j['correo']      as String?,
        extension:      j['extension']   as String?,
        telefono:       j['telefono']    as String?,
        departamento:   j['departamento'] as String?,
        adscripcion:    j['adscripcion'] as String?,
        activo:         j['activo'] == true || j['activo'] == 1,
        tsSync:         DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

  Map<String, dynamic> toMap() => {
        'matricula':       matricula,
        'nombre_completo': nombreCompleto,
        'correo':          correo,
        'extension':       extension,
        'telefono':        telefono,
        'departamento':    departamento,
        'adscripcion':     adscripcion,
        'activo':          activo ? 1 : 0,
        'ts_sync':         tsSync,
      };
}