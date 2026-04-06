import 'package:flutter/material.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_making_service.dart';
import '../../domain/services/match_requirement_service.dart';
import '../../domain/services/player_stats_calculator.dart';

export '../../domain/services/match_requirement_service.dart'
    show RequirementResult;

/// 試合履歴（セッション）の状態管理と統計計算を行うNotifier
class SessionNotifier extends ChangeNotifier {
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final MatchMakingService matchMakingService;
  final PlayerStatsCalculator playerStatsCalculator;
  final MatchRequirementService _requirementService;

  List<Session> _sessions = [];

  /// 保存されている全セッション（試合履歴）のリスト
  List<Session> get sessions => _sessions;

  PlayerStatsPool _cachedPool = PlayerStatsPool([]);
  List<Player> _allPlayersCache = [];

  /// 全プレイヤーの出場統計プールを返す
  PlayerStatsPool get playerStatsPool => _cachedPool;

  // コンフリクト影響評価のキャッシュ
  final Map<String, RequirementResult> _requirementCache = {};

  // 生成中フラグ
  bool _isGenerating = false;

  bool get isGenerating => _isGenerating;

  SessionNotifier({
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.matchMakingService,
    PlayerStatsCalculator? playerStatsCalculator,
    MatchRequirementService? requirementService,
  })  : playerStatsCalculator =
            playerStatsCalculator ?? PlayerStatsCalculator(),
        _requirementService =
            requirementService ?? const MatchRequirementService() {
    _refresh();
  }

  /// 現在のアクティブプレイヤーで、指定された試合形式が組めるかチェックする
  RequirementResult checkRequirements(List<MatchType> types) {
    final counts = _requirementService.calculateRequired(types);
    final cacheKey = '${counts.male}-${counts.female}';

    if (_requirementCache.containsKey(cacheKey)) {
      return _requirementCache[cacheKey]!;
    }

    final result = _requirementService.check(types, _cachedPool);
    _requirementCache[cacheKey] = result;
    return result;
  }

  Future<void> onPlayersUpdated() async {
    await _updateStats();
    notifyListeners();
  }

  Future<void> _updateStats() async {
    final allPlayers = await matchMakingService.playerRepository.getAll();
    _allPlayersCache = allPlayers;
    _cachedPool = _buildPoolForSessions(allPlayers, _sessions);
    _requirementCache.clear();
  }

  /// 各形式（MatchType）の累計試合数を取得する
  Map<MatchType, int> getMatchTypeTotalCounts() {
    final Map<MatchType, int> counts = {};
    for (final session in _sessions) {
      for (final game in session.games) {
        counts[game.type] = (counts[game.type] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// 男女それぞれの延べ出場回数を取得する
  Map<Gender, int> getGenderParticipationTotalCounts() {
    int maleCount = 0;
    int femaleCount = 0;
    for (final session in _sessions) {
      for (final game in session.games) {
        for (final p in [
          game.teamA.player1,
          game.teamA.player2,
          game.teamB.player1,
          game.teamB.player2
        ]) {
          if (p.gender == Gender.male) maleCount++;
          if (p.gender == Gender.female) femaleCount++;
        }
      }
    }
    return {Gender.male: maleCount, Gender.female: femaleCount};
  }

  /// 指定セッション(含む)までの履歴のみを使って統計プールを作る
  PlayerStatsPool getPlayerStatsPoolUpToSession(int sessionIndex) {
    final scopedSessions = _sessions
        .where((session) => session.index <= sessionIndex)
        .toList(growable: false);
    return _buildPoolForSessions(_allPlayersCache, scopedSessions);
  }

  PlayerStatsPool _buildPoolForSessions(
    List<Player> allPlayers,
    List<Session> sessionsForStats,
  ) {
    return playerStatsCalculator.buildPool(
      allPlayers: allPlayers,
      sessions: sessionsForStats,
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
    _sessions.removeWhere((session) => session.index == sessionIndex);
    await _updateStats();

    try {
      final generated = await _generateSessionData(settings);
      final updatedSession = Session(
        sessionIndex,
        generated.games,
        restingPlayers: generated.restingPlayers,
      );
      await sessionRepository.update(updatedSession);

      _sessions = originalSessions;
      final index =
          _sessions.indexWhere((session) => session.index == sessionIndex);
      if (index != -1) {
        _sessions[index] = updatedSession;
      }
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
      final generated = await _generateSessionData(settings);
      final nextIndex = _sessions.length + 1;
      final newSession = Session(
        nextIndex,
        generated.games,
        restingPlayers: generated.restingPlayers,
      );

      await sessionRepository.add(newSession);
      await _refresh();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<MatchGenerationResult> _generateSessionData(CourtSettings settings) {
    return matchMakingService.generateMatchSession(
      matchTypes: settings.matchTypes,
      playerStats: _cachedPool,
    );
  }

  int getPairCount(Team team, {int? upToIndex}) {
    var count = 0;
    for (final session in _sessions) {
      if (upToIndex != null && session.index > upToIndex) break;
      for (final game in session.games) {
        if (_isMatch(game.teamA, team) || _isMatch(game.teamB, team)) {
          count++;
        }
      }
    }
    return count;
  }

  bool _isMatch(Team t1, Team t2) {
    return (t1.player1.id == t2.player1.id && t1.player2.id == t2.player2.id) ||
        (t1.player1.id == t2.player2.id && t1.player2.id == t2.player1.id);
  }

  Future<void> swapPlayers(Session session, Player p1, Player p2) async {
    final newGames = session.games.map((game) {
      return game.copyWith(
        teamA: game.teamA.swapPlayers(p1, p2),
        teamB: game.teamB.swapPlayers(p1, p2),
      );
    }).toList(growable: false);

    final newResting = session.restingPlayers.map((player) {
      if (player.id == p1.id) return p2;
      if (player.id == p2.id) return p1;
      return player;
    }).toList(growable: false);

    await updateSession(
      session.copyWith(games: newGames, restingPlayers: newResting),
    );
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

  Future<void> deleteSession(int sessionIndex) async {
    final remaining = _sessions
        .where((session) => session.index != sessionIndex)
        .toList(growable: false);
    final reindexed = remaining
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(index: entry.key + 1))
        .toList(growable: false);

    await sessionRepository.clear();
    for (final session in reindexed) {
      await sessionRepository.add(session);
    }

    await _refresh();
  }

  Future<CourtSettings> getCurrentSettings() async {
    return await courtSettingsRepository.get();
  }
}
