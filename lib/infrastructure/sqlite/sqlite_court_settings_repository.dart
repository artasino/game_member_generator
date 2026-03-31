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

    final dynamic decoded = jsonDecode(maps.first['value']);
    if (decoded is List<dynamic>) {
      return CourtSettings(
        decoded.map((t) => MatchType.values[t as int]).toList(),
      );
    }

    final Map<String, dynamic> map = decoded as Map<String, dynamic>;
    final types = (map['matchTypes'] as List<dynamic>? ?? [])
        .map((t) => MatchType.values[t as int])
        .toList();
    final autoCourtCount = (map['autoCourtCount'] as int?) ?? 2;
    final autoCourtPolicyIndex = (map['autoCourtPolicy'] as int?) ?? 1;
    final isAutoRecommendMode = (map['isAutoRecommendMode'] as bool?) ?? false;

    return CourtSettings(
      types.isEmpty ? [MatchType.menDoubles] : types,
      autoCourtCount: autoCourtCount,
      autoCourtPolicy: AutoCourtPolicy.values[autoCourtPolicyIndex],
      isAutoRecommendMode: isAutoRecommendMode,
    );
  }

  @override
  Future<void> update(CourtSettings settings) async {
    final db = await _dbHelper.database;
    final payload = {
      'matchTypes': settings.matchTypes.map((t) => t.index).toList(),
      'autoCourtCount': settings.autoCourtCount,
      'autoCourtPolicy': settings.autoCourtPolicy.index,
      'isAutoRecommendMode': settings.isAutoRecommendMode,
    };
    await db.insert(
      'settings',
      {
        'key': _settingsKey,
        'value': jsonEncode(payload),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
