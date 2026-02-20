import '../algorithm/match_algorithm.dart';
import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/player.dart';

class MatchMakingService {
  final MatchAlgorithm algorithm;

  MatchMakingService(this.algorithm);

  List<Game> generateMatches({
    required List<Player> players,
    required List<MatchType> matchTypes,
  }) {
    return algorithm.generateMatches(players: players, matchTypes: matchTypes);
  }
}