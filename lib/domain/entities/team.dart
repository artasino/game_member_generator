import 'player.dart';

class Team {
  final Player player1;
  final Player player2;

  const Team(this.player1, this.player2);

  Team copyWith({Player? player1, Player? player2}) {
    return Team(player1 ?? this.player1, player2 ?? this.player2);
  }

  Map<String, dynamic> toJson() {
    return {
      'player1': player1.toJson(),
      'player2': player2.toJson(),
    };
  }

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      Player.fromJson(json['player1'] as Map<String, dynamic>),
      Player.fromJson(json['player2'] as Map<String, dynamic>),
    );
  }
}
