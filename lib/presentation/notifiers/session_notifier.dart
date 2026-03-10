import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/player_with_stats.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_making_service.dart';

/// 人数不足などの判定結果を保持するクラス
class RequirementResult {
  final bool canGenerate;
  final String? errorMessage;

  RequirementResult(this.canGenerate, this.errorMessage);
}

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

  // 生成中フラグ
  bool _isGenerating = false;

  bool get isGenerating => _isGenerating;

  SessionNotifier({
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.matchMakingService,
  }) {
    _refresh();
  }

  /// 現在のアクティブプレイヤーで、指定された試合形式が組めるかチェックする
  RequirementResult checkRequirements(List<MatchType> types) {
    int reqMale = 0;
    int reqFemale = 0;
    for (final type in types) {
      if (type == MatchType.menDoubles) {
        reqMale += 4;
      } else if (type == MatchType.womenDoubles) {
        reqFemale += 4;
      } else if (type == MatchType.mixedDoubles) {
        reqMale += 2;
        reqFemale += 2;
      }
    }

    final activeMales = _cachedPool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.male)
        .length;
    final activeFemales = _cachedPool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.female)
        .length;

    if (activeMales < reqMale && activeFemales < reqFemale) {
      return RequirementResult(false,
          '男女ともに人数が足りません (男:${reqMale - activeMales}人, 女:${reqFemale - activeFemales}人不足)');
    } else if (activeMales < reqMale) {
      return RequirementResult(false, '男性が足りません (${reqMale - activeMales}人不足)');
    } else if (activeFemales < reqFemale) {
      return RequirementResult(
          false, '女性が足りません (${reqFemale - activeFemales}人不足)');
    }

    return RequirementResult(true, null);
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
          // 削除済みプレイヤーの場合はスキップ
          if (!typeBreakdowns.containsKey(id)) return;

          totals[id] = (totals[id] ?? 0) + 1;
          typeBreakdowns[id]![game.type] =
              (typeBreakdowns[id]![game.type] ?? 0) + 1;
          partnerBreakdowns[id]![partner.id] =
              (partnerBreakdowns[id]![partner.id] ?? 0) + 1;
          for (final opp in opponents) {
            opponentBreakdowns[id]![opp.id] =
                (opponentBreakdowns[id]![opp.id] ?? 0) + 1;
          }
        }

        record(teamA[0], teamA[1], teamB);
        record(teamA[1], teamA[0], teamB);
        record(teamB[0], teamB[1], teamA);
        record(teamB[1], teamB[0], teamA);
      }
      for (final rp in session.restingPlayers) {
        if (rests.containsKey(rp.id)) {
          rests[rp.id] = (rests[rp.id] ?? 0) + 1;
        }
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
          restedLastTime: _sessions.isNotEmpty &&
              _sessions.last.restingPlayers.any((rp) => rp.id == p.id),
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

  Future<void> recalculateSession(
      int sessionIndex, CourtSettings settings) async {
    _isGenerating = true;
    notifyListeners();

    final originalSessions = List<Session>.from(_sessions);
    _sessions.removeWhere((s) => s.index == sessionIndex);
    await _updateStats();

    try {
      final games = await matchMakingService.generateMatches(
        matchTypes: settings.matchTypes,
        playerStats: _cachedPool,
      );

      final playingPlayerIds = games
          .expand((g) => [
                g.teamA.player1.id,
                g.teamA.player2.id,
                g.teamB.player1.id,
                g.teamB.player2.id
              ])
          .toSet();
      final allActivePlayers =
          await matchMakingService.playerRepository.getActive();
      final restingPlayers = allActivePlayers
          .where((p) => !playingPlayerIds.contains(p.id))
          .toList();

      final updatedSession =
          Session(sessionIndex, games, restingPlayers: restingPlayers);
      await sessionRepository.update(updatedSession);

      _sessions = originalSessions;
      final idx = _sessions.indexWhere((s) => s.index == sessionIndex);
      if (idx != -1) _sessions[idx] = updatedSession;
    } finally {
      await _updateStats();
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> generateSessionWithSettings(CourtSettings settings) async {
    _isGenerating = true;
    notifyListeners();

    await courtSettingsRepository.update(settings);

    try {
      final games = await matchMakingService.generateMatches(
        matchTypes: settings.matchTypes,
        playerStats: _cachedPool,
      );

      final playingPlayerIds = games
          .expand((g) => [
                g.teamA.player1.id,
                g.teamA.player2.id,
                g.teamB.player1.id,
                g.teamB.player2.id
              ])
          .toSet();
      final allActivePlayers =
          await matchMakingService.playerRepository.getActive();
      final restingPlayers = allActivePlayers
          .where((p) => !playingPlayerIds.contains(p.id))
          .toList();

      final nextIndex = _sessions.length + 1;
      final newSession =
          Session(nextIndex, games, restingPlayers: restingPlayers);

      await sessionRepository.add(newSession);
      await _refresh();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

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

  Future<void> updateSession(Session session) async {
    final index = _sessions.indexWhere((s) => s.index == session.index);
    if (index != -1) {
      _sessions[index] = session;
      await sessionRepository.update(session);
      await _updateStats();
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    await sessionRepository.clear();
    await _refresh();
  }

  Future<CourtSettings> getCurrentSettings() async {
    return await courtSettingsRepository.get();
  }
}
