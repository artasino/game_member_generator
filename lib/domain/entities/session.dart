import 'package:game_member_generator/domain/entities/game.dart';

class Session {
  final int index;
  final List<Game> games;

  Session(this.index, this.games);
}