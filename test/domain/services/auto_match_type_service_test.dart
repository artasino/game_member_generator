import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';
import 'package:game_member_generator/domain/services/auto_match_type_service.dart';

PlayerWithStats player(
  String id,
  Gender gender, {
  int played = 0,
  int streak = 0,
  bool oneRoundRest = false,
  bool departed = false,
  String? excluded,
}) =>
    PlayerWithStats(
      player: Player(
        id: id,
        name: id,
        yomigana: id,
        gender: gender,
        isMustRest: oneRoundRest,
        isEarlyDeparture: departed,
        excludedPartnerId: excluded,
      ),
      stats: PlayerStats(
        totalMatches: played,
        totalRests: streak,
        typeCounts: {},
        partnerCounts: {},
        opponentCounts: {},
        consecutiveRests: streak,
      ),
    );

void main() {
  const service = AutoMatchTypeService();
  final men = List.generate(4, (i) => player('m$i', Gender.male));

  test('balanced policy prefers fewer mixed courts when outcomes tie', () {
    final pool = PlayerStatsPool([
      ...men,
      for (var i = 0; i < 4; i++) player('f$i', Gender.female),
    ]);

    expect(
      service.recommend(pool, 2, AutoCourtPolicy.balance)?.matchTypes,
      unorderedEquals([MatchType.maleDoubles, MatchType.femaleDoubles]),
    );
    expect(
      service.recommend(pool, 2, AutoCourtPolicy.mix)?.matchTypes,
      [MatchType.mixedDoubles, MatchType.mixedDoubles],
    );
  });

  test('avoids a longer rest even when the average gap would increase', () {
    final pool = PlayerStatsPool([
      ...men,
      player('f0', Gender.female, played: 3, streak: 2),
      player('f1', Gender.female, played: 3),
    ]);

    final recommendation = service.recommend(pool, 1, AutoCourtPolicy.balance)!;
    final types = recommendation.matchTypes;
    expect(types, [MatchType.mixedDoubles]);
    expect(recommendation.playerIds, contains('f0'));
  });

  test('prevents one three-round rest even if two players rest twice', () {
    final pool = PlayerStatsPool([
      for (var i = 0; i < 4; i++) player('m$i', Gender.male, streak: 1),
      player('f0', Gender.female, played: 3, streak: 2),
      player('f1', Gender.female, played: 3),
    ]);

    // MD leaves one three-round rest. XD leaves two two-round rests.
    final recommendation = service.recommend(pool, 1, AutoCourtPolicy.balance)!;
    final types = recommendation.matchTypes;
    expect(types, [MatchType.mixedDoubles]);
    final ids = recommendation.playerIds;
    expect(ids, containsAll(['f0', 'f1']));
    expect(ids.intersection({'m0', 'm1', 'm2', 'm3'}), hasLength(2));
  });

  test('minimizes the number of rests when the longest streak is equal', () {
    final pool = PlayerStatsPool([
      for (var i = 0; i < 4; i++) player('m$i', Gender.male, streak: 1),
      player('f0', Gender.female, streak: 1),
      player('f1', Gender.female),
    ]);

    // Both formats leave a longest rest of two rounds. MD leaves one
    // such rest; XD leaves two despite having the smaller average gap.
    expect(service.recommend(pool, 1, AutoCourtPolicy.balance)?.matchTypes,
        [MatchType.maleDoubles]);
  });

  test('uses projected averages when the rest profiles are equal', () {
    final pool = PlayerStatsPool([
      ...men,
      player('f0', Gender.female, played: 3),
      player('f1', Gender.female, played: 3),
    ]);

    expect(service.recommend(pool, 1, AutoCourtPolicy.balance)?.matchTypes,
        [MatchType.maleDoubles]);
  });

  test('one-round rest counts in the average while departure does not', () {
    PlayerStatsPool pool({required bool departed}) => PlayerStatsPool([
          ...men,
          player('f0', Gender.female),
          player('f1', Gender.female),
          player('f2', Gender.female,
              played: 6, oneRoundRest: !departed, departed: departed),
        ]);

    final resting = pool(departed: false);
    final departed = pool(departed: true);
    expect(service.recommend(resting, 1, AutoCourtPolicy.balance)?.matchTypes,
        [MatchType.maleDoubles]);
    final recommendation =
        service.recommend(departed, 1, AutoCourtPolicy.balance)!;
    final types = recommendation.matchTypes;
    expect(types, [MatchType.mixedDoubles]);
    expect(recommendation.playerIds, isNot(contains('f2')));
    expect(service.evaluate(resting, [MatchType.mixedDoubles])?.playerIds,
        isNot(contains('f2')));
  });

  test('respects a one-way exclusion across courts and fills feasible courts',
      () {
    final pool = PlayerStatsPool([
      ...men,
      player('f0', Gender.female, streak: 2, excluded: 'm0'),
      player('f1', Gender.female),
      player('f2', Gender.female),
      player('f3', Gender.female),
      player('f4', Gender.female),
    ]);

    final recommendation = service.recommend(pool, 2, AutoCourtPolicy.mix)!;
    final types = recommendation.matchTypes;
    expect(types, [MatchType.mixedDoubles, MatchType.mixedDoubles]);
    final ids = recommendation.playerIds;
    expect(ids, hasLength(8));
    expect(ids, isNot(contains('f0')));
    expect(recommendation.restrictedRestPlayerNames, ['f0']);
  });

  test('uses flexible doubles to fill a court under the mixed policy', () {
    final pool = PlayerStatsPool([
      ...men,
      player('m4', Gender.male),
      player('m5', Gender.male),
      player('f0', Gender.female),
      player('f1', Gender.female),
    ]);

    final recommendation = service.recommend(pool, 2, AutoCourtPolicy.mix)!;
    final types = recommendation.matchTypes;
    expect(types, [MatchType.mixedDoubles, MatchType.fixedDoubles]);
    expect(
        recommendation.playerIds,
        unorderedEquals(
          ['m0', 'm1', 'm2', 'm3', 'm4', 'm5', 'f0', 'f1'],
        ));
  });

  test('uses assigned gender totals to compare flexible doubles', () {
    final pool = PlayerStatsPool([
      for (var i = 0; i < 3; i++) player('m$i', Gender.male),
      for (var i = 0; i < 3; i++) player('f$i', Gender.female, played: 3),
    ]);

    final recommendation =
        service.recommend(pool, 1, AutoCourtPolicy.genderSeparated)!;
    final types = recommendation.matchTypes;
    expect(types, [MatchType.fixedDoubles]);
    final ids = recommendation.playerIds;
    expect(ids, hasLength(4));
    expect(ids, containsAll(['m0', 'm1', 'm2']));
  });

  test('reports projected averages and rest streaks for the chosen IDs', () {
    final pool = PlayerStatsPool([
      for (var i = 0; i < 4; i++) player('m$i', Gender.male, streak: 1),
      player('f0', Gender.female, played: 3, streak: 2),
      player('f1', Gender.female, played: 3),
      player('f2', Gender.female, played: 3, oneRoundRest: true, streak: 4),
      player('f3', Gender.female, played: 10, departed: true),
    ]);

    final result = service.recommend(pool, 1, AutoCourtPolicy.balance)!;
    expect(result.matchTypes, [MatchType.mixedDoubles]);
    expect(result.playerIds, containsAll(['f0', 'f1']));
    expect(result.consecutiveRestStreaks, [2, 2]);
    expect(result.maleCount, 4);
    expect(result.femaleCount, 3);
    expect(result.projectedMaleAverage, 0.5);
    expect(result.projectedFemaleAverage, closeTo(11 / 3, 1e-9));
    expect(result.projectedAverageGap, closeTo(11 / 3 - 0.5, 1e-9));
  });

  test('returns no recommendation when a restriction prevents a full court',
      () {
    final pool = PlayerStatsPool([
      player('m0', Gender.male, excluded: 'm1'),
      ...men.skip(1),
    ]);

    expect(service.recommend(pool, 1, AutoCourtPolicy.balance), isNull);
    expect(service.evaluate(pool, [MatchType.maleDoubles]), isNull);
  });
}
