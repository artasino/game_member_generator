import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/repository/court_settings_repository.dart';
import 'database_helper.dart';

class SqliteCourtSettingsRepository implements CourtSettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String _settingsKey = 'court_match_types';

  @override
  Future<CourtSettings> get() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings', 
      where: 'key = ?', 
      whereArgs: [_settingsKey],
    );
    
    if (maps.isEmpty) {
      return CourtSettings([MatchType.menDoubles]);
    }
    
    final List<dynamic> types = jsonDecode(maps.first['value']);
    return CourtSettings(types.map((t) => MatchType.values[t as int]).toList());
  }

  @override
  Future<void> update(CourtSettings settings) async {
    final db = await _dbHelper.database;
    final types = settings.matchTypes.map((t) => t.index).toList();
    await db.insert(
      'settings',
      {
        'key': _settingsKey,
        'value': jsonEncode(types),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
