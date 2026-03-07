import 'dart:math';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';
import 'package:game_member_generator/domain/entities/team.dart';
import 'package:game_member_generator/domain/entities/gender.dart';

/// 試合数や対戦履歴の偏りを抑えたマッチメイキングアルゴリズム
class BalancedMatchAlgorithm implements MatchAlgorithm {
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
    final maleSelection = _splitMustAndCandidates(maleBuckets, requiredMale);
    final femaleSelection = _splitMustAndCandidates(femaleBuckets, requiredFemale);

    // 3. 最適な試合セットを探索
    return _findOptimalMatches(
      matchTypes: matchTypes,
      maleSelection: maleSelection,
      femaleSelection: femaleSelection,
      requiredMale: requiredMale,
      requiredFemale: requiredFemale,
    );
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
    final assignmentResult = _searchBestAssignment(
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
    sortedCandidates.sort((a, b) => a.stats.sessionsSinceLastRest.compareTo(b.stats.sessionsSinceLastRest));

    picked.addAll(sortedCandidates.take(needed));
    return picked;
  }

  /// 決定したメンバーを各コート（matchTypes）へ最適に割り振る
  _AssignmentResult _searchBestAssignment({
    required List<MatchType> matchTypes,
    required List<PlayerWithStats> availableMales,
    required List<PlayerWithStats> availableFemales,
  }) {
    return _recurseAssignment(matchTypes, 0, availableMales, availableFemales);
  }

  /// 再帰的にすべてのコートへのプレイヤーの割り振りを試す
  _AssignmentResult _recurseAssignment(
    List<MatchType> types,
    int typeIndex,
    List<PlayerWithStats> males,
    List<PlayerWithStats> females,
  ) {
    if (typeIndex >= types.length) return _AssignmentResult(0, []);

    final type = types[typeIndex];
    double bestScore = double.infinity;
    List<Game> bestGames = [];

    if (type == MatchType.menDoubles) {
      final combos = _getCombinations(males, 4);
      for (final selected in combos) {
        final remaining = males.where((m) => !selected.contains(m)).toList();
        final gameScore = _getBestGameForFour(type, selected);
        final next = _recurseAssignment(types, typeIndex + 1, remaining, females);
        if (gameScore.score + next.score < bestScore) {
          bestScore = gameScore.score + next.score;
          bestGames = [gameScore.game, ...next.games];
        }
      }
    } else if (type == MatchType.womenDoubles) {
      final combos = _getCombinations(females, 4);
      for (final selected in combos) {
        final remaining = females.where((f) => !selected.contains(f)).toList();
        final gameScore = _getBestGameForFour(type, selected);
        final next = _recurseAssignment(types, typeIndex + 1, males, remaining);
        if (gameScore.score + next.score < bestScore) {
          bestScore = gameScore.score + next.score;
          bestGames = [gameScore.game, ...next.games];
        }
      }
    } else {
      // 混合ダブルス
      final mCombos = _getCombinations(males, 2);
      final fCombos = _getCombinations(females, 2);
      for (final selectedM in mCombos) {
        final remainingM = males.where((m) => !selectedM.contains(m)).toList();
        for (final selectedF in fCombos) {
          final remainingF = females.where((f) => !selectedF.contains(f)).toList();
          final gameScore = _getBestMixedGame(type, selectedM, selectedF);
          final next = _recurseAssignment(types, typeIndex + 1, remainingM, remainingF);
          if (gameScore.score + next.score < bestScore) {
            bestScore = gameScore.score + next.score;
            bestGames = [gameScore.game, ...next.games];
          }
        }
      }
    }

    return _AssignmentResult(bestScore, bestGames);
  }

  /// 4人の中で最適なチーム分け（3パターン）を決定
  _GameScore _getBestGameForFour(MatchType type, List<PlayerWithStats> p) {
    final patterns = [
      [p[0], p[1], p[2], p[3]],
      [p[0], p[2], p[1], p[3]],
      [p[0], p[3], p[1], p[2]],
    ];

    double minScore = double.infinity;
    late Game bestGame;

    for (final pattern in patterns) {
      double score = _calculateGamePenalty(type, pattern[0], pattern[1], pattern[2], pattern[3]);
      if (score < minScore) {
        minScore = score;
        bestGame = Game(type, Team(pattern[0].player, pattern[1].player), Team(pattern[2].player, pattern[3].player));
      }
    }
    return _GameScore(minScore, bestGame);
  }

  /// 混合ダブルスで最適なチーム分け（2パターン）を決定
  _GameScore _getBestMixedGame(MatchType type, List<PlayerWithStats> ms, List<PlayerWithStats> fs) {
    final patterns = [
      [ms[0], fs[0], ms[1], fs[1]],
      [ms[0], fs[1], ms[1], fs[0]],
    ];
    double minScore = double.infinity;
    late Game bestGame;
    for (final pattern in patterns) {
      double score = _calculateGamePenalty(type, pattern[0], pattern[1], pattern[2], pattern[3]);
      if (score < minScore) {
        minScore = score;
        bestGame = Game(type, Team(pattern[0].player, pattern[1].player), Team(pattern[2].player, pattern[3].player));
      }
    }
    return _GameScore(minScore, bestGame);
  }

  /// 試合のペナルティ計算
  double _calculateGamePenalty(MatchType type, PlayerWithStats p1, PlayerWithStats p2, PlayerWithStats p3, PlayerWithStats p4) {
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

  double _calculateTypeImbalancePenalty(PlayerWithStats ps, MatchType type) {
    final counts = ps.stats.typeCounts;
    if (ps.player.gender == Gender.male) {
      final md = counts[MatchType.menDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      if (type == MatchType.menDoubles) return md > mx ? (md - mx).toDouble() : 0;
      if (type == MatchType.mixedDoubles) return mx > md ? (mx - md).toDouble() : 0;
    } else {
      final wd = counts[MatchType.womenDoubles] ?? 0;
      final mx = counts[MatchType.mixedDoubles] ?? 0;
      if (type == MatchType.womenDoubles) return wd > mx ? (wd - mx).toDouble() : 0;
      if (type == MatchType.mixedDoubles) return mx > wd ? (mx - wd).toDouble() : 0;
    }
    return 0;
  }

  List<List<T>> _getCombinations<T>(List<T> items, int n) {
    if (n <= 0) return [[]];
    if (items.isEmpty) return [];
    final result = <List<T>>[];
    for (int i = 0; i <= items.length - n; i++) {
      final first = items[i];
      for (final combo in _getCombinations(items.sublist(i + 1), n - 1)) {
        result.add([first, ...combo]);
      }
    }
    return result;
  }

  _SelectionSplit _splitMustAndCandidates(Map<int, PlayerStatsPool> buckets, int requiredCount) {
    final List<PlayerWithStats> must = [];
    final sortedKeys = buckets.keys.toList()..sort();
    for (final count in sortedKeys) {
      final pool = buckets[count]!;
      if (must.length + pool.length <= requiredCount) {
        must.addAll(pool.all);
        if (must.length == requiredCount) return _SelectionSplit(must, PlayerStatsPool([]));
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

class _AssignmentResult {
  final double score;
  final List<Game> games;
  _AssignmentResult(this.score, this.games);
}

class _GameScore {
  final double score;
  final Game game;
  _GameScore(this.score, this.game);
}
