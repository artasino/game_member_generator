import 'package:game_member_generator/domain/algorithm/session_score.dart';

import '../entities/game.dart';
import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player_with_stats.dart';
import '../entities/team.dart';

/// evaluate which game member is better by given players
class GameEvaluator {
  double _calculateTypeImbalancePenalty(PlayerWithStats ps, MatchType type) {
    final counts = ps.stats.typeCounts;
    if (ps.player.gender == Gender.male) {
      final md = counts[MatchType.menDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      if (type == MatchType.menDoubles) {
        return md > mx ? (md - mx).toDouble() : 0;
      }
      if (type == MatchType.mixedDoubles) {
        return mx > md ? (mx - md).toDouble() : 0;
      }
    } else {
      final wd = counts[MatchType.womenDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      if (type == MatchType.womenDoubles) {
        return wd > mx ? (wd - mx).toDouble() : 0;
      }
      if (type == MatchType.mixedDoubles) {
        return mx > wd ? (mx - wd).toDouble() : 0;
      }
    }
    return 0;
  }

  /// 試合のペナルティ計算
  double _calculateGamePenalty(MatchType type, PlayerWithStats p1,
      PlayerWithStats p2, PlayerWithStats p3, PlayerWithStats p4) {
    double penalty = 0;

    // 優先度2位: 種目バランス (Weight: 200.0)
    for (var ps in [p1, p2, p3, p4]) {
      penalty += _calculateTypeImbalancePenalty(ps, type) * 200.0;
    }

    // 優先度3位: ペア重複 (Weight: 50.0)
    penalty += (p1.stats.partnerCounts[p2.player.id] ?? 0) * 50.0;
    penalty += (p3.stats.partnerCounts[p4.player.id] ?? 0) * 50.0;

    // 優先度4位: 敵重複 (Weight: 10.0)
    for (var a in [p1, p2]) {
      for (var b in [p3, p4]) {
        penalty += (a.stats.opponentCounts[b.player.id] ?? 0) * 10.0;
      }
    }
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
}
