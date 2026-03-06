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

    // 3. 全ての選択肢の中から最適な試合セットを探索
    return _findOptimalMatches(
      matchTypes: matchTypes,
      maleSelection: maleSelection,
      femaleSelection: femaleSelection,
      requiredMale: requiredMale,
      requiredFemale: requiredFemale,
    );
  }

  /// 全ての選出パターンとチーム分けパターンを評価し、ベストな試合リストを返す
  List<Game> _findOptimalMatches({
    required List<MatchType> matchTypes,
    required _SelectionSplit maleSelection,
    required _SelectionSplit femaleSelection,
    required int requiredMale,
    required int requiredFemale,
  }) {
    // 抽選候補から必要な人数を選ぶ全組み合わせを取得
    final maleCombos = _getCombinations(
      maleSelection.candidatePool.all,
      requiredMale - maleSelection.mustPlayers.length,
    );
    final femaleCombos = _getCombinations(
      femaleSelection.candidatePool.all,
      requiredFemale - femaleSelection.mustPlayers.length,
    );

    double bestTotalScore = double.infinity;
    List<Game> bestGames = [];

    // コンビネーションが空の場合（全員Mustの場合など）のハンドリング
    final List<List<PlayerWithStats>> mCombos = maleCombos.isEmpty ? [ [] ] : maleCombos;
    final List<List<PlayerWithStats>> fCombos = femaleCombos.isEmpty ? [ [] ] : femaleCombos;

    for (final mCombo in mCombos) {
      final playingMales = [...maleSelection.mustPlayers, ...mCombo];
      final restingMales = maleSelection.candidatePool.all.where((p) => !mCombo.contains(p)).toList();

      for (final fCombo in fCombos) {
        final playingFemales = [...femaleSelection.mustPlayers, ...fCombo];
        final restingFemales = femaleSelection.candidatePool.all.where((p) => !fCombo.contains(p)).toList();

        // A. 選出スコア（休みの偏り）を計算
        double selectionScore = _calculateRestingScore([...restingMales, ...restingFemales]);

        // B. このメンバ内での最適なチーム分けを探索
        final matchResult = _searchBestAssignment(
          matchTypes: matchTypes,
          availableMales: List.from(playingMales),
          availableFemales: List.from(playingFemales),
        );

        double totalScore = selectionScore + matchResult.score;

        if (totalScore < bestTotalScore) {
          bestTotalScore = totalScore;
          bestGames = matchResult.games;
        }
      }
    }

    if (bestGames.isEmpty) throw Exception('最適な試合構成が見つかりませんでした');
    return bestGames;
  }

  /// 休みの偏りに対するペナルティ（低いほど良い）
  double _calculateRestingScore(List<PlayerWithStats> resting) {
    double score = 0;
    for (final r in resting) {
      // 直前にお休みだった人が再度お休みになる場合に非常に高いペナルティを課す（優先度1位）
      if (r.stats.restedLastTime) {
        score += 10000.0;
      }
      // 出場回数が少ない人が休む場合もペナルティ
      score += 100.0 / (r.stats.totalMatches + 1);
    }
    return score;
  }

  /// 決定したメンバーを各コート（matchTypes）へ最適に振り分ける
  _AssignmentResult _searchBestAssignment({
    required List<MatchType> matchTypes,
    required List<PlayerWithStats> availableMales,
    required List<PlayerWithStats> availableFemales,
  }) {
    return _recurseAssignment(matchTypes, 0, availableMales, availableFemales);
  }

  _AssignmentResult _recurseAssignment(
    List<MatchType> types,
    int index,
    List<PlayerWithStats> males,
    List<PlayerWithStats> females,
  ) {
    if (index >= types.length) return _AssignmentResult(0, []);

    final type = types[index];
    
    if (type == MatchType.menDoubles) {
      final selected = males.take(4).toList();
      final remainingMales = males.skip(4).toList();
      final bestGame = _getBestGameForFour(type, selected);
      final next = _recurseAssignment(types, index + 1, remainingMales, females);
      return _AssignmentResult(bestGame.score + next.score, [bestGame.game, ...next.games]);
    } else if (type == MatchType.womenDoubles) {
      final selected = females.take(4).toList();
      final remainingFemales = females.skip(4).toList();
      final bestGame = _getBestGameForFour(type, selected);
      final next = _recurseAssignment(types, index + 1, males, remainingFemales);
      return _AssignmentResult(bestGame.score + next.score, [bestGame.game, ...next.games]);
    } else {
      // 混合ダブルス
      final selectedM = males.take(2).toList();
      final remainingM = males.skip(2).toList();
      final selectedF = females.take(2).toList();
      final remainingF = females.skip(2).toList();
      final bestGame = _getBestMixedGame(type, selectedM, selectedF);
      final next = _recurseAssignment(types, index + 1, remainingM, remainingF);
      return _AssignmentResult(bestGame.score + next.score, [bestGame.game, ...next.games]);
    }
  }

  /// 4人の中で、過去の「ペア回数(50点)」「敵回数(10点)」が最小になる分け方を決定
  _GameScore _getBestGameForFour(MatchType type, List<PlayerWithStats> p) {
    final patterns = [
      [p[0], p[1], p[2], p[3]],
      [p[0], p[2], p[1], p[3]],
      [p[0], p[3], p[1], p[2]],
    ];

    double minScore = double.infinity;
    late Game bestGame;

    for (final pattern in patterns) {
      final tA = Team(pattern[0].player, pattern[1].player);
      final tB = Team(pattern[2].player, pattern[3].player);
      double score = _calculateGamePenalty(pattern[0], pattern[1], pattern[2], pattern[3]);
      if (score < minScore) {
        minScore = score;
        bestGame = Game(type, tA, tB);
      }
    }
    return _GameScore(minScore, bestGame);
  }

  _GameScore _getBestMixedGame(MatchType type, List<PlayerWithStats> ms, List<PlayerWithStats> fs) {
    final patterns = [
      [ms[0], fs[0], ms[1], fs[1]],
      [ms[0], fs[1], ms[1], fs[0]],
    ];
    double minScore = double.infinity;
    late Game bestGame;
    for (final pattern in patterns) {
      final tA = Team(pattern[0].player, pattern[1].player);
      final tB = Team(pattern[2].player, pattern[3].player);
      double score = _calculateGamePenalty(pattern[0], pattern[1], pattern[2], pattern[3]);
      if (score < minScore) {
        minScore = score;
        bestGame = Game(type, tA, tB);
      }
    }
    return _GameScore(minScore, bestGame);
  }

  double _calculateGamePenalty(PlayerWithStats p1, PlayerWithStats p2, PlayerWithStats p3, PlayerWithStats p4) {
    double p = 0;
    // ペアが同じにならない（優先度2位: 50点）
    p += (p1.stats.partnerCounts[p2.player.id] ?? 0) * 50.0;
    p += (p3.stats.partnerCounts[p4.player.id] ?? 0) * 50.0;
    
    // 敵が同じにならない（優先度3位: 10点）
    final teamAPlayers = [p1, p2];
    final teamBPlayers = [p3, p4];
    for (var a in teamAPlayers) {
      for (var b in teamBPlayers) {
        p += (a.stats.opponentCounts[b.player.id] ?? 0) * 10.0;
      }
    }
    return p;
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
