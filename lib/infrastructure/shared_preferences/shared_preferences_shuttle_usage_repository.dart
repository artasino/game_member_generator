import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/shuttle_usage_record.dart';
import '../../domain/repository/shuttle_usage_repository.dart';
import 'shared_preferences_key_migrator.dart';

class SharedPreferencesShuttleUsageRepository
    implements ShuttleUsageRepository {
  static const String _key = 'gmg.shuttle_usage.v1';
  static const List<String> _legacyKeys = ['shuttle_usage'];

  @override
  Future<void> save(ShuttleUsageRecord record) async {
    final records = await getAll();
    if (record.id != null) {
      final index = records.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        records[index] = record;
      } else {
        records.add(record);
      }
    } else {
      final newId = records.isEmpty
          ? 1
          : (records.map((r) => r.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
      records.add(ShuttleUsageRecord(
        id: newId,
        date: record.date,
        totalShuttles: record.totalShuttles,
        matchTypeCounts: record.matchTypeCounts,
      ));
    }
    await _saveAll(records);
  }

  @override
  Future<List<ShuttleUsageRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = await SharedPreferencesKeyMigrator.readStringWithMigration(
      prefs,
      currentKey: _key,
      legacyKeys: _legacyKeys,
    );
    if (jsonString == null) return [];
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded
        .map(
            (item) => ShuttleUsageRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> delete(int id) async {
    final records = await getAll();
    records.removeWhere((r) => r.id == id);
    await _saveAll(records);
  }

  Future<void> _saveAll(List<ShuttleUsageRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(records.map((r) => r.toJson()).toList()));
  }
}
