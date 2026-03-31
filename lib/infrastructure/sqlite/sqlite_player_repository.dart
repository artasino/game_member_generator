import 'package:sqflite/sqflite.dart';

import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';
import 'database_helper.dart';

class SqlitePlayerRepository implements PlayerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'players';

  @override
  Future<List<Player>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return maps.map((map) => Player.fromJson(map)).toList();
  }

  @override
  Future<List<Player>> getActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return maps.map((map) => Player.fromJson(map)).toList();
  }

  @override
  Future<void> add(Player player) async {
    final db = await _dbHelper.database;
    await db.insert(
      _tableName,
      player.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Player player) async {
    final db = await _dbHelper.database;
    await db.update(
      _tableName,
      player.toJson(),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  @override
  Future<void> remove(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
