import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/member.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'trailguard.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE detections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            name TEXT,
            status TEXT,
            latitude REAL,
            longitude REAL,
            battery INTEGER,
            timestamp INTEGER
          )
        ''');
      },
    );
  }

  // Insertar una detección
  static Future<void> insertDetection(Member member) async {
    final db = await database;
    await db.insert('detections', member.toMap());
  }

  // Obtener todos los minutos distintos registrados
  static Future<List<int>> getMinuteBuckets() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT timestamp / 60000 AS bucket FROM detections ORDER BY bucket ASC',
    );
    return result.map((r) => r['bucket'] as int).toList();
  }

  // Obtener posición promedio por miembro para un minuto dado
  static Future<List<Map<String, dynamic>>> getAveragePositions(
    int bucket,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT
        device_id,
        name,
        status,
        AVG(latitude)  AS latitude,
        AVG(longitude) AS longitude
      FROM detections
      WHERE timestamp / 60000 = ?
      GROUP BY device_id
    ''',
      [bucket],
    );
  }

  // Última detección por dispositivo (para home screen)
  static Future<List<Map<String, dynamic>>> getLatestPerDevice() async {
    final db = await database;
    return db.rawQuery('''
      SELECT device_id, name, status, latitude, longitude, battery,
             MAX(timestamp) AS timestamp
      FROM detections
      GROUP BY device_id
      ORDER BY timestamp DESC
    ''');
  }

  // Para alerta: dispositivos sin detección en los últimos 10 minutos
  static Future<List<String>> getMissingDevices() async {
    final db = await database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - 600000;
    final result = await db.rawQuery(
      '''
      SELECT device_id, name, MAX(timestamp) AS last_seen
      FROM detections
      GROUP BY device_id
      HAVING last_seen < ?
    ''',
      [cutoff],
    );
    return result.map((r) => r['name'] as String).toList();
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('detections');
  }
}
