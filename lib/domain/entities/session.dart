import 'game.dart';
import 'player.dart';

class Session {
  final int index;
  final List<Game> games;
  final List<Player> restingPlayers;

  Session(this.index, this.games, {this.restingPlayers = const []});

  Session copyWith({int? index, List<Game>? games, List<Player>? restingPlayers}) {
    return Session(
      index ?? this.index,
      games ?? this.games,
      restingPlayers: restingPlayers ?? this.restingPlayers,
    );
  }
}
