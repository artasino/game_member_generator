import 'player.dart';

class Team {
  final Player player1;
  final Player player2;

  const Team(this.player1, this.player2);

  Team copyWith({Player? player1, Player? player2}) {
    return Team(player1 ?? this.player1, player2 ?? this.player2);
  }
}
