import 'dart:math';

import 'package:game_member_generator/domain/entities/player_stats_pool.dart';

import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/team.dart';
import 'match_algorithm.dart';

/// ランダムに試合の組み合わせを生成するアルゴリズム
class RandomMatchAlgorithm implements MatchAlgorithm {
  @override
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required Map<int, PlayerStatsPool> maleBuckets,
    required Map<int, PlayerStatsPool> femaleBuckets,
  }) {
    final random = Random();
    
    // 男女それぞれのバケットからプレイヤーリストを平坦化して作成
    final males = maleBuckets.values.expand((pool) => pool.all).map((ps) => ps.player).toList();
    final females = femaleBuckets.values.expand((pool) => pool.all).map((ps) => ps.player).toList();
    
    // 完全にランダムにするためにシャッフル
    males.shuffle(random);
    females.shuffle(random);

    final matches = <Game>[];
    for (final matchType in matchTypes) {
      switch (matchType) {
        case MatchType.menDoubles:
          if (males.length < 4) {
            throw Exception('男子プレイヤーが不足しています');
          }
          final teamA = Team(males.removeAt(0), males.removeAt(0));
          final teamB = Team(males.removeAt(0), males.removeAt(0));
          matches.add(Game(matchType, teamA, teamB));
          break;
        case MatchType.womenDoubles:
          if (females.length < 4) {
            throw Exception('女子プレイヤーが不足しています');
          }
          final teamA = Team(females.removeAt(0), females.removeAt(0));
          final teamB = Team(females.removeAt(0), females.removeAt(0));
          matches.add(Game(matchType, teamA, teamB));
          break;
        case MatchType.mixedDoubles:
          if (males.length < 2 || females.length < 2) {
            throw Exception('混合Wのペアが不足しています');
          }
          final teamA = Team(males.removeAt(0), females.removeAt(0));
          final teamB = Team(males.removeAt(0), females.removeAt(0));
          matches.add(Game(matchType, teamA, teamB));
          break;
      }
    }
    
    if (matchTypes.length != matches.length) {
      throw Exception('試合を生成しきれませんでした');
    }
    return matches;
  }
}
