import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';
import 'session_notifier.dart';

class PlayerNotifier extends ChangeNotifier {
  final PlayerRepository repository;
  List<Player> _players = [];
  SessionNotifier? _sessionNotifier;

  PlayerNotifier(this.repository);

  void setSessionNotifier(SessionNotifier notifier) {
    _sessionNotifier = notifier;
  }

  List<Player> get players => _players;

  Future<void> _refresh() async {
    _players = await repository.getAll();
    notifyListeners();
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

  /// 現在のメンバリストをJSON文字列としてクリップボードにコピー
  Future<void> exportPlayersToClipboard() async {
    final List<Map<String, dynamic>> jsonList = _players.map((p) => p.toJson()).toList();
    final String jsonString = jsonEncode(jsonList);
    await Clipboard.setData(ClipboardData(text: jsonString));
  }

  /// クリップボードのJSON文字列からメンバを一括登録
  Future<String> importPlayersFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null) return 'クリップボードが空です';

    try {
      final List<dynamic> decoded = jsonDecode(data.text!);
      int count = 0;
      for (var item in decoded) {
        final player = Player.fromJson(item as Map<String, dynamic>);
        // IDが重複しないように現在の時間ベースで新しく振るか、そのまま使うか
        // ここでは一括移行を想定してそのまま追加を試みる
        await repository.add(player);
        count++;
      }
      await _refresh();
      return '$count名のメンバをインポートしました';
    } catch (e) {
      return 'インポートに失敗しました。正しい形式のデータではありません。';
    }
  }
}
