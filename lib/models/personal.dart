class Personal {
  final String matricula;
  final String nombres;
  final String apPaterno;
  final String apMaterno;
  final String? claveAdscripcion;
  final String? claveCategoria;
  // campos del join con trabajadores (pueden ser null si no hay match)
  final String? correo;
  final String? extension;
  final String? telefono;
  final String? departamento;
  final String? adscripcion;
  final bool activo;
  final int tsSync;

  const Personal({
    required this.matricula,
    required this.nombres,
    required this.apPaterno,
    required this.apMaterno,
    this.claveAdscripcion,
    this.claveCategoria,
    this.correo,
    this.extension,
    this.telefono,
    this.departamento,
    this.adscripcion,
    this.activo = true,
    this.tsSync = 0,
  });

  String get nombreCompleto =>
      '$nombres $apPaterno $apMaterno'.trim();

  factory Personal.fromApi(Map<String, dynamic> j) => Personal(
        matricula:        j['matricula']         ?? '',
        nombres:          j['nombres']           ?? '',
        apPaterno:        j['ap_paterno']        ?? '',
        apMaterno:        j['ap_materno']        ?? '',
        claveAdscripcion: j['clave_adscripcion'] as String?,
        claveCategoria:   j['clave_categoria']   as String?,
        correo:           j['correo']            as String?,
        extension:        j['extension']         as String?,
        telefono:         j['telefono']          as String?,
        departamento:     j['departamento']      as String?,
        adscripcion:      j['adscripcion']       as String?,
        activo:           j['activo'] == true || j['activo'] == 1,
        tsSync:           DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

  factory Personal.fromMap(Map<String, dynamic> m) => Personal(
        matricula:        m['matricula']          ?? '',
        nombres:          m['nombres']            ?? '',
        apPaterno:        m['ap_paterno']         ?? '',
        apMaterno:        m['ap_materno']         ?? '',
        claveAdscripcion: m['clave_adscripcion']  as String?,
        claveCategoria:   m['clave_categoria']    as String?,
        correo:           m['correo']             as String?,
        extension:        m['extension']          as String?,
        telefono:         m['telefono']           as String?,
        departamento:     m['departamento']       as String?,
        adscripcion:      m['adscripcion']        as String?,
        activo:           (m['activo'] ?? 1) == 1,
        tsSync:           m['ts_sync']            ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'matricula':         matricula,
        'nombres':           nombres,
        'ap_paterno':        apPaterno,
        'ap_materno':        apMaterno,
        'clave_adscripcion': claveAdscripcion,
        'clave_categoria':   claveCategoria,
        'correo':            correo,
        'extension':         extension,
        'telefono':          telefono,
        'departamento':      departamento,
        'adscripcion':       adscripcion,
        'activo':            activo ? 1 : 0,
        'ts_sync':           tsSync,
      };
}