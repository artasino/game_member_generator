import 'dart:math';

import 'package:game_member_generator/domain/algorithm/penalty_weights.dart';
import 'package:game_member_generator/domain/algorithm/session_score.dart';

import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/player_with_stats.dart';
import '../entities/team.dart';

/// evaluate which game member is better by given players
class GameEvaluator {
  /// 全体のセッションスコアを計算する
  SessionScore evaluateSession({
    required List<MatchType> matchTypes,
    required List<PlayerWithStats> selectedMales,
    required List<PlayerWithStats> benchMales,
    required List<PlayerWithStats> selectedFemales,
    required List<PlayerWithStats> benchFemales,
    List<Set<String>> previousMaleSelections = const [],
    List<Set<String>> previousFemaleSelections = const [],
  }) {
    double score = 0;

    // 1. 同一メンバー選出ペナルティ
    score += _calculateIdenticalSelectionPenalty(
        selectedMales, previousMaleSelections);
    score += _calculateIdenticalSelectionPenalty(
        selectedFemales, previousFemaleSelections);

    // 2. 休み関連のペナルティ/ゲイン
    score += calculateRestTogetherPenalty(benchMales);
    score += calculateRestTogetherPenalty(benchFemales);
    score += calculateSessionsFromLastRestPenalty(
        [...selectedMales, ...selectedFemales]);

    // 3. 試合構成の最適化とペナルティ
    final bestGames = <Game>[];
    int maleOffset = 0;
    int femaleOffset = 0;

    for (var type in matchTypes) {
      final GameScore gameScore;
      if (type == MatchType.maleDoubles) {
        final players = selectedMales.skip(maleOffset).take(4).toList();
        gameScore = getBestGameForFour(type, players);
        maleOffset += 4;
      } else if (type == MatchType.femaleDoubles) {
        final players = selectedFemales.skip(femaleOffset).take(4).toList();
        gameScore = getBestGameForFour(type, players);
        femaleOffset += 4;
      } else {
        final ms = selectedMales.skip(maleOffset).take(2).toList();
        final fs = selectedFemales.skip(femaleOffset).take(2).toList();
        gameScore = getBestMixedGame(type, ms, fs);
        maleOffset += 2;
        femaleOffset += 2;
      }
      score += gameScore.score;
      bestGames.add(gameScore.game);
    }

    return SessionScore(score, bestGames);
  }

  double _calculateIdenticalSelectionPenalty(
    List<PlayerWithStats> selected,
    List<Set<String>> previousSelections,
  ) {
    if (previousSelections.isEmpty) return 0;
    final currentIds = selected.map((p) => p.player.id).toSet();
    for (final prev in previousSelections) {
      if (prev.length == currentIds.length && prev.every(currentIds.contains)) {
        return PenaltyWeights.identicalSelectionPenalty;
      }
    }
    return 0;
  }

  /// 試合内のチーム分けペナルティ計算
  double _calculateGamePenalty(MatchType type, PlayerWithStats p1,
      PlayerWithStats p2, PlayerWithStats p3, PlayerWithStats p4) {
    double penalty = 0;

    for (var ps in [p1, p2, p3, p4]) {
      penalty += _calculateTypeImbalancePenalty(ps, type) *
          PenaltyWeights.typeImbalance;
      penalty += _calculateSameTypeAsPrevious(ps, type);
    }
    penalty += _calculatePairCountPenalty(p1, p2, p3, p4);
    penalty += _calculateOpponentCountPenalty(p1, p2, p3, p4);
    return penalty;
  }

  /// 4人の中で最適なチーム分け（3パターン）を決定
  GameScore getBestGameForFour(MatchType type, List<PlayerWithStats> p) {
    if (p.length < 4) {
      return GameScore(
          1000000,
          Game(type, Team(p[0].player, p[0].player),
              Team(p[0].player, p[0].player))); // Safety
    }
    final patterns = [
      [p[0], p[1], p[2], p[3]],
      [p[0], p[2], p[1], p[3]],
      [p[0], p[3], p[1], p[2]],
    ];
    return _findBestPattern(type, patterns);
  }

  /// 混合ダブルスで最適なチーム分け（2パターン）を決定
  GameScore getBestMixedGame(
      MatchType type, List<PlayerWithStats> ms, List<PlayerWithStats> fs) {
    if (ms.length < 2 || fs.length < 2) {
      return GameScore(
          1000000,
          Game(type, Team(ms[0].player, fs[0].player),
              Team(ms[0].player, fs[0].player))); // Safety
    }
    final patterns = [
      [ms[0], fs[0], ms[1], fs[1]],
      [ms[0], fs[1], ms[1], fs[0]],
    ];
    return _findBestPattern(type, patterns);
  }

  GameScore _findBestPattern(
      MatchType type, List<List<PlayerWithStats>> patterns) {
    double minScore = double.infinity;
    late Game bestGame;

    for (final pattern in patterns) {
      double score = _calculateGamePenalty(
          type, pattern[0], pattern[1], pattern[2], pattern[3]);
      if (score < minScore) {
        minScore = score;
        bestGame = Game(type, Team(pattern[0].player, pattern[1].player),
            Team(pattern[2].player, pattern[3].player));
      }
    }
    return GameScore(minScore, bestGame);
  }

  // score is minus (gain for resting last time)
  double calculateSessionsFromLastRestPenalty(
      List<PlayerWithStats> availablePlayers) {
    var score = 0.0;
    for (var ps in availablePlayers) {
      if (ps.stats.restedLastTime) {
        score -= PenaltyWeights.lastTimeRestedGain;
      }
    }
    return score;
  }

  /// 一緒に休みになった回数に基づくペナルティ（同性内のみ）
  double calculateRestTogetherPenalty(List<PlayerWithStats> restingPlayers) {
    double penalty = 0.0;
    int maxCount = 0;
    for (int i = 0; i < restingPlayers.length; i++) {
      for (int j = i + 1; j < restingPlayers.length; j++) {
        final p1 = restingPlayers[i];
        final p2 = restingPlayers[j];
        if (p1.player.gender == p2.player.gender) {
          final count = p1.stats.restTogetherCounts[p2.player.id] ?? 0;
          penalty += count * PenaltyWeights.restTogether;
          maxCount = max(maxCount, count);
        }
      }
    }
    penalty += maxCount * PenaltyWeights.restTogetherMaxBonus;
    return penalty;
  }

  double _calculateTypeImbalancePenalty(PlayerWithStats ps, MatchType type) {
    final counts = ps.stats.typeCounts;
    final targetTypeCount = counts[type] ?? 0;
    final totalMatches = counts.values.fold(0, (sum, count) => sum + count) + 1;

    if (!type.isAppropriateFor(ps.player.gender)) return 0;
    return (targetTypeCount + 1) / totalMatches;
  }

  double _calculateSameTypeAsPrevious(
      PlayerWithStats player, MatchType matchType) {
    if (player.stats.lastMatchType == matchType) {
      return PenaltyWeights.sameTypeAsPrevious;
    }
    return 0.0;
  }

  double _calculatePairCountPenalty(PlayerWithStats p1, PlayerWithStats p2,
      PlayerWithStats p3, PlayerWithStats p4) {
    var penalty = 0.0;
    penalty +=
        (p1.stats.partnerCounts[p2.player.id] ?? 0) * PenaltyWeights.pairRepeat;
    penalty +=
        (p3.stats.partnerCounts[p4.player.id] ?? 0) * PenaltyWeights.pairRepeat;
    return penalty;
  }

  double _calculateOpponentCountPenalty(PlayerWithStats p1, PlayerWithStats p2,
      PlayerWithStats p3, PlayerWithStats p4) {
    var penalty = 0.0;
    final opponentsA = [p3, p4];

    for (var p in [p1, p2]) {
      for (var opp in opponentsA) {
        penalty += (p.stats.opponentCounts[opp.player.id] ?? 0) *
            PenaltyWeights.opponentRepeat;
      }
    }
    return penalty;
  }
}
