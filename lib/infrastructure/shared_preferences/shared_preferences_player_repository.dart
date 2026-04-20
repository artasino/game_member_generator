import 'dart:convert';

import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_key_migrator.dart';

class SharedPreferencesPlayerRepository implements PlayerRepository {
  static const String _playersKey = 'gmg.players.v1';
  static const List<String> _legacyPlayersKeys = ['players'];

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  Future<void> add(Player player) async {
    final players = await getAll();
    final index = players.indexWhere((p) => p.id == player.id);
    if (index >= 0) {
      players[index] = player;
    } else {
      players.add(player);
    }
    await _saveAll(players);
  }

  @override
  Future<void> addAll(List<Player> players) async {
    if (players.isEmpty) return;

    final currentPlayers = await getAll();
    final playerById = {for (final p in currentPlayers) p.id: p};
    for (final player in players) {
      playerById[player.id] = player;
    }
    await _saveAll(playerById.values.toList());
  }

  @override
  Future<List<Player>> getActive() async {
    final players = await getAll();
    return players.where((p) => p.isActive).toList();
  }

  @override
  Future<List<Player>> getAll() async {
    final prefs = await _prefs;
    final jsonString = await SharedPreferencesKeyMigrator.readStringWithMigration(
      prefs,
      currentKey: _playersKey,
      legacyKeys: _legacyPlayersKeys,
    );
    if (jsonString == null || jsonString.isEmpty) return [];

    final data = jsonDecode(jsonString) as List<dynamic>;
    return data
        .map((item) => Player.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> remove(String id) async {
    final players = await getAll();
    players.removeWhere((player) => player.id == id);
    await _saveAll(players);
  }

  @override
  Future<void> update(Player player) async {
    await add(player);
  }

  @override
  Future<void> updateAll(List<Player> players) async {
    await addAll(players);
  }

  @override
  Future<void> removeAll(List<String> ids) async {
    if (ids.isEmpty) return;

    final idSet = ids.toSet();
    final players = await getAll();
    players.removeWhere((player) => idSet.contains(player.id));
    await _saveAll(players);
  }

  Future<void> _saveAll(List<Player> players) async {
    final prefs = await _prefs;
    final jsonString = jsonEncode(players.map((p) => p.toJson()).toList());
    await prefs.setString(_playersKey, jsonString);
  }
}
