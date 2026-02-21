import 'package:game_member_generator/domain/repository/player_repository.dart';

import '../entities/player.dart';

class InMemoryPlayerRepository implements PlayerRepository {
  final List<Player> _players = [];

  @override
  List<Player> getAll() => List.unmodifiable(_players);

  @override
  List<Player> getActive() =>
      _players.where((p) => p.isActive).toList();

  @override
  void add(Player player) {
    _players.add(player);
  }

  @override
  void update(Player player) {
    final index =
    _players.indexWhere((p) => p.id == player.id);
    if (index != -1) {
      _players[index] = player;
    }
  }

  @override
  void remove(String id) {
    _players.removeWhere((p) => p.id == id);
  }
}