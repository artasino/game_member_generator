import 'dart:math';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';
import 'package:game_member_generator/domain/entities/team.dart';

/// 試合数や対戦履歴の偏りを抑えたマッチメイキングアルゴリズム
class BalancedMatchAlgorithm implements MatchAlgorithm {
  @override
  List<Game> generateMatches({
    required List<Player> players,
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerStats, // すでにラップされたプールを受け取る
  }) {
    final random = Random();
    
    // 1. 引数のプールから、今回のアクティブプレイヤーのみに絞り込む
    final activeIds = players.map((p) => p.id).toSet();
    final activeList = playerStats.all.where((p) => activeIds.contains(p.player.id)).toList();
    
    PlayerStatsPool currentPool = PlayerStatsPool(activeList);
    final matches = <Game>[];

    // 2. マッチタイプごとに選出
    for (final matchType in matchTypes) {
      switch (matchType) {
        case MatchType.menDoubles:
          final result = currentPool.males.pickCandidates(4, random);
          if (result.picked.length < 4) throw Exception('男子プレイヤーが不足しています');
          
          matches.add(_createOptimizedGame(matchType, result.picked));
          currentPool = result.remainingPool; // Pick結果の残りプールを使用
          break;

        case MatchType.womenDoubles:
          final result = currentPool.females.pickCandidates(4, random);
          if (result.picked.length < 4) throw Exception('女子プレイヤーが不足しています');
          
          matches.add(_createOptimizedGame(matchType, result.picked));
          currentPool = result.remainingPool;
          break;

        case MatchType.mixedDoubles:
          // 混合の場合は男女それぞれのプールから選ぶため、全体のプール管理が少し複雑
          // 一旦、男女それぞれからピックし、最後に全体から除外する
          final mResult = currentPool.males.pickCandidates(2, random);
          final fResult = currentPool.females.pickCandidates(2, random);
          if (mResult.picked.length < 2 || fResult.picked.length < 2) {
            throw Exception('混合Wのペアが不足しています');
          }
          
          matches.add(_createOptimizedMixedGame(matchType, mResult.picked, fResult.picked));
          // 選ばれたメンバを除外したプールで更新
          currentPool = _removePickedFromPool(currentPool, [...mResult.picked, ...fResult.picked]);
          break;
      }
    }

    return matches;
  }

  /// 指定したリストのメンバをプール全体から除外するヘルパー
  PlayerStatsPool _removePickedFromPool(PlayerStatsPool pool, List<PlayerWithStats> picked) {
    final pickedIds = picked.map((p) => p.player.id).toSet();
    final remaining = pool.all.where((p) => !pickedIds.contains(p.player.id)).toList();
    return PlayerStatsPool(remaining);
  }

  /// 選ばれた4人の中で、過去の履歴を見て最適な組み合わせを作る
  Game _createOptimizedGame(MatchType type, List<PlayerWithStats> candidates) {
    final teamA = Team(candidates[0].player, candidates[1].player);
    final teamB = Team(candidates[2].player, candidates[3].player);
    return Game(type, teamA, teamB);
  }

  /// 混合ダブルスの最適化
  Game _createOptimizedMixedGame(MatchType type, List<PlayerWithStats> ms, List<PlayerWithStats> fs) {
    final teamA = Team(ms[0].player, fs[0].player);
    final teamB = Team(ms[1].player, fs[1].player);
    return Game(type, teamA, teamB);
  }
}
