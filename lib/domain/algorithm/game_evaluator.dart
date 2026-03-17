import 'package:flutter/foundation.dart';
import 'package:game_member_generator/domain/algorithm/session_score.dart';

import '../entities/game.dart';
import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player_with_stats.dart';
import '../entities/team.dart';

/// evaluate which game member is better by given players
class GameEvaluator {
  double calculateSessionScore(List<PlayerWithStats> selectedMales,
      List<PlayerWithStats> selectedFemales) {
    var gameNumGain = 100000;
    return gameNumGain *
        _calculateGameNumPenalty(selectedMales, selectedFemales);
  }

  double _calculateGameNumPenalty(List<PlayerWithStats> selectedMales,
      List<PlayerWithStats> selectedFemales) {
    var totaGameNum = 0.0;
    var all = [...selectedMales, ...selectedFemales];
    for (var p in all) {
      totaGameNum += p.stats.totalMatches;
    }
    return totaGameNum;
  }

  bool existExcludedPair(
      List<PlayerWithStats> males, List<PlayerWithStats> females) {
    final malePartnerMap = {
      for (var p in males)
        if (p.player.excludedPartnerId != null)
          p.player.id: p.player.excludedPartnerId
    };

    bool pairFound = false;
    // 2. 女性リストを1回だけ回して、相手が男性リストにいるか確認
    for (var female in females) {
      final targetMaleId = female.player.excludedPartnerId;
      if (targetMaleId == null) continue;

      // 「女性が指している男性」が、実際に男性リストに存在し、
      // かつ「その男性もこの女性を指している」かチェック
      if (malePartnerMap[targetMaleId] == female.id) {
        pairFound = true;
        if (kDebugMode) {
          print(
              'Found excluded pair: ${female.name} and ${malePartnerMap[targetMaleId]}');
        }
      }
    }
    return pairFound;
  }

  double _calculateTypeImbalancePenalty(PlayerWithStats ps, MatchType type) {
    final counts = ps.stats.typeCounts;
    if (ps.player.gender == Gender.male) {
      final md = counts[MatchType.menDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      final total = md + mx;
      if (total == 0) {
        return 0;
      }
      if (type == MatchType.menDoubles) {
        return md / total;
      }
      if (type == MatchType.mixedDoubles) {
        return mx / total;
      }
    } else {
      final wd = counts[MatchType.womenDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      final total = wd + mx;
      if (total == 0) {
        return 0;
      }
      if (type == MatchType.womenDoubles) {
        return wd / total;
      }
      if (type == MatchType.mixedDoubles) {
        return mx / total;
      }
    }
    return 0;
  }

  double _calculatePariCountPenalty(PlayerWithStats p1, PlayerWithStats p2,
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

  /// 試合のペナルティ計算
  double _calculateGamePenalty(MatchType type, PlayerWithStats p1,
      PlayerWithStats p2, PlayerWithStats p3, PlayerWithStats p4) {
    double penalty = 0;

    // 優先度2位: 種目バランス
    for (var ps in [p1, p2, p3, p4]) {
      penalty += _calculateTypeImbalancePenalty(ps, type) * 100.0;
    }
    penalty += _calculatePariCountPenalty(p1, p2, p3, p4);
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
}
