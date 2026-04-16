import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/algorithm/balanced_match_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/best_force_court_assignment.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/services/player_stats_calculator.dart';

void main() {
  group('GameEvaluator rotation regression', () {
    test('12人男子で2コート/1コート交互: 同一8人固定と偶数巡固定メンバーを避ける', () {
      final players = _createMalePlayers(12);
      final algorithm = _createAlgorithm();
      final statsCalculator = PlayerStatsCalculator();
      final sessions = <Session>[];

      Set<String> playRound(List<MatchType> matchTypes) {
        final pool = statsCalculator.buildPool(allPlayers: players, sessions: sessions);
        final games = algorithm.generateMatches(matchTypes: matchTypes, playerPool: pool);
        final selected = _selectedIds(games);
        sessions.add(_toSession(index: sessions.length + 1, games: games, allPlayers: players));
        return selected;
      }

      final round1 = playRound([MatchType.maleDoubles, MatchType.maleDoubles]);
      expect(round1.length, 8);

      final round2 = playRound([MatchType.maleDoubles]);
      expect(round2.length, 4);
      expect(round2, equals(players.map((p) => p.id).toSet().difference(round1)));

      final round3 = playRound([MatchType.maleDoubles, MatchType.maleDoubles]);
      expect(round3.length, 8);
      expect(round3, isNot(equals(round1)));

      final round4 = playRound([MatchType.maleDoubles]);
      expect(round4.length, 4);
      expect(round4, equals(players.map((p) => p.id).toSet().difference(round3)));

      final round5 = playRound([MatchType.maleDoubles, MatchType.maleDoubles]);
      expect(round5.length, 8);
      expect(round5, isNot(equals(round1)));
      expect(round5, isNot(equals(round3)));

      final round6 = playRound([MatchType.maleDoubles]);
      expect(round6.length, 4);
      final evenIntersection3 = round2.intersection(round4).intersection(round6);
      expect(evenIntersection3.length, lessThanOrEqualTo(2),
          reason: '2,4,6巡目で同じ3人が3回連続選出されないこと');

      final round7 = playRound([MatchType.maleDoubles, MatchType.maleDoubles]);
      expect(round7.length, 8);
      expect(round7, isNot(equals(round1)));
      expect(round7, isNot(equals(round3)));
      expect(round7, isNot(equals(round5)));

      final round8 = playRound([MatchType.maleDoubles]);
      expect(round8.length, 4);
      final evenIntersection4 =
          round2.intersection(round4).intersection(round6).intersection(round8);
      expect(evenIntersection4.length, lessThanOrEqualTo(1),
          reason: '2,4,6,8巡目で同じ2人が4回連続選出されないこと');
    });

    test('9人男子で1コート→2コート→1コート: 誰も2連続休みにならない', () {
      final players = _createMalePlayers(9);
      final algorithm = _createAlgorithm();
      final statsCalculator = PlayerStatsCalculator();
      final sessions = <Session>[];

      Set<String> playRound(List<MatchType> matchTypes) {
        final pool = statsCalculator.buildPool(allPlayers: players, sessions: sessions);
        final games = algorithm.generateMatches(matchTypes: matchTypes, playerPool: pool);
        final selected = _selectedIds(games);
        sessions.add(_toSession(index: sessions.length + 1, games: games, allPlayers: players));
        return selected;
      }

      final round1 = playRound([MatchType.maleDoubles]);
      final round2 = playRound([MatchType.maleDoubles, MatchType.maleDoubles]);
      final round3 = playRound([MatchType.maleDoubles]);

      expect(round1.length, 4);
      expect(round2.length, 8);
      expect(round3.length, 4);

      final allIds = players.map((p) => p.id).toSet();
      final rest1 = allIds.difference(round1);
      final rest2 = allIds.difference(round2);
      final rest3 = allIds.difference(round3);

      expect(rest1.intersection(rest2), isEmpty,
          reason: '1巡目と2巡目で連続休みがいないこと');
      expect(rest2.intersection(rest3), isEmpty,
          reason: '2巡目と3巡目で連続休みがいないこと');
    });
  });
}

BalancedMatchAlgorithm _createAlgorithm() {
  final evaluator = GameEvaluator();
  return BalancedMatchAlgorithm(
    gameEvaluator: evaluator,
    courtAssignmentAlgorithm:
        BestForceCourtAssignmentAlgorithm(gameEvaluator: evaluator),
  );
}

List<Player> _createMalePlayers(int count) {
  return List.generate(
    count,
    (i) => Player(
      id: 'm${i + 1}',
      name: 'M${i + 1}',
      yomigana: 'm${i + 1}',
      gender: Gender.male,
    ),
    growable: false,
  );
}

Set<String> _selectedIds(List<Game> games) {
  return games
      .expand(
        (g) => [
          g.teamA.player1.id,
          g.teamA.player2.id,
          g.teamB.player1.id,
          g.teamB.player2.id,
        ],
      )
      .toSet();
}

Session _toSession({
  required int index,
  required List<Game> games,
  required List<Player> allPlayers,
}) {
  final selected = _selectedIds(games);
  final resting = allPlayers.where((p) => !selected.contains(p.id)).toList();
  return Session(index, games, restingPlayers: resting);
}
