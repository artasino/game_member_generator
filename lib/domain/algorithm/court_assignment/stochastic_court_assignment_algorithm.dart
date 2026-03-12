import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:game_member_generator/config/app_config.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/session_score.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

import '../../entities/game.dart';
import '../player_selector_util.dart';

class StochasticCourtAssignmentAlgorithm implements CourtAssignmentAlgorithm {
  GameEvaluator gameEvaluator;

  StochasticCourtAssignmentAlgorithm({required this.gameEvaluator});

  @override
  SessionScore searchBestAssignment(
      {required List<MatchType> types,
      required List<PlayerWithStats> mustMales,
      required List<PlayerWithStats> mustFemales,
      required List<PlayerWithStats> candidateMales,
      required List<PlayerWithStats> candidateFemales}) {
    Random random = Random();
    final loopCount = AppConfig.loopCount;
    mustMales.shuffle(random);
    mustFemales.shuffle(random);
    return _findBestSession(loopCount, types, mustMales, mustFemales,
        candidateMales, candidateFemales);
  }

  SessionScore _findBestSession(
      int count,
      List<MatchType> types,
      List<PlayerWithStats> mustMales,
      List<PlayerWithStats> mustFemales,
      List<PlayerWithStats> candidateMales,
      List<PlayerWithStats> candidateFemales) {
    var requiredMale = types.requiredPlayerCount(isMale: true);
    var requiredFemale = types.requiredPlayerCount(isMale: false);
    var state = AlgorithmsState.initial(
        mustMales: mustMales,
        candidateMales: candidateMales,
        requiredMale: requiredMale,
        mustFemales: mustFemales,
        candidateFemales: candidateFemales,
        requiredFemale: requiredFemale);

    SessionScore bestSession =
        _calculateScore(types, state.selectedMales, state.selectedFemales);
    for (int i = 0; i < count; i++) {
      AlgorithmsState newState = state.copyWithSwap();

      final nextScore = _calculateScore(
          types, newState.selectedMales, newState.selectedFemales);
      if (nextScore.score < bestSession.score) {
        bestSession = nextScore;
        state = newState;
        if (kDebugMode) {
          print('Best score: ${bestSession.score} at $i');
        }
      }
    }
    if (kDebugMode) {
      print('Best score: ${bestSession.score}');
    }
    return bestSession;
  }

  SessionScore _calculateScore(
      List<MatchType> matchTypes,
      List<PlayerWithStats> availableMales,
      List<PlayerWithStats> availableFemales) {
    double score = 0;
    final bestGames = <Game>[];
    int menOffset = 0;
    int womenOffset = 0;
    for (var type in matchTypes) {
      switch (type) {
        case MatchType.menDoubles:
          int menCount = 4;
          final selectedMales =
              availableMales.skip(menOffset).take(menCount).toList();
          final gameScore =
              gameEvaluator.getBestGameForFour(type, selectedMales);
          score += gameScore.score;
          bestGames.add(gameScore.game);
          menOffset += menCount;
          break;

        case MatchType.womenDoubles:
          int womenCount = 4;
          final selectedFemales =
              availableFemales.skip(womenOffset).take(womenCount).toList();
          final gameScore =
              gameEvaluator.getBestGameForFour(type, selectedFemales);
          score += gameScore.score;
          bestGames.add(gameScore.game);

          womenOffset += womenCount;
          break;

        case MatchType.mixedDoubles:
          int menCount = 2;
          int womenCount = 2;

          final selectedMales =
              availableMales.skip(menOffset).take(menCount).toList();
          final selectedFemales =
              availableFemales.skip(womenOffset).take(womenCount).toList();

          final gameScore = gameEvaluator.getBestMixedGame(
              type, selectedMales, selectedFemales);

          score += gameScore.score;
          bestGames.add(gameScore.game);

          menOffset += menCount;
          womenOffset += womenCount;
          break;
      }
    }
    return SessionScore(score, bestGames);
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

  factory AlgorithmsState.initial(
      {required List<PlayerWithStats> mustMales,
      required List<PlayerWithStats> candidateMales,
      required int requiredMale,
      required List<PlayerWithStats> mustFemales,
      required List<PlayerWithStats> candidateFemales,
      required int requiredFemale}) {
    final selectedMales = PlayerSelectorUtil.pickCourtMembers(
        mustMales, candidateMales, requiredMale);
    final selectedMaleSet = selectedMales.toSet();
    List<PlayerWithStats> benchMales =
        candidateMales.where((p) => !selectedMaleSet.contains(p)).toList();
    final selectedFemales = PlayerSelectorUtil.pickCourtMembers(
        mustFemales, candidateFemales, requiredFemale);
    final selectedFemaleSet = selectedFemales.toSet();
    List<PlayerWithStats> benchFemales =
        candidateFemales.where((p) => !selectedFemaleSet.contains(p)).toList();

    return AlgorithmsState(
        selectedMales: selectedMales,
        benchMales: benchMales,
        candidateMales: candidateMales,
        selectedFemales: selectedFemales,
        benchFemales: benchFemales,
        candidateFemales: candidateFemales);
  }

  AlgorithmsState copyWithSwap() {
    final random = Random();
    final isMale = random.nextBool();
    final benchSwapProb = 0.2;

    final canSwapBench =
        isMale ? benchMales.isNotEmpty : benchFemales.isNotEmpty;
    final isSwapToBench = random.nextDouble() < benchSwapProb;

    if (canSwapBench && isSwapToBench) {
      return _copyWithSwapBench(isMale);
    } else {
      return _copyWithSwapPosition(isMale);
    }
  }

  AlgorithmsState _copyWithSwapBench(bool isMale) {
    if (isMale) {
      var (newMales, newBenchMales) = _copyWithSwapBenchEachGender(
          selectedMales, benchMales, candidateMales);
      return AlgorithmsState(
        selectedMales: newMales,
        benchMales: newBenchMales,
        candidateMales: candidateMales,
        selectedFemales: selectedFemales,
        benchFemales: benchFemales,
        candidateFemales: candidateFemales,
      );
    } else {
      var (newFemales, newBenchFemales) = _copyWithSwapBenchEachGender(
          selectedFemales, benchFemales, candidateFemales);
      return AlgorithmsState(
        selectedMales: selectedMales,
        benchMales: benchMales,
        candidateMales: candidateMales,
        selectedFemales: newFemales,
        benchFemales: newBenchFemales,
        candidateFemales: candidateFemales,
      );
    }
  }

  (List<PlayerWithStats>, List<PlayerWithStats>) _copyWithSwapBenchEachGender(
      List<PlayerWithStats> selectedPlayers,
      List<PlayerWithStats> benchPlayers,
      List<PlayerWithStats> candidatePlayers) {
    Random random = Random();
    final tempSelected = List<PlayerWithStats>.from(selectedPlayers);
    final tempBench = List<PlayerWithStats>.from(benchPlayers);

    final candidateSet = candidatePlayers.toSet();
    final indicesInSelected = [
      for (int i = 0; i < tempSelected.length; i++)
        if (candidateSet.contains(tempSelected[i])) i
    ];

    // RangeError対策：入れ替え可能な人がいない場合はそのまま返す
    if (indicesInSelected.isEmpty || tempBench.isEmpty) {
      return (tempSelected, tempBench);
    }

    final activeIdx =
        indicesInSelected[random.nextInt(indicesInSelected.length)];
    final benchIndex = random.nextInt(tempBench.length);

    final temp = tempSelected[activeIdx];
    tempSelected[activeIdx] = tempBench[benchIndex];
    tempBench[benchIndex] = temp;

    return (tempSelected, tempBench);
  }

  AlgorithmsState _copyWithSwapPosition(bool isMale) {
    if (isMale) {
      final newMales = _copyWithSwapPositionEachGender(selectedMales);
      return AlgorithmsState(
        selectedMales: newMales,
        benchMales: benchMales,
        candidateMales: candidateMales,
        selectedFemales: selectedFemales,
        benchFemales: benchFemales,
        candidateFemales: candidateFemales,
      );
    }
    final newFemales = _copyWithSwapPositionEachGender(selectedFemales);
    return AlgorithmsState(
      selectedMales: selectedMales,
      benchMales: benchMales,
      candidateMales: candidateMales,
      selectedFemales: newFemales,
      benchFemales: benchFemales,
      candidateFemales: candidateFemales,
    );
  }

  List<PlayerWithStats> _copyWithSwapPositionEachGender(
      List<PlayerWithStats> playerList) {
    // RangeError対策：2人以上いないと位置の入れ替えは不可
    if (playerList.length < 2) return playerList;

    final tempPlayerList = List<PlayerWithStats>.from(playerList);
    final random = Random();
    int index1 = random.nextInt(tempPlayerList.length);
    int index2;
    do {
      index2 = random.nextInt(tempPlayerList.length);
    } while (index1 == index2);

    PlayerWithStats temp = tempPlayerList[index1];
    tempPlayerList[index1] = tempPlayerList[index2];
    tempPlayerList[index2] = temp;

    return tempPlayerList;
  }
}
