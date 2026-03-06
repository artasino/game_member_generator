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
    required Map<int, PlayerStatsPool> playerBuckets,
  }) {
    final random = Random();
    
    // 全バケットから平坦なリスト（ソート済み）を作成し、初期プールを構築
    final allPlayers = playerBuckets.values.expand((p) => p.all).toList();
    PlayerStatsPool currentPool = PlayerStatsPool(allPlayers);
    
    final matches = <Game>[];

    for (final matchType in matchTypes) {
      switch (matchType) {
        case MatchType.menDoubles:
          final result = currentPool.males.pickCandidates(4, random);
          if (result.picked.length < 4) throw Exception('男子プレイヤーが不足しています');
          matches.add(_createOptimizedGame(matchType, result.picked));
          currentPool = result.remainingPool;
          break;

        case MatchType.womenDoubles:
          final result = currentPool.females.pickCandidates(4, random);
          if (result.picked.length < 4) throw Exception('女子プレイヤーが不足しています');
          matches.add(_createOptimizedGame(matchType, result.picked));
          currentPool = result.remainingPool;
          break;

        case MatchType.mixedDoubles:
          final mResult = currentPool.males.pickCandidates(2, random);
          final fResult = currentPool.females.pickCandidates(2, random);
          if (mResult.picked.length < 2 || fResult.picked.length < 2) {
            throw Exception('混合Wのペアが不足しています');
          }
          matches.add(_createOptimizedMixedGame(matchType, mResult.picked, fResult.picked));
          currentPool = _removePickedFromPool(currentPool, [...mResult.picked, ...fResult.picked]);
          break;
      }
    }

    return matches;
  }

  PlayerStatsPool _removePickedFromPool(PlayerStatsPool pool, List<PlayerWithStats> picked) {
    final pickedIds = picked.map((p) => p.player.id).toSet();
    final remaining = pool.all.where((p) => !pickedIds.contains(p.player.id)).toList();
    return PlayerStatsPool(remaining);
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
