import 'package:sqflite/sqflite.dart';

import '../../domain/entities/shuttle_usage_record.dart';
import '../../domain/repository/shuttle_usage_repository.dart';
import 'database_helper.dart';

class SqliteShuttleUsageRepository implements ShuttleUsageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'shuttle_usage';

  @override
  Future<void> save(ShuttleUsageRecord record) async {
    final db = await _dbHelper.database;
    await db.insert(
      _tableName,
      record.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ShuttleUsageRecord>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query(_tableName, orderBy: 'date DESC');

    return maps.map((map) => ShuttleUsageRecord.fromJson(map)).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
