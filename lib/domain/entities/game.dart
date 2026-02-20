import 'match_type.dart';
import 'team.dart';

class Game {
  final MatchType type;
  final Team teamA;
  final Team teamB;

  Game(this.type, this.teamA, this.teamB);
}