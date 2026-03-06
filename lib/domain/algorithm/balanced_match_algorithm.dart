import 'dart:math';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';
import 'package:game_member_generator/domain/entities/team.dart';

/// 試合数や対戦履歴の偏りを抑えたマッチメイキングアルゴリズム
class BalancedMatchAlgorithm implements MatchAlgorithm {
  @override
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required Map<int, PlayerStatsPool> maleBuckets,
    required Map<int, PlayerStatsPool> femaleBuckets,
  }) {
    final random = Random();

    // 1. 必要人数の計算
    int requiredMale = 0;
    int requiredFemale = 0;
    for (final type in matchTypes) {
      if (type == MatchType.menDoubles) {
        requiredMale += 4;
      } else if (type == MatchType.womenDoubles) {
        requiredFemale += 4;
      } else if (type == MatchType.mixedDoubles) {
        requiredMale += 2;
        requiredFemale += 2;
      }
    }

    // 2. 出場回数に基づいた選出（Must枠と抽選プールの分離）
    final maleSelection = _splitMustAndCandidates(maleBuckets, requiredMale);
    final femaleSelection = _splitMustAndCandidates(femaleBuckets, requiredFemale);

    // 3. 抽選プールから不足分をピックアップ
    final List<PlayerWithStats> malePicked = List.from(maleSelection.mustPlayers);
    if (malePicked.length < requiredMale) {
      final needed = requiredMale - malePicked.length;
      final result = maleSelection.candidatePool.pickCandidates(needed, random);
      if (result.picked.length < needed) throw Exception('男子プレイヤーが不足しています');
      malePicked.addAll(result.picked);
    }

    final List<PlayerWithStats> femalePicked = List.from(femaleSelection.mustPlayers);
    if (femalePicked.length < requiredFemale) {
      final needed = requiredFemale - femalePicked.length;
      final result = femaleSelection.candidatePool.pickCandidates(needed, random);
      if (result.picked.length < needed) throw Exception('女子プレイヤーが不足しています');
      femalePicked.addAll(result.picked);
    }

    // 4. 試合の構築（シャッフルして割り当て）
    malePicked.shuffle(random);
    femalePicked.shuffle(random);

    final matches = <Game>[];
    for (final matchType in matchTypes) {
      switch (matchType) {
        case MatchType.menDoubles:
          final selected = malePicked.take(4).toList();
          malePicked.removeRange(0, 4);
          matches.add(_createOptimizedGame(matchType, selected));
          break;
        case MatchType.womenDoubles:
          final selected = femalePicked.take(4).toList();
          femalePicked.removeRange(0, 4);
          matches.add(_createOptimizedGame(matchType, selected));
          break;
        case MatchType.mixedDoubles:
          final ms = malePicked.take(2).toList();
          malePicked.removeRange(0, 2);
          final fs = femalePicked.take(2).toList();
          femalePicked.removeRange(0, 2);
          matches.add(_createOptimizedMixedGame(matchType, ms, fs));
          break;
      }
    }

    return matches;
  }

  /// バケットを走査して、「全員入れても必要数を超えない」メンバをMustリストに、
  /// 超えた瞬間のバケットのメンバのみをCandidatePoolに分ける
  _SelectionSplit _splitMustAndCandidates(Map<int, PlayerStatsPool> buckets, int requiredCount) {
    final List<PlayerWithStats> must = [];

    // バケットは出場回数の昇順でソートされている必要がある
    final sortedKeys = buckets.keys.toList()..sort();

    for (final count in sortedKeys) {
      final pool = buckets[count]!;
      if (must.length + pool.length <= requiredCount) {
        // このバケットの全員を入れても上限に達しない場合は全員確定
        must.addAll(pool.all);
        if (must.length == requiredCount) {
          return _SelectionSplit(must, PlayerStatsPool([]));
        }
      } else {
        // このバケットを入れると上限を超えるので、このバケットのメンバのみを抽選対象にする
        return _SelectionSplit(must, PlayerStatsPool(pool.all));
      }
    }

    return _SelectionSplit(must, PlayerStatsPool([]));
  }

  Game _createOptimizedGame(MatchType type, List<PlayerWithStats> candidates) {
    final teamA = Team(candidates[0].player, candidates[1].player);
    final teamB = Team(candidates[2].player, candidates[3].player);
    return Game(type, teamA, teamB);
  }

  Game _createOptimizedMixedGame(MatchType type, List<PlayerWithStats> ms, List<PlayerWithStats> fs) {
    final teamA = Team(ms[0].player, fs[0].player);
    final teamB = Team(ms[1].player, fs[1].player);
    return Game(type, teamA, teamB);
  }
}

class _SelectionSplit {
  final List<PlayerWithStats> mustPlayers;
  final PlayerStatsPool candidatePool;
  _SelectionSplit(this.mustPlayers, this.candidatePool);
}
