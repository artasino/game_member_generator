import 'dart:math';

import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/session_score.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

import '../game_evaluator.dart';

class BestForceCourtAssignmentAlgorithm implements CourtAssignmentAlgorithm {
  GameEvaluator gameEvaluator;

  BestForceCourtAssignmentAlgorithm({required this.gameEvaluator});

  @override
  SessionScore searchBestAssignment({
    required List<MatchType> types,
    required List<PlayerWithStats> mustMales,
    required List<PlayerWithStats> mustFemales,
    required List<PlayerWithStats> candidateMales,
    required List<PlayerWithStats> candidateFemales,
    List<Set<String>> previousMaleSelections = const [],
    List<Set<String>> previousFemaleSelections = const [],
  }) {
    var requiredMale = types.requiredPlayerCount(isMale: true);
    var requiredFemale = types.requiredPlayerCount(isMale: false);

    List<PlayerWithStats> selectedMales =
        _pickCourtMembers(mustMales, candidateMales, requiredMale);
    List<PlayerWithStats> selectedFemales =
        _pickCourtMembers(mustFemales, candidateFemales, requiredFemale);

    final selectedMaleSet = selectedMales.toSet();
    List<PlayerWithStats> benchMales =
        candidateMales.where((p) => !selectedMaleSet.contains(p)).toList();
    final selectedFemaleSet = selectedFemales.toSet();
    List<PlayerWithStats> benchFemales =
        candidateFemales.where((p) => !selectedFemaleSet.contains(p)).toList();

    double penalty = 0;

    // 同一メンバーペナルティ
    final currentMaleIds = selectedMales.map((p) => p.player.id).toSet();
    for (final prev in previousMaleSelections) {
      if (prev.length == currentMaleIds.length &&
          prev.every(currentMaleIds.contains)) {
        penalty += 1000.0;
        break;
      }
    }

    final currentFemaleIds = selectedFemales.map((p) => p.player.id).toSet();
    for (final prev in previousFemaleSelections) {
      if (prev.length == currentFemaleIds.length &&
          prev.every(currentFemaleIds.contains)) {
        penalty += 1000.0;
        break;
      }
    }

    // 同時に休みペナルティ
    penalty += gameEvaluator.calculateRestTogetherPenalty(benchMales);
    penalty += gameEvaluator.calculateRestTogetherPenalty(benchFemales);

    final availablePlayers = [...selectedMales, ...selectedFemales];
    penalty +=
        gameEvaluator.calculateSessionsFromLastRestPenalty(availablePlayers);

    final sessionScore =
        _recurseAssignment(types, 0, selectedMales, selectedFemales);

    return SessionScore(sessionScore.score + penalty, sessionScore.games);
  }

  List<PlayerWithStats> _pickCourtMembers(
    List<PlayerWithStats> must,
    List<PlayerWithStats> candidates,
    int requiredCount,
  ) {
    final random = Random();
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

  /// 再帰的にすべてのコートへのプレイヤーの割り振りを試す
  SessionScore _recurseAssignment(
    List<MatchType> types,
    int typeIndex,
    List<PlayerWithStats> males,
    List<PlayerWithStats> females,
  ) {
    if (typeIndex >= types.length) {
      return SessionScore(0, []);
    }

    final type = types[typeIndex];
    double bestScore = double.infinity;
    List<Game> bestGames = [];

    if (type == MatchType.maleDoubles) {
      final combos = _getCombinations(males, 4);
      for (final selected in combos) {
        final remaining = males.where((m) => !selected.contains(m)).toList();
        final gameScore = gameEvaluator.getBestGameForFour(type, selected);
        final next =
            _recurseAssignment(types, typeIndex + 1, remaining, females);
        if (gameScore.score + next.score < bestScore) {
          bestScore = gameScore.score + next.score;
          bestGames = [gameScore.game, ...next.games];
        }
      }
    } else if (type == MatchType.femaleDoubles) {
      final combos = _getCombinations(females, 4);
      for (final selected in combos) {
        final remaining = females.where((f) => !selected.contains(f)).toList();
        final gameScore = gameEvaluator.getBestGameForFour(type, selected);
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
          final remainingF =
              females.where((f) => !selectedF.contains(f)).toList();
          final gameScore =
              gameEvaluator.getBestMixedGame(type, selectedM, selectedF);
          final next =
              _recurseAssignment(types, typeIndex + 1, remainingM, remainingF);
          if (gameScore.score + next.score < bestScore) {
            bestScore = gameScore.score + next.score;
            bestGames = [gameScore.game, ...next.games];
          }
        }
      }
    }

    return SessionScore(bestScore, bestGames);
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
}
