import 'game.dart';
import 'player.dart';

class Session {
  final int index;
  final List<Game> games;
  final List<Player> restingPlayers;

  Session(this.index, this.games, {this.restingPlayers = const []});

  Session copyWith(
      {int? index, List<Game>? games, List<Player>? restingPlayers}) {
    return Session(
      index ?? this.index,
      games ?? this.games,
      restingPlayers: restingPlayers ?? this.restingPlayers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'games': games.map((g) => g.toJson()).toList(),
      'restingPlayers': restingPlayers.map((p) => p.toJson()).toList(),
    };
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      json['index'] as int,
      (json['games'] as List)
          .map((g) => Game.fromJson(g as Map<String, dynamic>))
          .toList(),
      restingPlayers: (json['restingPlayers'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
