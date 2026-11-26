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

  test('avoids a longer rest even when the average gap would increase', () {
    final pool = PlayerStatsPool([
      ...men,
      player('f0', Gender.female, played: 3, streak: 2),
      player('f1', Gender.female, played: 3),
    ]);

    final types = service.recommend(pool, 1, AutoCourtPolicy.balance);
    expect(types, [MatchType.mixedDoubles]);
    expect(service.selectPlayers(pool, types), contains('f0'));
  });

  test('uses projected averages when the rest profiles are equal', () {
    final pool = PlayerStatsPool([
      ...men,
      player('f0', Gender.female, played: 3),
      player('f1', Gender.female, played: 3),
    ]);

    expect(service.recommend(pool, 1, AutoCourtPolicy.balance),
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
    expect(service.recommend(resting, 1, AutoCourtPolicy.balance),
        [MatchType.maleDoubles]);
    final types = service.recommend(departed, 1, AutoCourtPolicy.balance);
    expect(types, [MatchType.mixedDoubles]);
    expect(service.selectPlayers(departed, types), isNot(contains('f2')));
    expect(service.selectPlayers(resting, [MatchType.mixedDoubles]),
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

    final types = service.recommend(pool, 2, AutoCourtPolicy.mix);
    expect(types, [MatchType.mixedDoubles, MatchType.mixedDoubles]);
    final ids = service.selectPlayers(pool, types)!;
    expect(ids, hasLength(8));
    expect(ids, isNot(contains('f0')));
  });
}
