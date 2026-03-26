import 'package:game_member_generator/domain/algorithm/session_score.dart';

import '../entities/game.dart';
import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player_with_stats.dart';
import '../entities/team.dart';

/// evaluate which game member is better by given players
class GameEvaluator {
  /// 試合のペナルティ計算
  double _calculateGamePenalty(MatchType type, PlayerWithStats p1,
      PlayerWithStats p2, PlayerWithStats p3, PlayerWithStats p4) {
    double penalty = 0;

    // 優先度2位: 種目バランス
    for (var ps in [p1, p2, p3, p4]) {
      penalty += _calculateTypeImbalancePenalty(ps, type) * 100.0;
      penalty += _calculateSameTypeAsPrevious(ps, type);
    }
    penalty += _calculatePairCountPenalty(p1, p2, p3, p4);
    penalty += _calculateOpponentCountPenalty(p1, p2, p3, p4);
    return penalty;
  }

  /// 4人の中で最適なチーム分け（3パターン）を決定
  GameScore getBestGameForFour(MatchType type, List<PlayerWithStats> p) {
    final patterns = [
      [p[0], p[1], p[2], p[3]],
      [p[0], p[2], p[1], p[3]],
      [p[0], p[3], p[1], p[2]],
    ];

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

  /// 混合ダブルスで最適なチーム分け（2パターン）を決定
  GameScore getBestMixedGame(
      MatchType type, List<PlayerWithStats> ms, List<PlayerWithStats> fs) {
    final patterns = [
      [ms[0], fs[0], ms[1], fs[1]],
      [ms[0], fs[1], ms[1], fs[0]],
    ];
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

  // score is minus
  double calculateSessionsFromLastRestPenalty(
      List<PlayerWithStats> availablePlayers) {
    final gain = 200.0;
    var score = 0.0;
    for (var ps in availablePlayers) {
      if (ps.stats.restedLastTime) {
        score -= gain * 2;
      } else if (ps.stats.sessionsSinceLastRest == 1) {
        score -= gain;
      }
    }
    return score;
  }

  double _calculateTypeImbalancePenalty(PlayerWithStats ps, MatchType type) {
    final counts = ps.stats.typeCounts;
    if (ps.player.gender == Gender.male) {
      final md = counts[MatchType.menDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      final total = md + mx + 1;
      if (total == 0) {
        return 0;
      }
      if (type == MatchType.menDoubles) {
        return (md + 1) / total;
      }
      if (type == MatchType.mixedDoubles) {
        return (mx + 1) / total;
      }
    } else {
      final wd = counts[MatchType.womenDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      final total = wd + mx + 1;
      if (total == 0) {
        return 0;
      }
      if (type == MatchType.womenDoubles) {
        return (wd + 1) / total;
      }
      if (type == MatchType.mixedDoubles) {
        return (mx + 1) / total;
      }
    }
    return 0;
  }

  double _calculateSameTypeAsPrevious(
      PlayerWithStats player, MatchType matchType) {
    if (player.stats.lastMatchType == null) {
      return 0.0;
    }
    if (player.stats.lastMatchType == matchType) {
      return 15.0;
    }
    return 0.0;
  }

  double _calculatePairCountPenalty(PlayerWithStats p1, PlayerWithStats p2,
      PlayerWithStats p3, PlayerWithStats p4) {
    // 優先度3位: ペア重複
    var penalty = 0.0;
    final normalizedPairCount = 10.0;
    penalty += (p1.stats.partnerCounts[p2.player.id] ?? 0) /
        normalizedPairCount *
        50.0;
    penalty += (p3.stats.partnerCounts[p4.player.id] ?? 0) /
        normalizedPairCount *
        50.0;
    return penalty;
  }

  double _calculateOpponentCountPenalty(PlayerWithStats p1, PlayerWithStats p2,
      PlayerWithStats p3, PlayerWithStats p4) {
    // 優先度4位: 敵重複 (Weight: 10.0)
    final normalizedOpponentCount = 10.0;
    var penalty = 0.0;
    for (var a in [p1, p2]) {
      for (var b in [p3, p4]) {
        penalty += (a.stats.opponentCounts[b.player.id] ?? 0) /
            normalizedOpponentCount *
            10.0;
      }
    }
    return penalty;
  }
}
