import 'package:sqflite/sqflite.dart';

import '../../domain/entities/shuttle_stock.dart';
import '../../domain/repository/shuttle_stock_repository.dart';
import 'database_helper.dart';

class SqliteShuttleStockRepository implements ShuttleStockRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<void> save(ShuttleStock stock) async {
    final db = await _dbHelper.database;
    await db.insert(
      'shuttle_stocks',
      {
        if (stock.id != null) 'id': stock.id,
        'name': stock.name,
        'price_per_dozens': stock.pricePerDozens,
        'payer_id': stock.payerId,
        'purchase_date': stock.purchaseDate.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ShuttleStock>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query('shuttle_stocks', orderBy: 'purchase_date DESC');

    return maps.map((map) {
      return ShuttleStock(
        id: map['id'] as int,
        name: map['name'] as String,
        pricePerDozens: map['price_per_dozens'] as double,
        payerId: map['payer_id'] as String?,
        purchaseDate: DateTime.parse(map['purchase_date'] as String),
      );
    }).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete('shuttle_stocks', where: 'id = ?', whereArgs: [id]);
  }
}
