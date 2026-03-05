import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_making_service.dart';

/// プレイヤーの出場統計を保持するクラス
/// BalancedMatchingの計算に利用できる詳細な履歴を含む
class PlayerStats {
  /// 合計出場回数
  final int totalMatches;
  /// 種目別の出場回数
  final Map<MatchType, int> typeCounts;
  /// このプレイヤーが誰と何回ペア（味方）を組んだか (key: Player.id, value: 回数)
  final Map<String, int> partnerCounts;
  /// このプレイヤーが誰と何回対戦（敵）したか (key: Player.id, value: 回数)
  final Map<String, int> opponentCounts;

  PlayerStats({
    required this.totalMatches,
    required this.typeCounts,
    required this.partnerCounts,
    required this.opponentCounts,
  });

  /// 指定した相手と同じコートにいた（味方または敵）合計回数を返す
  int getInteractionCount(String otherId) =>
      (partnerCounts[otherId] ?? 0) + (opponentCounts[otherId] ?? 0);
}

class SessionNotifier extends ChangeNotifier {
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final MatchMakingService matchMakingService;

  List<Session> _sessions = [];
  List<Session> get sessions => _sessions;

  // キャッシュされた詳細統計データ
  Map<String, PlayerStats> _cachedStats = {};
  Map<String, PlayerStats> get playerStats => _cachedStats;

  SessionNotifier({
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.matchMakingService,
  }) {
    _refresh();
  }

  /// 試合履歴を走査し、BalancedMatchingに必要な詳細統計を計算する
  Future<void> _updateStats() async {
    final Map<String, int> totals = {};
    final Map<String, Map<MatchType, int>> typeBreakdowns = {};
    final Map<String, Map<String, int>> partnerBreakdowns = {};
    final Map<String, Map<String, int>> opponentBreakdowns = {};

    final allPlayers = await matchMakingService.playerRepository.getAll();
    for (final player in allPlayers) {
      final id = player.id;
      totals[id] = 0;
      typeBreakdowns[id] = {};
      partnerBreakdowns[id] = {};
      opponentBreakdowns[id] = {};
    }

    for (final session in _sessions) {
      for (final game in session.games) {
        final teamA = [game.teamA.player1, game.teamA.player2];
        final teamB = [game.teamB.player1, game.teamB.player2];

        // 各プレイヤーごとに味方と敵を記録する
        void record(Player p, Player partner, List<Player> opponents) {
          final id = p.id;
          totals[id] = (totals[id] ?? 0) + 1;
          typeBreakdowns[id]![game.type] = (typeBreakdowns[id]![game.type] ?? 0) + 1;
          
          // 味方のカウント
          partnerBreakdowns[id]![partner.id] = (partnerBreakdowns[id]![partner.id] ?? 0) + 1;
          
          // 敵のカウント
          for (final opp in opponents) {
            opponentBreakdowns[id]![opp.id] = (opponentBreakdowns[id]![opp.id] ?? 0) + 1;
          }
        }

        record(teamA[0], teamA[1], teamB);
        record(teamA[1], teamA[0], teamB);
        record(teamB[0], teamB[1], teamA);
        record(teamB[1], teamB[0], teamA);
      }
    }

    _cachedStats = totals.map((playerId, total) => MapEntry(
      playerId,
      PlayerStats(
        totalMatches: total,
        typeCounts: typeBreakdowns[playerId] ?? {},
        partnerCounts: partnerBreakdowns[playerId] ?? {},
        opponentCounts: opponentBreakdowns[playerId] ?? {},
      ),
    ));
  }

  /// 指定されたペアがそのセッションまでに組んだ回数を計算する
  int getPairCount(Team team, {int? upToIndex}) {
    int count = 0;
    final id1 = team.player1.id;
    final id2 = team.player2.id;

    for (final session in _sessions) {
      if (upToIndex != null && session.index > upToIndex) break;
      for (final game in session.games) {
        if (_isMatch(game.teamA, id1, id2) || _isMatch(game.teamB, id1, id2)) {
          count++;
        }
      }
    }
    return count;
  }

  bool _isMatch(Team team, String id1, String id2) {
    final tId1 = team.player1.id;
    final tId2 = team.player2.id;
    return (tId1 == id1 && tId2 == id2) || (tId1 == id2 && tId2 == id1);
  }

  Future<void> _refresh() async {
    final fetchedSessions = await sessionRepository.getAll();
    _sessions = List.from(fetchedSessions);
    await _updateStats();
    notifyListeners();
  }

  Future<void> updateSession(Session session) async {
    final index = _sessions.indexWhere((s) => s.index == session.index);
    if (index != -1) {
      _sessions[index] = session;
      await sessionRepository.update(session);
      await _updateStats();
      notifyListeners();
    }
  }

  Future<void> generateSessionWithSettings(CourtSettings settings) async {
    await courtSettingsRepository.update(settings);
    
    // キャッシュされた最新の統計データを渡す
    final games = await matchMakingService.generateMatches(
      matchTypes: settings.matchTypes,
      playerStats: _cachedStats,
    );

    final playingPlayerIds = <String>{};
    for (var game in games) {
      playingPlayerIds.add(game.teamA.player1.id);
      playingPlayerIds.add(game.teamA.player2.id);
      playingPlayerIds.add(game.teamB.player1.id);
      playingPlayerIds.add(game.teamB.player2.id);
    }

    // お休みメンバの特定のために全アクティブプレイヤーを取得
    final allActivePlayers = await matchMakingService.playerRepository.getActive();
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

  Future<CourtSettings> getCurrentSettings() async {
    return await courtSettingsRepository.get();
  }
}
