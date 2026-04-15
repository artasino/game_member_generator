import 'dart:convert';

import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/repository/court_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_key_migrator.dart';

class SharedPreferencesCourtSettingsRepository
    implements CourtSettingsRepository {
  static const String _settingsKey = 'gmg.court_match_types.v1';
  static const List<String> _legacySettingsKeys = ['court_match_types'];

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<CourtSettings> get() async {
    final prefs = await _prefs;
    final jsonString = await SharedPreferencesKeyMigrator.readStringWithMigration(
      prefs,
      currentKey: _settingsKey,
      legacyKeys: _legacySettingsKeys,
    );
    if (jsonString == null || jsonString.isEmpty) {
      return CourtSettings([MatchType.maleDoubles]);
    }

    final dynamic decoded = jsonDecode(jsonString);
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
    final isAutoRecommendMode =
        (map['isAutoRecommendMode'] as bool?) ?? false;

    return CourtSettings(
      types.isEmpty ? [MatchType.maleDoubles] : types,
      autoCourtCount: autoCourtCount,
      autoCourtPolicy: AutoCourtPolicy.values[autoCourtPolicyIndex],
      isAutoRecommendMode: isAutoRecommendMode,
    );
  }

  @override
  Future<void> update(CourtSettings settings) async {
    final prefs = await _prefs;
    final payload = {
      'matchTypes': settings.matchTypes.map((t) => t.index).toList(),
      'autoCourtCount': settings.autoCourtCount,
      'autoCourtPolicy': settings.autoCourtPolicy.index,
      'isAutoRecommendMode': settings.isAutoRecommendMode,
    };
    await prefs.setString(_settingsKey, jsonEncode(payload));
  }
}
