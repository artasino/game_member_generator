import 'package:flutter/material.dart';
import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository.dart';

class PlayerNotifier extends ChangeNotifier {
  final PlayerRepository repository;
  List<Player> _players = [];

  PlayerNotifier(this.repository) {
    _refresh();
  }

  List<Player> get players => _players;

  void _refresh() {
    _players = repository.getAll();
    notifyListeners();
  }

  void addPlayer(Player player) {
    repository.add(player);
    _refresh();
  }

  void updatePlayer(Player player) {
    repository.update(player);
    _refresh();
  }

  void toggleActive(Player player) {
    final updated = player.copyWith(isActive: !player.isActive);
    repository.update(updated);
    _refresh();
  }

  void removePlayer(String id) {
    repository.remove(id);
    _refresh();
  }
}
