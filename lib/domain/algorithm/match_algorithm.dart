import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/player.dart';

abstract class MatchAlgorithm {
  List<Game> generateMatches({
    required List<Player> players,
    required List<MatchType> matchTypes,
});
}