import 'dart:math';

import 'package:game_member_generator/config/app_config.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/session_score.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

import '../../entities/game.dart';

class StochasticCourtAssignmentAlgorithm implements CourtAssignmentAlgorithm {
  GameEvaluator gameEvaluator;

  StochasticCourtAssignmentAlgorithm({required this.gameEvaluator});

  @override
  SessionScore searchBestAssignment(
      {required List<MatchType> types,
      required List<PlayerWithStats> availableMales,
      required List<PlayerWithStats> availableFemales}) {
    Random random = Random();
    final loopCount = AppConfig.loopCount;
    availableMales.shuffle(random);
    availableFemales.shuffle(random);
    return _findBestSession(loopCount, types, availableMales, availableFemales);
  }

  SessionScore _findBestSession(
      int count,
      List<MatchType> types,
      List<PlayerWithStats> availableMales,
      List<PlayerWithStats> availableFemales) {
    // create first random session
    SessionScore bestSession =
        _calculateScore(types, availableMales, availableFemales);
    List<PlayerWithStats> nextMales;
    List<PlayerWithStats> nextFemales;
    for (int i = 0; i < count; i++) {
      (nextMales, nextFemales) =
          _swapRandomPlayers(availableMales, availableFemales);
      final nextScore = _calculateScore(types, nextMales, nextFemales);
      if (nextScore.score < bestSession.score) {
        bestSession = nextScore;
        availableMales = nextMales;
        availableFemales = nextFemales;
      }
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

  (List<PlayerWithStats>, List<PlayerWithStats>) _swapRandomPlayers(
      List<PlayerWithStats> availableMales,
      List<PlayerWithStats> availableFemales) {
    Random random = Random();
    bool isMale = random.nextBool();
    var tempMales = List<PlayerWithStats>.from(availableMales);
    var tempFemales = List<PlayerWithStats>.from(availableFemales);

    if (isMale) {
      int index1 = random.nextInt(tempMales.length);
      int index2;
      // index2 should not equal to index1
      do {
        index2 = random.nextInt(tempMales.length);
      } while (index1 == index2);
      PlayerWithStats temp = tempMales[index1];
      tempMales[index1] = tempMales[index2];
      tempMales[index2] = temp;
      return (tempMales, tempFemales);
    }
    int index1 = random.nextInt(tempFemales.length);
    int index2;
    // index2 should not equal to index1
    do {
      index2 = random.nextInt(tempMales.length);
    } while (index1 == index2);
    PlayerWithStats temp = tempFemales[index1];
    tempFemales[index1] = tempFemales[index2];
    tempFemales[index2] = temp;
    return (tempMales, tempFemales);
  }
}
