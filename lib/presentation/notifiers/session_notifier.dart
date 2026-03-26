import 'package:flutter/material.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_requirement_checker.dart';
import '../../domain/services/match_making_service.dart';
import '../../domain/services/player_stats_pool_builder.dart';

/// 試合履歴（セッション）の状態管理と統計計算を行うNotifier
class SessionNotifier extends ChangeNotifier {
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final MatchMakingService matchMakingService;
  final MatchRequirementChecker requirementChecker;
  final PlayerStatsPoolBuilder statsPoolBuilder;

  List<Session> _sessions = [];

  /// 保存されている全セッション（試合履歴）のリスト
  List<Session> get sessions => _sessions;

  PlayerStatsPool _cachedPool = PlayerStatsPool([]);
  List<Player> _allPlayersCache = [];

  /// 全プレイヤーの出場統計プールを返す
  PlayerStatsPool get playerStatsPool => _cachedPool;

  // 生成中フラグ
  bool _isGenerating = false;

  bool get isGenerating => _isGenerating;

  SessionNotifier({
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.matchMakingService,
    MatchRequirementChecker? requirementChecker,
    PlayerStatsPoolBuilder? statsPoolBuilder,
  })  : requirementChecker =
            requirementChecker ?? const MatchRequirementChecker(),
        statsPoolBuilder = statsPoolBuilder ?? const PlayerStatsPoolBuilder() {
    _refresh();
  }

  /// 現在のアクティブプレイヤーで、指定された試合形式が組めるかチェックする
  RequirementResult checkRequirements(List<MatchType> types) {
    return requirementChecker.check(
      matchTypes: types,
      playerStatsPool: _cachedPool,
    );
  }

  Future<void> onPlayersUpdated() async {
    await _updateStats();
    notifyListeners();
  }

  Future<void> _updateStats() async {
    final allPlayers = await matchMakingService.playerRepository.getAll();
    _allPlayersCache = allPlayers;
    _cachedPool = statsPoolBuilder.build(
      allPlayers: allPlayers,
      sessions: _sessions,
    );
  }

  /// 指定セッション(含む)までの履歴のみを使って統計プールを作る
  ///
  /// MatchHistory で過去セッションを閲覧したときに、
  /// その時点までのペア回数/休み連続を表示するために使用する。
  PlayerStatsPool getPlayerStatsPoolUpToSession(int sessionIndex) {
    final scopedSessions = _sessions
        .where((session) => session.index <= sessionIndex)
        .toList(growable: false);
    return statsPoolBuilder.build(
      allPlayers: _allPlayersCache,
      sessions: scopedSessions,
    );
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

  Future<void> swapPlayers(Session session, Player p1, Player p2) async {
    final newGames = session.games.map((game) {
      final newTeamA = _swapInTeam(game.teamA, p1, p2);
      final newTeamB = _swapInTeam(game.teamB, p1, p2);
      return game.copyWith(teamA: newTeamA, teamB: newTeamB);
    }).toList();

    final newResting = session.restingPlayers.map((p) {
      if (p.id == p1.id) return p2;
      if (p.id == p2.id) return p1;
      return p;
    }).toList();

    await updateSession(
      session.copyWith(games: newGames, restingPlayers: newResting),
    );
  }

  Team _swapInTeam(Team team, Player p1, Player p2) {
    Player newP1 = team.player1;
    Player newP2 = team.player2;
    if (team.player1.id == p1.id) {
      newP1 = p2;
    } else if (team.player1.id == p2.id) {
      newP1 = p1;
    }
    if (team.player2.id == p1.id) {
      newP2 = p2;
    } else if (team.player2.id == p2.id) {
      newP2 = p1;
    }
    return team.copyWith(player1: newP1, player2: newP2);
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
