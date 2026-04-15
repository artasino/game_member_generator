import 'dart:developer' as dev;
import 'dart:math';

import 'package:game_member_generator/config/app_config.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/session_score.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

import '../player_selector_util.dart';

class StochasticCourtAssignmentAlgorithm implements CourtAssignmentAlgorithm {
  final GameEvaluator gameEvaluator;

  StochasticCourtAssignmentAlgorithm({required this.gameEvaluator});

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
    final loopCount = AppConfig.loopCount;

    var state = AlgorithmsState.initial(
      mustMales: mustMales,
      candidateMales: candidateMales,
      requiredMale: types.requiredPlayerCount(isMale: true),
      mustFemales: mustFemales,
      candidateFemales: candidateFemales,
      requiredFemale: types.requiredPlayerCount(isMale: false),
    );

    SessionScore bestSession = _evaluate(
        state, types, previousMaleSelections, previousFemaleSelections);

    for (int i = 0; i < loopCount; i++) {
      final newState = state.copyWithSwap();
      final nextScore = _evaluate(
          newState, types, previousMaleSelections, previousFemaleSelections);

      if (nextScore.score < bestSession.score) {
        bestSession = nextScore;
        state = newState;
        dev.log('Best score: ${bestSession.score.toStringAsFixed(2)} at $i',
            name: "stochastic_algo");
      }
    }
    return bestSession;
  }

  SessionScore _evaluate(
    AlgorithmsState state,
    List<MatchType> types,
    List<Set<String>> prevMales,
    List<Set<String>> prevFemales,
  ) {
    return gameEvaluator.evaluateSession(
      matchTypes: types,
      selectedMales: state.selectedMales,
      benchMales: state.benchMales,
      selectedFemales: state.selectedFemales,
      benchFemales: state.benchFemales,
      previousMaleSelections: prevMales,
      previousFemaleSelections: prevFemales,
    );
  }
}

class AlgorithmsState {
  final List<PlayerWithStats> selectedMales;
  final List<PlayerWithStats> benchMales;
  final List<PlayerWithStats> candidateMales;
  final List<PlayerWithStats> selectedFemales;
  final List<PlayerWithStats> benchFemales;
  final List<PlayerWithStats> candidateFemales;

  AlgorithmsState({
    required this.selectedMales,
    required this.benchMales,
    required this.candidateMales,
    required this.selectedFemales,
    required this.benchFemales,
    required this.candidateFemales,
  });

  factory AlgorithmsState.initial({
    required List<PlayerWithStats> mustMales,
    required List<PlayerWithStats> candidateMales,
    required int requiredMale,
    required List<PlayerWithStats> mustFemales,
    required List<PlayerWithStats> candidateFemales,
    required int requiredFemale,
  }) {
    final sMales = PlayerSelectorUtil.pickCourtMembers(
        mustMales, candidateMales, requiredMale);
    final sFemales = PlayerSelectorUtil.pickCourtMembers(
        mustFemales, candidateFemales, requiredFemale);

    return AlgorithmsState(
      selectedMales: sMales,
      benchMales: candidateMales.where((p) => !sMales.contains(p)).toList(),
      candidateMales: candidateMales,
      selectedFemales: sFemales,
      benchFemales:
          candidateFemales.where((p) => !sFemales.contains(p)).toList(),
      candidateFemales: candidateFemales,
    );
  }

  AlgorithmsState copyWithSwap() {
    final random = Random();
    final isMale = random.nextBool();
    final benchSwapProb = 0.2;

    if (random.nextDouble() < benchSwapProb) {
      return _swapWithBench(isMale);
    } else {
      return _swapPositions(isMale);
    }
  }

  AlgorithmsState _swapWithBench(bool isMale) {
    if (isMale) {
      final (newSelected, newBench) =
          _doSwapWithBench(selectedMales, benchMales, candidateMales);
      return _copy(sMales: newSelected, bMales: newBench);
    } else {
      final (newSelected, newBench) =
          _doSwapWithBench(selectedFemales, benchFemales, candidateFemales);
      return _copy(sFemales: newSelected, bFemales: newBench);
    }
  }

  (List<PlayerWithStats>, List<PlayerWithStats>) _doSwapWithBench(
      List<PlayerWithStats> selected,
      List<PlayerWithStats> bench,
      List<PlayerWithStats> candidates) {
    if (bench.isEmpty) return (selected, bench);

    final random = Random();
    final candidateSet = candidates.toSet();
    final indices = [
      for (int i = 0; i < selected.length; i++)
        if (candidateSet.contains(selected[i])) i
    ];
    if (indices.isEmpty) return (selected, bench);

    final resSelected = List<PlayerWithStats>.from(selected);
    final resBench = List<PlayerWithStats>.from(bench);

    final sIdx = indices[random.nextInt(indices.length)];
    final bIdx = random.nextInt(resBench.length);

    final temp = resSelected[sIdx];
    resSelected[sIdx] = resBench[bIdx];
    resBench[bIdx] = temp;

    return (resSelected, resBench);
  }

  AlgorithmsState _swapPositions(bool isMale) {
    if (isMale) {
      return _copy(sMales: _doSwapPositions(selectedMales));
    } else {
      return _copy(sFemales: _doSwapPositions(selectedFemales));
    }
  }

  List<PlayerWithStats> _doSwapPositions(List<PlayerWithStats> list) {
    if (list.length < 2) return list;
    final res = List<PlayerWithStats>.from(list);
    final random = Random();
    int i1 = random.nextInt(res.length);
    int i2 = (i1 + 1 + random.nextInt(res.length - 1)) % res.length;
    final temp = res[i1];
    res[i1] = res[i2];
    res[i2] = temp;
    return res;
  }

  AlgorithmsState _copy({
    List<PlayerWithStats>? sMales,
    List<PlayerWithStats>? bMales,
    List<PlayerWithStats>? sFemales,
    List<PlayerWithStats>? bFemales,
  }) {
    return AlgorithmsState(
      selectedMales: sMales ?? selectedMales,
      benchMales: bMales ?? benchMales,
      candidateMales: candidateMales,
      selectedFemales: sFemales ?? selectedFemales,
      benchFemales: bFemales ?? benchFemales,
      candidateFemales: candidateFemales,
    );
  }
}
