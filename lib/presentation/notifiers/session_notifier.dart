import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/session.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_making_service.dart';

/// プレイヤーの出場統計を保持するクラス
class PlayerStats {
  final int totalMatches;
  final Map<MatchType, int> typeCounts;

  PlayerStats({required this.totalMatches, required this.typeCounts});
}

class SessionNotifier extends ChangeNotifier {
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final MatchMakingService matchMakingService;

  List<Session> _sessions = [];
  List<Session> get sessions => _sessions;

  SessionNotifier({
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.matchMakingService,
  }) {
    _refresh();
  }

  /// 全プレイヤーの出場統計を計算する
  /// key: Player.id, value: PlayerStats
  Map<String, PlayerStats> get playerStats {
    final Map<String, int> totals = {};
    final Map<String, Map<MatchType, int>> breakdown = {};

    // 最初に全プレイヤーを 0 で初期化する
    final allPlayers = matchMakingService.playerRepository.getAll();
    for (final player in allPlayers) {
      totals[player.id] = 0;
      breakdown[player.id] = {};
    }

    for (final session in _sessions) {
      for (final game in session.games) {
        final playersInGame = [
          game.teamA.player1,
          game.teamA.player2,
          game.teamB.player1,
          game.teamB.player2,
        ];
        
        for (final player in playersInGame) {
          // 削除されたプレイヤーがセッションに残っている場合も考慮
          totals[player.id] = (totals[player.id] ?? 0) + 1;
          
          final playerBreakdown = breakdown.putIfAbsent(player.id, () => {});
          playerBreakdown[game.type] = (playerBreakdown[game.type] ?? 0) + 1;
        }
      }
    }

    return totals.map((playerId, total) => MapEntry(
      playerId,
      PlayerStats(
        totalMatches: total,
        typeCounts: breakdown[playerId] ?? {},
      ),
    ));
  }

  Future<void> _refresh() async {
    final fetchedSessions = await sessionRepository.getAll();
    _sessions = List.from(fetchedSessions);
    notifyListeners();
  }

  Future<void> updateSession(Session session) async {
    final index = _sessions.indexWhere((s) => s.index == session.index);
    if (index != -1) {
      _sessions[index] = session;
      notifyListeners();
    }
  }

  Future<void> generateSessionWithSettings(CourtSettings settings) async {
    courtSettingsRepository.update(settings);
    final allActivePlayers = matchMakingService.playerRepository.getActive();
    final games = matchMakingService.generateMatches(
      matchTypes: settings.matchTypes,
    );

    final playingPlayerIds = <String>{};
    for (var game in games) {
      playingPlayerIds.add(game.teamA.player1.id);
      playingPlayerIds.add(game.teamA.player2.id);
      playingPlayerIds.add(game.teamB.player1.id);
      playingPlayerIds.add(game.teamB.player2.id);
    }

    final restingPlayers = allActivePlayers
        .where((p) => !playingPlayerIds.contains(p.id))
        .toList();

    final nextIndex = _sessions.length + 1;
    final newSession = Session(nextIndex, games, restingPlayers: restingPlayers);

    await sessionRepository.add(newSession);
    await _refresh();
  }

  Future<void> clearHistory() async {
    await sessionRepository.clear();
    await _refresh();
  }

  CourtSettings getCurrentSettings() {
    return courtSettingsRepository.get();
  }
}
