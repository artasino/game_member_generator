import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';
import '../services/player_exchange_service.dart';
import 'session_notifier.dart';

class PlayerNotifier extends ChangeNotifier {
  final PlayerRepository repository;
  final PlayerExchangeService _exchangeService = PlayerExchangeService();
  List<Player> _players = [];
  SessionNotifier? _sessionNotifier;

  PlayerNotifier(this.repository) {
    _refresh();
  }

  void setSessionNotifier(SessionNotifier notifier) {
    _sessionNotifier = notifier;
  }

  List<Player> get players => _players;

  Future<void> _publishPlayers(List<Player> nextPlayers) async {
    _players = nextPlayers;
    notifyListeners();
    await _sessionNotifier?.onPlayersUpdated();
  }

  Future<void> _refresh() async {
    final snapshot = await repository.getAll();
    await _publishPlayers(snapshot);
  }

  String? getPlayerNameById(String id) {
    return _players.firstWhereOrNull((p) => p.id == id)?.name;
  }

  Future<bool> addPlayer(Player player) async {
    final snapshot = await repository.getAll();
    if (snapshot.contains(player)) return false;

    await repository.add(player);
    await _publishPlayers([...snapshot, player]);
    return true;
  }

  Future<(int added, int skipped)> addPlayersBulk(List<Player> players) async {
    final snapshot = await repository.getAll();
    final existingIds = snapshot.map((p) => p.id).toSet();
    final playersToAdd = <Player>[];
    int skipped = 0;

    for (final player in players) {
      if (
          existingIds.contains(player.id) ||
          snapshot.contains(player) ||
          playersToAdd.contains(player)) {
        skipped++;
        continue;
      }
      playersToAdd.add(player);
      existingIds.add(player.id);
    }

    if (playersToAdd.isNotEmpty) {
      await repository.addAll(playersToAdd);
    }

    await _publishPlayers([...snapshot, ...playersToAdd]);
    return (playersToAdd.length, skipped);
  }

  Future<void> updatePlayer(Player player) async {
    await repository.update(player);
    await _refresh();
  }

  Future<void> toggleActive(Player player) async {
    await updatePlayer(player.copyWith(isActive: !player.isActive));
  }

  Future<int> setActiveBulk(List<String> ids, bool isActive) async {
    final uniqueIds = ids.toSet();
    int updated = 0;
    final playersToUpdate = <Player>[];
    for (final player in _players) {
      if (!uniqueIds.contains(player.id) || player.isActive == isActive) {
        continue;
      }
      playersToUpdate.add(player.copyWith(isActive: isActive));
      updated++;
    }
    await repository.updateAll(playersToUpdate);
    await _refresh();
    return updated;
  }

  Future<void> removePlayer(String id) async {
    await repository.remove(id);
    await _refresh();
  }

  Future<int> removePlayersBulk(List<String> ids) async {
    final uniqueIds = ids.toSet();
    await repository.removeAll(uniqueIds.toList());
    await _refresh();
    return uniqueIds.length;
  }

  Future<void> _updatePlayers(List<Player> updatedList) async {
    await repository.updateAll(updatedList);
    await _refresh();
  }

  Future<void> linkPartner(String playerId, String partnerId) async {
    final player = _players.firstWhereOrNull((p) => p.id == playerId);
    final partner = _players.firstWhereOrNull((p) => p.id == partnerId);
    if (player == null || partner == null) return;

    final List<Player> targets = [];
    final oldPartnerA =
        _players.firstWhereOrNull((p) => p.excludedPartnerId == player.id);
    if (oldPartnerA != null && oldPartnerA.id != partnerId) {
      targets.add(oldPartnerA.copyWith(excludedPartnerId: null));
    }
    final oldPartnerB =
        _players.firstWhereOrNull((p) => p.excludedPartnerId == partner.id);
    if (oldPartnerB != null && oldPartnerB.id != playerId) {
      targets.add(oldPartnerB.copyWith(excludedPartnerId: null));
    }

    targets.add(player.copyWith(excludedPartnerId: partner.id));
    targets.add(partner.copyWith(excludedPartnerId: player.id));

    await _updatePlayers(targets);
  }

  Future<void> unlinkPartner(String playerId) async {
    final player = _players.firstWhereOrNull((p) => p.id == playerId);
    if (player == null) return;

    final List<Player> targets = [player.copyWith(excludedPartnerId: null)];
    final partner =
        _players.firstWhereOrNull((p) => p.id == player.excludedPartnerId);
    if (partner != null) {
      targets.add(partner.copyWith(excludedPartnerId: null));
    }

    await _updatePlayers(targets);
  }

  // --- Import / Export ---

  Future<void> exportPlayersToClipboard() async {
    final snapshot = await repository.getAll();
    await _exchangeService.exportToClipboard(snapshot);
  }

  Future<String> importPlayersFromClipboard() async {
    final imported = await _exchangeService.importFromClipboard();
    if (imported == null) return 'インポートに失敗しました';
    return _applyImportedList(imported);
  }

  Future<void> exportPlayersToFile(String format) async {
    final snapshot = await repository.getAll();
    await _exchangeService.exportToFile(snapshot, format);
  }

  Future<String> importPlayersFromFile() async {
    final imported = await _exchangeService.importFromFile();
    if (imported == null) return 'ファイルが選択されなかったか、インポートに失敗しました';
    return _applyImportedList(imported);
  }

  Future<String> _applyImportedList(List<Player> list) async {
    final snapshot = await repository.getAll();
    final existingIds = snapshot.map((p) => p.id).toSet();
    final playersToUpsert = <Player>[];
    int count = 0;
    int skipCount = 0;

    for (final player in list) {
      if (existingIds.contains(player.id)) {
        playersToUpsert.add(player);
        count++;
        continue;
      }
      if (snapshot.contains(player) || playersToUpsert.contains(player)) {
        skipCount++;
        continue;
      }
      playersToUpsert.add(player);
      existingIds.add(player.id);
      count++;
    }

    if (playersToUpsert.isNotEmpty) {
      await repository.addAll(playersToUpsert);
    }

    final upsertById = {for (final player in playersToUpsert) player.id: player};
    final nextPlayers = [
      for (final player in snapshot) upsertById.remove(player.id) ?? player,
      ...upsertById.values,
    ];
    await _publishPlayers(nextPlayers);

    String msg = '$count名のメンバーをインポートしました';
    if (skipCount > 0) msg += ' ($skipCount名は重複のためスキップ)';
    return msg;
  }
}
