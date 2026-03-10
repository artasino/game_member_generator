import '../entities/game.dart';

class SessionScore {
  final double score;
  final List<Game> games;

  SessionScore(this.score, this.games);
}

class GameScore {
  final double score;
  final Game game;

  GameScore(this.score, this.game);
}
