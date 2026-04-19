import 'package:sqflite/sqflite.dart';

import '../../domain/entities/shuttle_usage_record.dart';
import '../../domain/repository/shuttle_usage_repository.dart';
import 'database_helper.dart';

class SqliteShuttleUsageRepository implements ShuttleUsageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'shuttle_usage';

  Future<void> _ensureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        total_shuttles INTEGER,
        match_counts TEXT
      )
    ''');

    final columns = await db.rawQuery('PRAGMA table_info($_tableName)');
    final columnNames = columns
        .map((c) => (c['name'] as String?) ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!columnNames.contains('date')) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN date TEXT');
    }
    if (!columnNames.contains('total_shuttles')) {
      await db
          .execute('ALTER TABLE $_tableName ADD COLUMN total_shuttles INTEGER');
    }
    if (!columnNames.contains('match_counts')) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN match_counts TEXT');
    }
  }

  @override
  Future<void> save(ShuttleUsageRecord record) async {
    final db = await _dbHelper.database;
    await _ensureTable(db);
    await db.insert(
      _tableName,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ShuttleUsageRecord>> getAll() async {
    final db = await _dbHelper.database;
    await _ensureTable(db);
    final List<Map<String, dynamic>> maps =
        await db.query(_tableName, orderBy: 'date DESC');

    return maps.map((map) => ShuttleUsageRecord.fromJson(map)).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await _ensureTable(db);
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
