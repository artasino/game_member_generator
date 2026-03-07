import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/player_with_stats.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_making_service.dart';

/// 試合履歴（セッション）の状態管理と統計計算を行うNotifier
class SessionNotifier extends ChangeNotifier {
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final MatchMakingService matchMakingService;

  List<Session> _sessions = [];
  /// 保存されている全セッション（試合履歴）のリスト
  List<Session> get sessions => _sessions;

  PlayerStatsPool _cachedPool = PlayerStatsPool([]);
  /// 全プレイヤーの出場統計プールを返す
  PlayerStatsPool get playerStatsPool => _cachedPool;

  SessionNotifier({
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.matchMakingService,
  }) {
    _refresh();
  }

  Future<void> onPlayersUpdated() async {
    await _updateStats();
    notifyListeners();
  }

  Future<void> _updateStats() async {
    final Map<String, int> totals = {};
    final Map<String, int> rests = {}; 
    final Map<String, Map<MatchType, int>> typeBreakdowns = {};
    final Map<String, Map<String, int>> partnerBreakdowns = {};
    final Map<String, Map<String, int>> opponentBreakdowns = {};

    final allPlayers = await matchMakingService.playerRepository.getAll();
    for (final player in allPlayers) {
      final id = player.id;
      totals[id] = 0;
      rests[id] = 0;
      typeBreakdowns[id] = {};
      partnerBreakdowns[id] = {};
      opponentBreakdowns[id] = {};
    }

    for (final session in _sessions) {
      for (final game in session.games) {
        final teamA = [game.teamA.player1, game.teamA.player2];
        final teamB = [game.teamB.player1, game.teamB.player2];

        void record(Player p, Player partner, List<Player> opponents) {
          final id = p.id;
          totals[id] = (totals[id] ?? 0) + 1;
          typeBreakdowns[id]![game.type] = (typeBreakdowns[id]![game.type] ?? 0) + 1;
          partnerBreakdowns[id]![partner.id] = (partnerBreakdowns[id]![partner.id] ?? 0) + 1;
          for (final opp in opponents) {
            opponentBreakdowns[id]![opp.id] = (opponentBreakdowns[id]![opp.id] ?? 0) + 1;
          }
        }

        record(teamA[0], teamA[1], teamB);
        record(teamA[1], teamA[0], teamB);
        record(teamB[0], teamB[1], teamA);
        record(teamB[1], teamB[0], teamA);
      }
      for (final rp in session.restingPlayers) {
        rests[rp.id] = (rests[rp.id] ?? 0) + 1;
      }
    }

    final Map<String, int> sessionsSinceLastRest = {};
    for (final player in allPlayers) {
      int count = 0;
      for (final session in _sessions.reversed) {
        final rested = session.restingPlayers.any((p) => p.id == player.id);
        if (rested) break;
        count++;
      }
      sessionsSinceLastRest[player.id] = count;
    }

    final playerWithStatsList = allPlayers.map((p) {
      return PlayerWithStats(
        player: p,
        stats: PlayerStats(
          totalMatches: totals[p.id] ?? 0,
          totalRests: rests[p.id] ?? 0,
          typeCounts: typeBreakdowns[p.id] ?? {},
          partnerCounts: partnerBreakdowns[p.id] ?? {},
          opponentCounts: opponentBreakdowns[p.id] ?? {},
          restedLastTime: _sessions.isNotEmpty && _sessions.last.restingPlayers.any((rp) => rp.id == p.id),
          sessionsSinceLastRest: sessionsSinceLastRest[p.id] ?? 0,
        ),
      );
    }).toList();

    _cachedPool = PlayerStatsPool(playerWithStatsList);
  }

  Future<void> _refresh() async {
    final fetchedSessions = await sessionRepository.getAll();
    _sessions = List.from(fetchedSessions);
    await _updateStats();
    notifyListeners();
  }

  /// 指定されたインデックスのセッションを、新しい設定で再生成する
  Future<void> recalculateSession(int sessionIndex, CourtSettings settings) async {
    // 1. そのセッションを除いた状態での統計を一時的に計算する
    final originalSessions = List<Session>.from(_sessions);
    _sessions.removeWhere((s) => s.index == sessionIndex);
    await _updateStats();

    try {
      // 2. 新しい組み合わせを生成
      final games = await matchMakingService.generateMatches(
        matchTypes: settings.matchTypes,
        playerStats: _cachedPool,
      );

      final playingPlayerIds = games.expand((g) => [g.teamA.player1.id, g.teamA.player2.id, g.teamB.player1.id, g.teamB.player2.id]).toSet();
      final allActivePlayers = await matchMakingService.playerRepository.getActive();
      final restingPlayers = allActivePlayers.where((p) => !playingPlayerIds.contains(p.id)).toList();

      final updatedSession = Session(sessionIndex, games, restingPlayers: restingPlayers);

      // 3. セッションを上書き保存
      await sessionRepository.update(updatedSession);
      
      // 4. 全体を復元してリフレッシュ
      _sessions = originalSessions;
      final idx = _sessions.indexWhere((s) => s.index == sessionIndex);
      if (idx != -1) _sessions[idx] = updatedSession;
    } finally {
      // エラーが起きても元の状態に戻す
      await _updateStats();
      notifyListeners();
    }
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
    final games = await matchMakingService.generateMatches(
      matchTypes: settings.matchTypes,
      playerStats: _cachedPool,
    );

    final playingPlayerIds = games.expand((g) => [g.teamA.player1.id, g.teamA.player2.id, g.teamB.player1.id, g.teamB.player2.id]).toSet();
    final allActivePlayers = await matchMakingService.playerRepository.getActive();
    final restingPlayers = allActivePlayers.where((p) => !playingPlayerIds.contains(p.id)).toList();

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
