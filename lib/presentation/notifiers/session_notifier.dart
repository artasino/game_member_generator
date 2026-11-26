import 'dart:convert';

import 'package:flutter/material.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/auto_match_type_service.dart';
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
  final List<List<Session>> _undoStack = [];

  /// 保存されている全セッション（試合履歴）のリスト
  List<Session> get sessions => _sessions;
  bool get canUndo => _undoStack.isNotEmpty;

  PlayerStatsPool _cachedPool = PlayerStatsPool([]);
  List<Player> _allPlayersCache = [];
  final Map<int, PlayerStatsPool> _scopedPoolCache = {};

  /// 全プレイヤーの出場統計プールを返す
  PlayerStatsPool get playerStatsPool => _cachedPool;

  // コンフリクト影響評価のキャッシュ
  final Map<String, RequirementResult> _requirementCache = {};

  // 生成中フラグ
  bool _isGenerating = false;
  String? _declinedRotationConfiguration;
  late final Future<void> _initialRefresh;

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
    _initialRefresh = _refresh();
  }

  /// 現在のアクティブプレイヤーで、指定された試合形式が組めるかチェックする
  RequirementResult checkRequirements(List<MatchType> types,
      {bool silent = false}) {
    final counts = _requirementService.calculateRequired(types);
    final cacheKey = '${counts.male}-${counts.female}-${counts.flexible}';

    if (!silent && _requirementCache.containsKey(cacheKey)) {
      return _requirementCache[cacheKey]!;
    }

    final result =
        _requirementService.check(types, _cachedPool, silent: silent);
    if (!silent) {
      _requirementCache[cacheKey] = result;
    }
    return result;
  }

  Future<void> onPlayersUpdated() async {
    _invalidateStatsCaches();
    await _updateStats();
    notifyListeners();
  }

  Future<void> _updateStats() async {
    final allPlayers = await matchMakingService.playerRepository.getAll();
    _allPlayersCache = allPlayers;
    _cachedPool = _buildPoolForSessions(allPlayers, _sessions);
    _scopedPoolCache.clear();
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

  /// 指定セッション(含む)までの履歴のみを使って統計プールを作る
  PlayerStatsPool getPlayerStatsPoolUpToSession(int sessionIndex) {
    final cached = _scopedPoolCache[sessionIndex];
    if (cached != null) {
      return cached;
    }

    final scopedSessions = _sessions
        .where((session) => session.index <= sessionIndex)
        .toList(growable: false);
    final pool = _buildPoolForSessions(_allPlayersCache, scopedSessions);
    _scopedPoolCache[sessionIndex] = pool;
    return pool;
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
    _invalidateStatsCaches();
    await _updateStats();
    notifyListeners();
  }

  PlayerStatsPool getPlayerStatsPoolForRecalculation(int sessionIndex) =>
      playerStatsCalculator.buildPool(
        allPlayers: _allPlayersCache,
        sessions: _sessions.where((s) => s.index != sessionIndex).toList(),
      );

  Set<String>? _autoSelectedPlayers(
    CourtSettings settings,
    PlayerStatsPool pool,
  ) {
    if (!settings.isAutoRecommendMode) return null;
    final ids =
        const AutoMatchTypeService().selectPlayers(pool, settings.matchTypes);
    if (ids == null) {
      throw StateError('現在の出場条件で試合を作成できません。');
    }
    return ids;
  }

  Future<void> recalculateSession(
      int sessionIndex, CourtSettings settings) async {
    _isGenerating = true;
    notifyListeners();

    try {
      final poolForGeneration = getPlayerStatsPoolForRecalculation(sessionIndex);
      final generated = await matchMakingService.generateMatchSession(
        matchTypes: settings.matchTypes,
        playerStats: poolForGeneration,
        selectedPlayerIds: _autoSelectedPlayers(settings, poolForGeneration),
      );
      final updatedSession = Session(
        sessionIndex,
        generated.games,
        restingPlayers: generated.restingPlayers,
      );
      _pushUndoState();
      await sessionRepository.update(updatedSession);

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

  Future<int?> generateSessionWithSettings(
    CourtSettings settings, {
    Future<bool?> Function(int longestRest, int consecutiveRestCount)?
        confirmRotationException,
  }) async {
    if (_isGenerating) return null;
    _isGenerating = true;
    notifyListeners();

    try {
      await _initialRefresh;
      final pool = _cachedPool;
      final history = _sessions;
      final activePlayers = pool.active.filterAvailable().all
          .map((p) => p.player)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      final configuration = jsonEncode([
        for (final player in activePlayers)
          [player.id, player.gender.index, player.excludedPartnerId],
        settings.matchTypes.map((type) => type.index).toList()..sort(),
      ]);
      var declined = _declinedRotationConfiguration == configuration;
      final plan = await matchMakingService.planNextSession(
        preferredPlayerIds: _autoSelectedPlayers(settings, pool),
        matchTypes: settings.matchTypes,
        playerStats: pool,
        offerException: !declined && confirmRotationException != null,
      );
      if (!identical(pool, _cachedPool) || !identical(history, _sessions)) {
        return null;
      }

      var generated = plan.normal;
      final exception = plan.exception;
      final alternative = plan.alternative;
      if (exception != null &&
          alternative != null &&
          confirmRotationException != null) {
        final accepted = await confirmRotationException(
          exception.longestRest,
          exception.consecutiveRestCount,
        );
        if (accepted == null ||
            !identical(pool, _cachedPool) ||
            !identical(history, _sessions)) {
          return null;
        }
        if (accepted) {
          generated = alternative;
        } else {
          declined = true;
        }
      }

      await courtSettingsRepository.update(settings);
      final nextIndex = _sessions.length + 1;
      final newSession = Session(
        nextIndex,
        generated.games,
        restingPlayers: generated.restingPlayers,
      );

      _pushUndoState();
      await sessionRepository.add(newSession);
      _declinedRotationConfiguration = declined ? configuration : null;
      await _refresh();
      return nextIndex;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
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
      _pushUndoState();
      _sessions[index] = session;
      await sessionRepository.update(session);
      await _updateStats();
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    if (_sessions.isEmpty) return;
    _pushUndoState();
    _invalidateStatsCaches();
    await sessionRepository.clear();
    _declinedRotationConfiguration = null;
    await _refresh();
  }

  Future<void> deleteSession(int sessionIndex) async {
    if (_sessions.every((session) => session.index != sessionIndex)) return;
    _pushUndoState();
    _invalidateStatsCaches();
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

  Future<void> revertToPreviousState() async {
    if (_undoStack.isEmpty) return;
    _invalidateStatsCaches();
    final previous = _undoStack.removeLast();
    await _replaceAllSessions(previous);
    await _refresh();
  }

  void _invalidateStatsCaches() {
    _scopedPoolCache.clear();
    _requirementCache.clear();
  }

  void _pushUndoState() {
    _undoStack.add(_cloneSessions(_sessions));
    if (_undoStack.length > 30) {
      _undoStack.removeAt(0);
    }
  }

  List<Session> _cloneSessions(List<Session> sessions) {
    return sessions
        .map((s) => s.copyWith(
              games: List.of(s.games),
              restingPlayers: List.of(s.restingPlayers),
            ))
        .toList(growable: false);
  }

  Future<void> _replaceAllSessions(List<Session> nextSessions) async {
    await sessionRepository.clear();
    for (final session in nextSessions) {
      await sessionRepository.add(session);
    }
  }

  Future<CourtSettings> getCurrentSettings() async {
    return await courtSettingsRepository.get();
  }
}
