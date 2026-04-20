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
  Future<void> addAll(List<Player> players) async {
    if (players.isEmpty) return;

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final player in players) {
        batch.insert(
          _tableName,
          player.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
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
  Future<void> updateAll(List<Player> players) async {
    if (players.isEmpty) return;

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final player in players) {
        batch.update(
          _tableName,
          player.toJson(),
          where: 'id = ?',
          whereArgs: [player.id],
        );
      }
      await batch.commit(noResult: true);
    });
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

  @override
  Future<void> removeAll(List<String> ids) async {
    if (ids.isEmpty) return;

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in ids) {
        batch.delete(
          _tableName,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
