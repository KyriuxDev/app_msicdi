import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reporte.dart';

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE reportes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            matricula TEXT NOT NULL,
            nombreReportador TEXT NOT NULL,
            nserie TEXT NOT NULL,
            falla TEXT NOT NULL,
            telefono TEXT,
            correo TEXT,
            usuario TEXT,
            contrasena TEXT,
            ipEquipo TEXT,
            depto TEXT,
            ipOrigen TEXT,
            estado TEXT DEFAULT 'pendiente',
            nRastreo TEXT,
            fechaCreacion TEXT
          )
        ''');
      },
    );
  }

  // Guardar nuevo reporte
  Future<int> insertarReporte(Reporte reporte) async {
    final db = await database;
    return await db.insert('reportes', reporte.toMap());
  }

  // Obtener todos los reportes pendientes
  Future<List<Reporte>> obtenerPendientes() async {
    final db = await database;
    final maps = await db.query(
      'reportes',
      where: 'estado = ?',
      whereArgs: ['pendiente'],
      orderBy: 'fechaCreacion ASC',
    );
    return maps.map((m) => Reporte.fromMap(m)).toList();
  }

  // Obtener todos los reportes (para mostrar historial)
  Future<List<Reporte>> obtenerTodos() async {
    final db = await database;
    final maps = await db.query(
      'reportes',
      orderBy: 'fechaCreacion DESC',
    );
    return maps.map((m) => Reporte.fromMap(m)).toList();
  }

  // Marcar como enviado y guardar nRastreo
  Future<void> marcarEnviado(int id, String nRastreo) async {
    final db = await database;
    await db.update(
      'reportes',
      {'estado': 'enviado', 'nRastreo': nRastreo},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}