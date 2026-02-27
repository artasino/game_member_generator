import 'package:flutter/material.dart';
import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';

class PlayerNotifier extends ChangeNotifier {
  final PlayerRepository repository;
  List<Player> _players = [];

  PlayerNotifier(this.repository) {
    _refresh();
  }

  List<Player> get players => _players;

  Future<void> _refresh() async {
    _players = await repository.getAll();
    notifyListeners();
  }

  Future<void> addPlayer(Player player) async {
    await repository.add(player);
    await _refresh();
  }

  Future<void> updatePlayer(Player player) async {
    await repository.update(player);
    await _refresh();
  }

  Future<void> toggleActive(Player player) async {
    final updated = player.copyWith(isActive: !player.isActive);
    await repository.update(updated);
    await _refresh();
  }

  Future<void> removePlayer(String id) async {
    await repository.remove(id);
    await _refresh();
  }
}
