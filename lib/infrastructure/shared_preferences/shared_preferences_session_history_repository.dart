import 'dart:convert';

import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/repository/session_repository/session_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_key_migrator.dart';

class SharedPreferencesSessionHistoryRepository
    implements SessionHistoryRepository {
  static const String _sessionsKey = 'gmg.sessions.v1';
  static const List<String> _legacySessionsKeys = ['sessions'];

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<void> add(Session session) async {
    final sessions = await getAll();
    final index = sessions.indexWhere((s) => s.index == session.index);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
      sessions.sort((a, b) => a.index.compareTo(b.index));
    }
    await _saveAll(sessions);
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_sessionsKey);
  }

  @override
  Future<List<Session>> getAll() async {
    final prefs = await _prefs;
    final jsonString = await SharedPreferencesKeyMigrator.readStringWithMigration(
      prefs,
      currentKey: _sessionsKey,
      legacyKeys: _legacySessionsKeys,
    );
    if (jsonString == null || jsonString.isEmpty) return [];

    final data = jsonDecode(jsonString) as List<dynamic>;
    final sessions = data
        .map((item) => Session.fromJson(item as Map<String, dynamic>))
        .toList();
    sessions.sort((a, b) => a.index.compareTo(b.index));
    return sessions;
  }

  @override
  Future<void> update(Session session) async {
    await add(session);
  }

  Future<void> _saveAll(List<Session> sessions) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey, jsonString);
  }
}
