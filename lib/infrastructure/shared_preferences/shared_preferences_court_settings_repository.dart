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

    final List<dynamic> types = jsonDecode(jsonString);
    return CourtSettings(types.map((t) => MatchType.values[t as int]).toList());
  }

  @override
  Future<void> update(CourtSettings settings) async {
    final prefs = await _prefs;
    final types = settings.matchTypes.map((t) => t.index).toList();
    await prefs.setString(_settingsKey, jsonEncode(types));
  }
}
