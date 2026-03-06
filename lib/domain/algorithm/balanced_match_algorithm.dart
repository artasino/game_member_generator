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
    final mCombos = maleCombos.isEmpty ? [ <PlayerWithStats>[] ] : maleCombos;
    final fCombos = femaleCombos.isEmpty ? [ <PlayerWithStats>[] ] : femaleCombos;

    for (final mCombo in mCombos) {
      final playingMales = [...maleSelection.mustPlayers, ...mCombo];
      final restingMales = maleSelection.candidatePool.all.where((p) => !mCombo.contains(p)).toList();

      for (final fCombo in fCombos) {
        final playingFemales = [...femaleSelection.mustPlayers, ...fCombo];
        final restingFemales = femaleSelection.candidatePool.all.where((p) => !fCombo.contains(p)).toList();

        // A. 選出スコア（休みの偏り）を計算
        double selectionScore = _calculateRestingScore([...restingMales, ...restingFemales]);

        // B. このメンバ内での最適な「コートへの割り振り」を探索
        final assignmentResult = _searchBestAssignment(
          matchTypes: matchTypes,
          availableMales: List.from(playingMales),
          availableFemales: List.from(playingFemales),
        );

        double totalScore = selectionScore + assignmentResult.score;

        if (totalScore < bestTotalScore) {
          bestTotalScore = totalScore;
          bestGames = assignmentResult.games;
        }
      }
    }

    if (bestGames.isEmpty) throw Exception('最適な試合構成が見つかりませんでした');
    return bestGames;
  }

  /// 休みの偏りに対するペナルティ
  double _calculateRestingScore(List<PlayerWithStats> resting) {
    double score = 0;
    for (final r in resting) {
      if (r.stats.restedLastTime) {
        score += 10000.0; // 連続休みは最優先で回避
      }
      score += 100.0 / (r.stats.totalMatches + 1);
    }
    return score;
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
      // 残っている男性から4人選ぶ全パターンを試す
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
      // 残っている女性から4人選ぶ全パターンを試す
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
      // 混合ダブルス: 男性2人、女性2人を選ぶ全パターンを試す
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
      double score = _calculateGamePenalty(pattern[0], pattern[1], pattern[2], pattern[3]);
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
      [ms[0], fs[0], ms[1], fs[1]], // M1-F1 vs M2-F2
      [ms[0], fs[1], ms[1], fs[0]], // M1-F2 vs M2-F1
    ];
    double minScore = double.infinity;
    late Game bestGame;
    for (final pattern in patterns) {
      double score = _calculateGamePenalty(pattern[0], pattern[1], pattern[2], pattern[3]);
      if (score < minScore) {
        minScore = score;
        bestGame = Game(type, Team(pattern[0].player, pattern[1].player), Team(pattern[2].player, pattern[3].player));
      }
    }
    return _GameScore(minScore, bestGame);
  }

  /// 指定されたペアと対戦相手の履歴ペナルティを計算
  double _calculateGamePenalty(PlayerWithStats p1, PlayerWithStats p2, PlayerWithStats p3, PlayerWithStats p4) {
    double p = 0;
    // ペアが同じにならない (Penalty 50)
    p += (p1.stats.partnerCounts[p2.player.id] ?? 0) * 50.0;
    p += (p3.stats.partnerCounts[p4.player.id] ?? 0) * 50.0;
    
    // 敵が同じにならない (Penalty 10)
    final teamA = [p1, p2];
    final teamB = [p3, p4];
    for (var a in teamA) {
      for (var b in teamB) {
        p += (a.stats.opponentCounts[b.player.id] ?? 0) * 10.0;
      }
    }
    return p;
  }

  /// 組み合わせ生成のヘルパー関数
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
