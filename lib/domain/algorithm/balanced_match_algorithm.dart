import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats.dart';

class BalancedMatchAlgorithm implements MatchAlgorithm{
  @override
  List<Game> generateMatches({required List<Player> players, required List<MatchType> matchTypes, required Map<String, PlayerStats> playerStats}) {
    // TODO: implement generateMatches
    throw UnimplementedError();
  }

}