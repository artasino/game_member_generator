import 'package:sqflite/sqflite.dart';

import '../../domain/entities/shuttle_stock.dart';
import '../../domain/repository/shuttle_stock_repository.dart';
import 'database_helper.dart';

class SqliteShuttleStockRepository implements ShuttleStockRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _tableName = 'shuttle_stocks';

  @override
  Future<void> save(ShuttleStock stock) async {
    final db = await _dbHelper.database;
    await db.insert(
      _tableName,
      stock.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ShuttleStock>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query(_tableName, orderBy: 'purchase_date DESC');

    return maps.map((map) => ShuttleStock.fromJson(map)).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
