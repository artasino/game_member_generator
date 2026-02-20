import 'dart:math';

import '../entities/game.dart';
import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player.dart';
import '../entities/team.dart';
import 'match_algorithm.dart';

class RandomMatchAlgorithm implements MatchAlgorithm {
  @override
  List<Game> generateMatches({
    required List<Player> players,
    required List<MatchType> matchTypes,
  }) {
    final random = Random();
    final males = <Player>[];
    final females = <Player>[];
    for (var player in players) {
      if (player.gender == Gender.male) {
        males.add(player);
      } else {
        females.add(player);
      }
    }
    males.shuffle(random);
    females.shuffle(random);
    final matches = <Game>[];
    for (final matchType in matchTypes) {
      switch (matchType) {
        case MatchType.menDoubles:
          if (males.length < 4) {
            throw Exception('Not enough male players to generate matches');
          }
          final teamA = Team(males.removeAt(0), males.removeAt(0));
          final teamB = Team(males.removeAt(0), males.removeAt(0));
          matches.add(Game(matchType, teamA, teamB));
          break;
        case MatchType.womenDoubles:
          if (females.length < 4) {
            throw Exception('Not enough female players to generate matches');
          }
          final teamA = Team(females.removeAt(0), females.removeAt(0));
          final teamB = Team(females.removeAt(0), females.removeAt(0));
          matches.add(Game(matchType, teamA, teamB));
          break;
        case MatchType.mixedDoubles:
          if (males.length < 2 || females.length < 2) {
            throw Exception('Not enough players to generate matches');
          }
          final teamA = Team(males.removeAt(0), females.removeAt(0));
          final teamB = Team(males.removeAt(0), females.removeAt(0));
          matches.add(Game(matchType, teamA, teamB));
          break;
      }
    }
    if (matchTypes.length != matches.length) {
      throw Exception('Not enough player for match types');
    }
    return matches;
  }
}
