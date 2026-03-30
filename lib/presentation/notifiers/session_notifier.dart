import 'package:flutter/material.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_making_service.dart';
import '../../domain/services/player_stats_calculator.dart';

/// 人数不足などの判定結果を保持するクラス
class RequirementResult {
  final bool canGenerate;
  final String? errorMessage;
  final List<String> predictedRestPlayerNames;

  RequirementResult(
    this.canGenerate,
    this.errorMessage, {
    this.predictedRestPlayerNames = const [],
  });
}

/// 試合履歴（セッション）の状態管理と統計計算を行うNotifier
class SessionNotifier extends ChangeNotifier {
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final MatchMakingService matchMakingService;
  final PlayerStatsCalculator playerStatsCalculator;

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
    PlayerStatsCalculator? playerStatsCalculator,
  }) : playerStatsCalculator = playerStatsCalculator ?? PlayerStatsCalculator() {
    _refresh();
  }

  /// 現在のアクティブプレイヤーで、指定された試合形式が組めるかチェックする
  RequirementResult checkRequirements(
    List<MatchType> types, {
    bool performAlgorithmCheck = true,
    int? excludingSessionIndex,
  }) {
    final requiredCounts = _calculateRequiredCounts(types);
    final activeAvailable =
        _getActiveAvailablePool(excludingSessionIndex: excludingSessionIndex);
    final activeCounts = _GenderCounts(
      male: activeAvailable.males.length,
      female: activeAvailable.females.length,
    );
    final initialShortage = _buildShortageResult(
      requiredCounts: requiredCounts,
      availableCounts: activeCounts,
      reasonPrefix: '',
    );
    if (initialShortage != null) {
      return initialShortage;
    }

    if (performAlgorithmCheck &&
        !_canGenerateWithCurrentAlgorithm(types, activeAvailable)) {
      return RequirementResult(
        false,
        'この組み合わせでは試合を生成できません。コートタイプを変更してください。',
      );
    }

    return RequirementResult(true, null);
  }

  RequirementResult? _buildShortageResult({
    required _RequiredPlayerCounts requiredCounts,
    required _GenderCounts availableCounts,
    required String reasonPrefix,
  }) {
    final missingMale = requiredCounts.male - availableCounts.male;
    final missingFemale = requiredCounts.female - availableCounts.female;

    if (missingMale <= 0 && missingFemale <= 0) {
      return null;
    }

    final message = _buildShortageMessage(
      missingMale: missingMale,
      missingFemale: missingFemale,
      reasonPrefix: reasonPrefix,
    );
    return RequirementResult(
      false,
      message,
    );
  }

  String _buildShortageMessage({
    required int missingMale,
    required int missingFemale,
    required String reasonPrefix,
  }) {
    final shortagePrefix = reasonPrefix.isEmpty ? '' : '$reasonPrefix';

    if (missingMale > 0 && missingFemale > 0) {
      final suffix = reasonPrefix.isEmpty ? '足りません' : '不足します';
      return '${shortagePrefix}男女ともに人数が$suffix (男:${missingMale}人, 女:${missingFemale}人不足)';
    }
    if (missingMale > 0) {
      return '${shortagePrefix}男性が足りません (${missingMale}人不足)';
    }
    return '${shortagePrefix}女性が足りません (${missingFemale}人不足)';
  }

  PlayerStatsPool _getActiveAvailablePool({int? excludingSessionIndex}) {
    final sourcePool = excludingSessionIndex == null
        ? _cachedPool
        : _buildPoolForSessions(
            _allPlayersCache,
            _sessions
                .where((session) => session.index != excludingSessionIndex)
                .toList(growable: false),
          );
    return PlayerStatsPool(
      sourcePool.all
          .where((player) => player.player.isActive && !player.player.isMustRest)
          .toList(growable: false),
    );
  }

  bool _canGenerateWithCurrentAlgorithm(
    List<MatchType> types,
    PlayerStatsPool activeAvailablePool,
  ) {
    try {
      final generated = matchMakingService.algorithm.generateMatches(
        matchTypes: types,
        playerPool: activeAvailablePool,
      );
      return generated.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> onPlayersUpdated() async {
    await _updateStats();
    notifyListeners();
  }

  Future<void> _updateStats() async {
    final allPlayers = await matchMakingService.playerRepository.getAll();
    _allPlayersCache = allPlayers;
    _cachedPool = _buildPoolForSessions(allPlayers, _sessions);
  }

  /// 指定セッション(含む)までの履歴のみを使って統計プールを作る
  ///
  /// MatchHistory で過去セッションを閲覧したときに、
  /// その時点までのペア回数/休み連続を表示するために使用する。
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

  Future<void> recalculateSession(int sessionIndex, CourtSettings settings) async {
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
      final index = _sessions.indexWhere((session) => session.index == sessionIndex);
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
    final id1 = team.player1.id;
    final id2 = team.player2.id;
    for (final session in _sessions) {
      if (upToIndex != null && session.index > upToIndex) {
        break;
      }
      for (final game in session.games) {
        if (_isMatch(game.teamA, id1, id2) || _isMatch(game.teamB, id1, id2)) {
          count++;
        }
      }
    }
    return count;
  }

  bool _isMatch(Team team, String id1, String id2) {
    final teamId1 = team.player1.id;
    final teamId2 = team.player2.id;
    return (teamId1 == id1 && teamId2 == id2) ||
        (teamId1 == id2 && teamId2 == id1);
  }

  Future<void> swapPlayers(Session session, Player p1, Player p2) async {
    final newGames = session.games.map((game) {
      final newTeamA = _swapInTeam(game.teamA, p1, p2);
      final newTeamB = _swapInTeam(game.teamB, p1, p2);
      return game.copyWith(teamA: newTeamA, teamB: newTeamB);
    }).toList(growable: false);

    final newResting = session.restingPlayers.map((player) {
      if (player.id == p1.id) {
        return p2;
      }
      if (player.id == p2.id) {
        return p1;
      }
      return player;
    }).toList(growable: false);

    await updateSession(
      session.copyWith(games: newGames, restingPlayers: newResting),
    );
  }

  Team _swapInTeam(Team team, Player p1, Player p2) {
    var newP1 = team.player1;
    var newP2 = team.player2;
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

  _RequiredPlayerCounts _calculateRequiredCounts(List<MatchType> types) {
    var requiredMale = 0;
    var requiredFemale = 0;

    for (final type in types) {
      switch (type) {
        case MatchType.menDoubles:
          requiredMale += 4;
          break;
        case MatchType.womenDoubles:
          requiredFemale += 4;
          break;
        case MatchType.mixedDoubles:
          requiredMale += 2;
          requiredFemale += 2;
          break;
      }
    }

    return _RequiredPlayerCounts(male: requiredMale, female: requiredFemale);
  }
}

class _RequiredPlayerCounts {
  final int male;
  final int female;

  const _RequiredPlayerCounts({
    required this.male,
    required this.female,
  });
}

class _GenderCounts {
  final int male;
  final int female;

  const _GenderCounts({
    required this.male,
    required this.female,
  });
}
