import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/entities/team.dart';
import 'package:game_member_generator/domain/services/player_stats_calculator.dart';

void main() {
  group('PlayerStatsCalculator', () {
    const p1 = Player(id: 'p1', name: 'P1', yomigana: 'p1', gender: Gender.male);
    const p2 = Player(id: 'p2', name: 'P2', yomigana: 'p2', gender: Gender.male);
    const p3 = Player(id: 'p3', name: 'P3', yomigana: 'p3', gender: Gender.male);
    const p4 = Player(id: 'p4', name: 'P4', yomigana: 'p4', gender: Gender.male);
    const p5 = Player(id: 'p5', name: 'P5', yomigana: 'p5', gender: Gender.male);

    final players = [p1, p2, p3, p4, p5];

    final sessions = [
      Session(
        1,
        [Game(MatchType.menDoubles, Team(p1, p2), Team(p3, p4))],
        restingPlayers: [p5],
      ),
      Session(
        2,
        [Game(MatchType.menDoubles, Team(p2, p3), Team(p4, p5))],
        restingPlayers: [p1],
      ),
      Session(
        3,
        [Game(MatchType.menDoubles, Team(p2, p4), Team(p3, p5))],
        restingPlayers: [p1],
      ),
    ];

    test('休憩関連の統計値（restedLastTime / sessionsSinceLastRest / consecutiveRests）を計算できる', () {
      final calculator = PlayerStatsCalculator();
      final pool = calculator.buildPool(allPlayers: players, sessions: sessions);

      final p1Stats = pool.getPlayer('p1').stats;
      final p2Stats = pool.getPlayer('p2').stats;

      expect(p1Stats.restedLastTime, isTrue);
      expect(p1Stats.sessionsSinceLastRest, 0);
      expect(p1Stats.consecutiveRests, 2);

      expect(p2Stats.restedLastTime, isFalse);
      expect(p2Stats.sessionsSinceLastRest, 3);
      expect(p2Stats.consecutiveRests, 0);
    });

    test('試合種別・ペア・対戦相手の集計と lastMatchType を計算できる', () {
      final calculator = PlayerStatsCalculator();
      final pool = calculator.buildPool(allPlayers: players, sessions: sessions);

      final p2Stats = pool.getPlayer('p2').stats;

      expect(p2Stats.totalMatches, 3);
      expect(p2Stats.totalRests, 0);
      expect(p2Stats.typeCounts[MatchType.menDoubles], 3);

      // p2 のペア: s1でp1, s2でp3, s3でp4
      expect(p2Stats.partnerCounts['p1'], 1);
      expect(p2Stats.partnerCounts['p3'], 1);
      expect(p2Stats.partnerCounts['p4'], 1);

      // p2 は p3 と s1/s3 で2回対戦
      expect(p2Stats.opponentCounts['p3'], 2);
      expect(p2Stats.lastMatchType, MatchType.menDoubles);
    });
  });
}
