import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';

import '../../entities/player.dart';

class InMemoryPlayerRepository implements PlayerRepository {
  final List<Player> _players = [];

  @override
  Future<List<Player>> getAll() async => List.unmodifiable(_players);

  @override
  Future<List<Player>> getActive() async =>
      _players.where((p) => p.isActive).toList();

  @override
  Future<void> add(Player player) async {
    _players.add(player);
  }

  @override
  Future<void> addAll(List<Player> players) async {
    if (players.isEmpty) return;

    final existingById = {for (final player in _players) player.id: player};
    for (final player in players) {
      existingById[player.id] = player;
    }
    _players
      ..clear()
      ..addAll(existingById.values);
  }

  @override
  Future<void> update(Player player) async {
    final index = _players.indexWhere((p) => p.id == player.id);
    if (index != -1) {
      _players[index] = player;
    }
  }

  @override
  Future<void> updateAll(List<Player> players) async {
    await addAll(players);
  }

  @override
  Future<void> remove(String id) async {
    _players.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> removeAll(List<String> ids) async {
    if (ids.isEmpty) return;

    final idSet = ids.toSet();
    _players.removeWhere((p) => idSet.contains(p.id));
  }
}
