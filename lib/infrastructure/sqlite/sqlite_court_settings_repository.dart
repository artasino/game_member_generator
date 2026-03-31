import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/repository/court_settings_repository.dart';
import 'database_helper.dart';

class SqliteCourtSettingsRepository implements CourtSettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _settingsKey = 'court_match_types';
  static const String _tableName = 'settings';

  @override
  Future<CourtSettings> get() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [_settingsKey],
    );

    if (maps.isEmpty) {
      return const CourtSettings([]);
    }

    final dynamic decoded = jsonDecode(maps.first['value']);
    return CourtSettings.fromJson(decoded);
  }

  @override
  Future<void> update(CourtSettings settings) async {
    final db = await _dbHelper.database;
    await db.insert(
      _tableName,
      {
        'key': _settingsKey,
        'value': jsonEncode(settings.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
