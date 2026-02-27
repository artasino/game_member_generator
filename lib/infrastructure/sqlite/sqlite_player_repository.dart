import 'package:sqflite/sqflite.dart';
import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';
import 'database_helper.dart';

class SqlitePlayerRepository implements PlayerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<List<Player>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('players');
    return List.generate(maps.length, (i) {
      return Player.fromJson(maps[i]);
    });
  }

  @override
  Future<List<Player>> getActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'players',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) {
      return Player.fromJson(maps[i]);
    });
  }

  @override
  Future<void> add(Player player) async {
    final db = await _dbHelper.database;
    await db.insert(
      'players',
      player.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Player player) async {
    final db = await _dbHelper.database;
    await db.update(
      'players',
      player.toJson(),
      where: 'id = ?',
      whereArgs: [player.id],
    );
  }

  @override
  Future<void> remove(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'players',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
