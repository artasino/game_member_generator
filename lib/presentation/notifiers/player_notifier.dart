import 'package:flutter/material.dart';
import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';
import 'session_notifier.dart';

class PlayerNotifier extends ChangeNotifier {
  final PlayerRepository repository;
  List<Player> _players = [];
  SessionNotifier? _sessionNotifier;

  PlayerNotifier(this.repository);

  // SessionNotifierを後からセットするためのメソッド
  void setSessionNotifier(SessionNotifier notifier) {
    _sessionNotifier = notifier;
  }

  List<Player> get players => _players;

  Future<void> _refresh() async {
    _players = await repository.getAll();
    notifyListeners();

    // メンバが変更されたら、統計も再計算するように通知
    await _sessionNotifier?.onPlayersUpdated();
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
