import 'player.dart';

class Team {
  final Player player1;
  final Player player2;

  const Team(this.player1, this.player2);

  bool containsPlayer(String id) => player1.id == id || player2.id == id;

  /// 与えられた2つのプレイヤーがチーム内にいれば入れ替える
  Team swapPlayers(Player p1, Player p2) {
    Player newP1 = player1;
    Player newP2 = player2;

    if (player1.id == p1.id) {
      newP1 = p2;
    } else if (player1.id == p2.id) {
      newP1 = p1;
    }

    if (player2.id == p1.id) {
      newP2 = p2;
    } else if (player2.id == p2.id) {
      newP2 = p1;
    }

    return copyWith(player1: newP1, player2: newP2);
  }

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
