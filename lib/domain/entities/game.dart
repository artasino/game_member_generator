import 'match_type.dart';
import 'team.dart';

class Game {
  final MatchType type;
  final Team teamA;
  final Team teamB;

  Game(this.type, this.teamA, this.teamB);

  Game copyWith({Team? teamA, Team? teamB}) {
    return Game(this.type, teamA ?? this.teamA, teamB ?? this.teamB);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'teamA': teamA.toJson(),
      'teamB': teamB.toJson(),
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      MatchType.values[json['type'] as int],
      Team.fromJson(json['teamA'] as Map<String, dynamic>),
      Team.fromJson(json['teamB'] as Map<String, dynamic>),
    );
  }
}
