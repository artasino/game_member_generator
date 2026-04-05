import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/expense_item.dart';
import '../../domain/repository/expense_repository.dart';
import 'database_helper.dart';

class SqliteExpenseRepository implements ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _settingsKey = 'expense_calculation_state';
  static const String _tableName = 'settings';

  @override
  Future<ExpenseCalculationState?> get() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [_settingsKey],
    );

    if (maps.isEmpty) {
      return null;
    }

    try {
      final dynamic decoded = jsonDecode(maps.first['value']);
      return ExpenseCalculationState.fromJson(decoded as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> save(ExpenseCalculationState state) async {
    final db = await _dbHelper.database;
    await db.insert(
      _tableName,
      {
        'key': _settingsKey,
        'value': jsonEncode(state.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
