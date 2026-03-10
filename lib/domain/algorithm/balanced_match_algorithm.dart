import 'dart:math';

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
      requiredMale: requiredMale,
      requiredFemale: requiredFemale,
    );
  }

  /// isMustRest フラグが true のプレイヤーを除外したバケットを返す
  Map<int, PlayerStatsPool> _filterMustRest(Map<int, PlayerStatsPool> buckets) {
    return buckets.map((count, pool) {
      final filtered = pool.all.where((p) => !p.player.isMustRest).toList();
      return MapEntry(count, PlayerStatsPool(filtered));
    });
  }

  /// 出場メンバーを確定させた後、最適な試合リストを返す
  List<Game> _findOptimalMatches({
    required List<MatchType> matchTypes,
    required _SelectionSplit maleSelection,
    required _SelectionSplit femaleSelection,
    required int requiredMale,
    required int requiredFemale,
  }) {
    final random = Random();

    // 1. メンバーを選出する (前回休みからの間隔が短い人を優先して固定)
    final playingMales = _pickFinalMembers(
      maleSelection.mustPlayers,
      maleSelection.candidatePool.all,
      requiredMale,
      random,
    );
    final playingFemales = _pickFinalMembers(
      femaleSelection.mustPlayers,
      femaleSelection.candidatePool.all,
      requiredFemale,
      random,
    );

    // 2. 固定されたメンバー内で最適な「コートへの割り振り」を探索
    final assignmentResult = courtAssignmentAlgorithm.searchBestAssignment(
      matchTypes: matchTypes,
      availableMales: playingMales,
      availableFemales: playingFemales,
    );

    if (assignmentResult.games.isEmpty) {
      throw Exception('最適な試合構成が見つかりませんでした');
    }
    return assignmentResult.games;
  }

  /// 優先度（休み間隔が短い > ランダム）に基づいて最終的なメンバーを決定する
  List<PlayerWithStats> _pickFinalMembers(
    List<PlayerWithStats> must,
    List<PlayerWithStats> candidates,
    int requiredCount,
    Random random,
  ) {
    final picked = List<PlayerWithStats>.from(must);
    final needed = requiredCount - picked.length;
    if (needed <= 0) return picked;

    final sortedCandidates = List<PlayerWithStats>.from(candidates);
    // 偏りを防ぐためにまずシャッフル
    sortedCandidates.shuffle(random);
    // 「前の休みからの試合間隔」が短い順（sessionsSinceLastRestが小さい＝直近で休んだ人）にソート
    sortedCandidates.sort((a, b) =>
        a.stats.sessionsSinceLastRest.compareTo(b.stats.sessionsSinceLastRest));

    picked.addAll(sortedCandidates.take(needed));
    return picked;
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
