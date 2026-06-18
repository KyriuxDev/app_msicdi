import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reporte.dart';
import '../models/trabajador.dart';
import '../models/personal.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _db;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'reportes_msicdi.db');
    return await openDatabase(
      path,
      version: 4,                          // v3 → v4: agrega personal_local
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_sqlReportes);
    await db.execute(_sqlDirectorio);
    await db.execute(_sqlPersonal);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(_sqlDirectorio);
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE reportes ADD COLUMN adjuntos TEXT DEFAULT NULL');
    }
    if (oldVersion < 4) {
      await db.execute(_sqlPersonal);
    }
  }

  // ─── DDL ──────────────────────────────────────────────────────────────────

  static const _sqlReportes = '''
    CREATE TABLE reportes (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      matricula        TEXT NOT NULL,
      nombreReportador TEXT NOT NULL,
      nserie           TEXT NOT NULL,
      falla            TEXT NOT NULL,
      telefono         TEXT,
      correo           TEXT,
      usuario          TEXT,
      contrasena       TEXT,
      ipEquipo         TEXT,
      depto            TEXT,
      ipOrigen         TEXT,
      estado           TEXT DEFAULT 'pendiente',
      nRastreo         TEXT,
      fechaCreacion    TEXT,
      adjuntos         TEXT DEFAULT NULL
    )
  ''';

  static const _sqlDirectorio = '''
    CREATE TABLE directorio_local (
      matricula        TEXT PRIMARY KEY,
      nombre_completo  TEXT NOT NULL,
      correo           TEXT,
      extension        TEXT,
      telefono         TEXT,
      departamento     TEXT,
      adscripcion      TEXT,
      activo           INTEGER DEFAULT 1,
      ts_sync          INTEGER DEFAULT 0
    )
  ''';

  static const _sqlPersonal = '''
    CREATE TABLE personal_local (
      matricula          TEXT PRIMARY KEY,
      nombres            TEXT NOT NULL,
      ap_paterno         TEXT NOT NULL,
      ap_materno         TEXT,
      clave_adscripcion  TEXT,
      clave_categoria    TEXT,
      correo             TEXT,
      extension          TEXT,
      telefono           TEXT,
      departamento       TEXT,
      adscripcion        TEXT,
      activo             INTEGER DEFAULT 1,
      ts_sync            INTEGER DEFAULT 0
    )
  ''';

  // ─── REPORTES ─────────────────────────────────────────────────────────────

  Future<int> insertarReporte(Reporte reporte) async {
    final db = await database;
    return await db.insert('reportes', reporte.toMap());
  }

  Future<List<Reporte>> obtenerPendientes() async {
    final db = await database;
    final maps = await db.query('reportes',
        where: 'estado = ?',
        whereArgs: ['pendiente'],
        orderBy: 'fechaCreacion ASC');
    return maps.map((m) => Reporte.fromMap(m)).toList();
  }

  Future<List<Reporte>> obtenerTodos() async {
    final db = await database;
    final maps = await db.query('reportes', orderBy: 'fechaCreacion DESC');
    return maps.map((m) => Reporte.fromMap(m)).toList();
  }

  Future<void> marcarEnviado(int id, String nRastreo) async {
    final db = await database;
    await db.update('reportes', {'estado': 'enviado', 'nRastreo': nRastreo},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── DIRECTORIO ───────────────────────────────────────────────────────────

  Future<void> upsertTrabajadores(List<Trabajador> lista) async {
    final db = await database;
    final batch = db.batch();
    for (final t in lista) {
      batch.insert('directorio_local', t.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> contarDirectorio() async {
    final db = await database;
    final r = await db
        .rawQuery('SELECT COUNT(*) as c FROM directorio_local WHERE activo = 1');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<int> ultimoTsSyncDirectorio() async {
    final db = await database;
    final r =
        await db.rawQuery('SELECT MAX(ts_sync) as m FROM directorio_local');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<Trabajador?> buscarPorCorreo(String correo) async {
    final db = await database;
    final maps = await db.query('directorio_local',
        where: 'correo = ? AND activo = 1',
        whereArgs: [correo.toLowerCase().trim()],
        limit: 1);
    return maps.isEmpty ? null : Trabajador.fromMap(maps.first);
  }

  Future<Trabajador?> buscarPorMatricula(String matricula) async {
    final db = await database;
    final maps = await db.query('directorio_local',
        where: 'matricula = ?',
        whereArgs: [matricula.trim()],
        limit: 1);
    return maps.isEmpty ? null : Trabajador.fromMap(maps.first);
  }

  Future<List<Trabajador>> buscarPorTexto(String texto,
      {int limit = 6}) async {
    final db = await database;
    final q = '%${texto.toLowerCase()}%';
    final maps = await db.query(
      'directorio_local',
      where:
          '(LOWER(correo) LIKE ? OR LOWER(nombre_completo) LIKE ?) AND activo = 1',
      whereArgs: [q, q],
      orderBy: 'nombre_completo ASC',
      limit: limit,
    );
    return maps.map(Trabajador.fromMap).toList();
  }

  // ─── PERSONAL ─────────────────────────────────────────────────────────────

  Future<void> upsertPersonal(List<Personal> lista) async {
    final db = await database;
    final batch = db.batch();
    for (final p in lista) {
      batch.insert('personal_local', p.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<int> contarPersonal() async {
    final db = await database;
    final r =
        await db.rawQuery('SELECT COUNT(*) as c FROM personal_local');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  Future<int> ultimoTsSyncPersonal() async {
    final db = await database;
    final r =
        await db.rawQuery('SELECT MAX(ts_sync) as m FROM personal_local');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  /// Busca en personal_local por matrícula.
  /// El join ya viene resuelto desde la API (correo, teléfono, etc. incluidos).
  Future<Personal?> buscarPersonalPorMatricula(String matricula) async {
    final db = await database;
    final maps = await db.query(
      'personal_local',
      where: 'matricula = ?',
      whereArgs: [matricula.trim()],
      limit: 1,
    );
    return maps.isEmpty ? null : Personal.fromMap(maps.first);
  }
  
  /// Marca un reporte con error permanente de datos (ej: validación del servidor).
  /// El estado 'error_datos' no se reintenta en syncs automáticos.
  Future<void> marcarErrorPermanente(int id) async {
    final db = await database;
    await db.update(
      'reportes',
      {'estado': 'error_datos'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}