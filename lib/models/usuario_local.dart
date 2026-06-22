// lib/models/usuario_local.dart
class UsuarioLocal {
  final String matricula;
  final String password; // sha1 tal como viene del servidor
  final String nombres;
  final String apPaterno;
  final String apMaterno;
  final String? email;
  final String rol;

  const UsuarioLocal({
    required this.matricula,
    required this.password,
    required this.nombres,
    required this.apPaterno,
    required this.apMaterno,
    this.email,
    this.rol = 'user',
  });

  String get nombreCompleto => '$nombres $apPaterno $apMaterno'.trim();

  factory UsuarioLocal.fromApi(Map<String, dynamic> j) => UsuarioLocal(
        matricula: j['matricula'] ?? '',
        password:  j['password']  ?? '',
        nombres:   j['nombres']   ?? '',
        apPaterno: j['ap_paterno'] ?? '',
        apMaterno: j['ap_materno'] ?? '',
        email:     j['email']     as String?,
        rol:       j['rol']       ?? 'user',
      );

  factory UsuarioLocal.fromMap(Map<String, dynamic> m) => UsuarioLocal(
        matricula: m['matricula'] ?? '',
        password:  m['password']  ?? '',
        nombres:   m['nombres']   ?? '',
        apPaterno: m['ap_paterno'] ?? '',
        apMaterno: m['ap_materno'] ?? '',
        email:     m['email']     as String?,
        rol:       m['rol']       ?? 'user',
      );

  Map<String, dynamic> toMap() => {
        'matricula': matricula,
        'password':  password,
        'nombres':   nombres,
        'ap_paterno': apPaterno,
        'ap_materno': apMaterno,
        'email':     email,
        'rol':       rol,
      };
}