import 'dart:convert';

import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/repository/court_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesCourtSettingsRepository
    implements CourtSettingsRepository {
  static const String _settingsKey = 'court_match_types';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<CourtSettings> get() async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(_settingsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return CourtSettings([MatchType.menDoubles]);
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

    return CourtSettings(
      types.isEmpty ? [MatchType.menDoubles] : types,
      autoCourtCount: autoCourtCount,
      autoCourtPolicy: AutoCourtPolicy.values[autoCourtPolicyIndex],
    );
  }

  @override
  Future<void> update(CourtSettings settings) async {
    final prefs = await _prefs;
    final payload = {
      'matchTypes': settings.matchTypes.map((t) => t.index).toList(),
      'autoCourtCount': settings.autoCourtCount,
      'autoCourtPolicy': settings.autoCourtPolicy.index,
    };
    await prefs.setString(_settingsKey, jsonEncode(payload));
  }
}
