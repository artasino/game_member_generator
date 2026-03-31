import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/match_type.dart';
import '../../domain/entities/shuttle_usage_record.dart';
import '../../domain/repository/shuttle_usage_repository.dart';
import 'database_helper.dart';

class SqliteShuttleUsageRepository implements ShuttleUsageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<void> save(ShuttleUsageRecord record) async {
    final db = await _dbHelper.database;
    final matchCountsJson = jsonEncode(
      record.matchTypeCounts.map((key, value) => MapEntry(key.name, value)),
    );

    await db.insert(
      'shuttle_usage',
      {
        'date': record.date.toIso8601String(),
        'total_shuttles': record.totalShuttles,
        'match_counts': matchCountsJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ShuttleUsageRecord>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query('shuttle_usage', orderBy: 'date DESC');

    return maps.map((map) {
      final Map<String, dynamic> countsMap =
          jsonDecode(map['match_counts'] as String);
      final matchTypeCounts = countsMap.map((key, value) {
        final matchType = MatchType.values.firstWhere((e) => e.name == key);
        return MapEntry(matchType, value as int);
      });

      return ShuttleUsageRecord(
        id: map['id'] as int,
        date: DateTime.parse(map['date'] as String),
        totalShuttles: map['total_shuttles'] as int,
        matchTypeCounts: matchTypeCounts,
      );
    }).toList();
  }

  @override
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete('shuttle_usage', where: 'id = ?', whereArgs: [id]);
  }
}
