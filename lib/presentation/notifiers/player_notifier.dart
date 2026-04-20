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

  Future<void> _refresh() async {
    _players = await repository.getAll();
    notifyListeners();
    await _sessionNotifier?.onPlayersUpdated();
  }

  bool _exists(Player player) {
    return _players.contains(player);
  }

  String? getPlayerNameById(String id) {
    return _players.firstWhereOrNull((p) => p.id == id)?.name;
  }

  Future<bool> addPlayer(Player player) async {
    await _refresh();
    if (_exists(player)) return false;
    await repository.add(player);
    await _refresh();
    return true;
  }

  Future<(int added, int skipped)> addPlayersBulk(List<Player> players) async {
    await _refresh();
    final existingIds = _players.map((p) => p.id).toSet();
    int added = 0;
    int skipped = 0;
    final playersToAdd = <Player>[];

    for (final player in players) {
      if (existingIds.contains(player.id) || _exists(player)) {
        skipped++;
        continue;
      }
      playersToAdd.add(player);
      existingIds.add(player.id);
      added++;
    }

    await repository.addAll(playersToAdd);
    await _refresh();
    return (added, skipped);
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
    await _refresh();
    await _exchangeService.exportToClipboard(_players);
  }

  Future<String> importPlayersFromClipboard() async {
    final imported = await _exchangeService.importFromClipboard();
    if (imported == null) return 'インポートに失敗しました';
    return await _applyImportedList(imported);
  }

  Future<void> exportPlayersToFile(String format) async {
    await _refresh();
    await _exchangeService.exportToFile(_players, format);
  }

  Future<String> importPlayersFromFile() async {
    final imported = await _exchangeService.importFromFile();
    if (imported == null) return 'ファイルが選択されなかったか、インポートに失敗しました';
    return await _applyImportedList(imported);
  }

  Future<String> _applyImportedList(List<Player> list) async {
    await _refresh();
    final existingIds = _players.map((p) => p.id).toSet();
    int count = 0;
    int skipCount = 0;
    final playersToUpsert = <Player>[];
    for (final player in list) {
      if (existingIds.contains(player.id)) {
        playersToUpsert.add(player);
        count++;
        continue;
      }
      if (_exists(player) || playersToUpsert.contains(player)) {
        skipCount++;
        continue;
      }
      playersToUpsert.add(player);
      existingIds.add(player.id);
      count++;
    }
    await repository.addAll(playersToUpsert);
    await _refresh();
    String msg = '$count名のメンバーをインポートしました';
    if (skipCount > 0) msg += ' ($skipCount名は重複のためスキップ)';
    return msg;
  }
}
