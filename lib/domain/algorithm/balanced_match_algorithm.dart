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


    PlayerStatsPool malePool = PlayerStatsPool(maleBuckets.values.expand((p) => p.all).toList());
    PlayerStatsPool femalePool = PlayerStatsPool(femaleBuckets.values.expand((p) => p.all).toList());

    final matches = <Game>[];

    for (final matchType in matchTypes) {
      switch (matchType) {
        case MatchType.menDoubles:
          final result = malePool.pickCandidates(4, random);
          if (result.picked.length < 4) throw Exception('男子プレイヤーが不足しています');
          matches.add(_createOptimizedGame(matchType, result.picked));
          malePool = result.remainingPool;
          break;

        case MatchType.womenDoubles:
          final result = femalePool.pickCandidates(4, random);
          if (result.picked.length < 4) throw Exception('女子プレイヤーが不足しています');
          matches.add(_createOptimizedGame(matchType, result.picked));
          femalePool = result.remainingPool;
          break;

        case MatchType.mixedDoubles:
          final mResult = malePool.pickCandidates(2, random);
          final fResult = femalePool.pickCandidates(2, random);
          if (mResult.picked.length < 2 || fResult.picked.length < 2) {
            throw Exception('混合Wのペアが不足しています');
          }
          matches.add(_createOptimizedMixedGame(matchType, mResult.picked, fResult.picked));
          malePool = mResult.remainingPool;
          femalePool = fResult.remainingPool;
          break;
      }
    }

    return matches;
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
