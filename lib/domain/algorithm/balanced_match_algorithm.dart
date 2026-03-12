import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

/// 試合数や対戦履歴の偏りを抑えたマッチメイキングアルゴリズム
class BalancedMatchAlgorithm implements MatchAlgorithm {
  GameEvaluator gameEvaluator;
  CourtAssignmentAlgorithm courtAssignmentAlgorithm;

  BalancedMatchAlgorithm({
    required this.gameEvaluator,
    required this.courtAssignmentAlgorithm,
  });

  @override
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required Map<int, PlayerStatsPool> maleBuckets,
    required Map<int, PlayerStatsPool> femaleBuckets,
  }) {
    // 1. 必要人数の計算
    int requiredMale = matchTypes.requiredPlayerCount(isMale: true);
    int requiredFemale = matchTypes.requiredPlayerCount(isMale: false);

    // 2. 出場回数に基づいた選出（Must枠と抽選プールの分離）
    // ここで isMustRest が true のプレイヤーをあらかじめ除外（候補から外す）する
    final filteredMaleBuckets = _filterMustRest(maleBuckets);
    final filteredFemaleBuckets = _filterMustRest(femaleBuckets);

    final maleSelection =
        _splitMustAndCandidates(filteredMaleBuckets, requiredMale);
    final femaleSelection =
        _splitMustAndCandidates(filteredFemaleBuckets, requiredFemale);

    // 3. 最適な試合セットを探索
    return _findOptimalMatches(
      matchTypes: matchTypes,
      maleSelection: maleSelection,
      femaleSelection: femaleSelection,
    );
  }

  /// isMustRest フラグが true のプレイヤーを除外したバケットを返す
  Map<int, PlayerStatsPool> _filterMustRest(Map<int, PlayerStatsPool> buckets) {
    return buckets.map((count, pool) {
      final filtered = pool.all.where((p) => !p.player.isMustRest).toList();
      return MapEntry(count, PlayerStatsPool(filtered));
    });
  }

  List<Game> _findOptimalMatches({
    required List<MatchType> matchTypes,
    required _SelectionSplit maleSelection,
    required _SelectionSplit femaleSelection,
  }) {
    // 2. 試合セットを探索する
    final assignmentResult = courtAssignmentAlgorithm.searchBestAssignment(
      types: matchTypes,
      mustMales: maleSelection.mustPlayers,
      mustFemales: femaleSelection.mustPlayers,
      candidateMales: maleSelection.candidatePool.all,
      candidateFemales: femaleSelection.candidatePool.all,
    );

    if (assignmentResult.games.isEmpty) {
      throw Exception('最適な試合構成が見つかりませんでした');
    }
    return assignmentResult.games;
  }

  _SelectionSplit _splitMustAndCandidates(
      Map<int, PlayerStatsPool> buckets, int requiredCount) {
    final List<PlayerWithStats> must = [];
    final sortedKeys = buckets.keys.toList()..sort();
    for (final count in sortedKeys) {
      final pool = buckets[count]!;
      if (must.length + pool.length <= requiredCount) {
        must.addAll(pool.all);
        if (must.length == requiredCount) {
          return _SelectionSplit(must, PlayerStatsPool([]));
        }
      } else {
        return _SelectionSplit(must, PlayerStatsPool(pool.all));
      }
    }
    return _SelectionSplit(must, PlayerStatsPool([]));
  }
}

class _SelectionSplit {
  final List<PlayerWithStats> mustPlayers;
  final PlayerStatsPool candidatePool;

  _SelectionSplit(this.mustPlayers, this.candidatePool);
}
