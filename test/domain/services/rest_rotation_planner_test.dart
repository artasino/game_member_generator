import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';
import 'package:game_member_generator/domain/services/rest_rotation_planner.dart';

Set<String> ids(int start, int count) => {
  for (var index = start; index < start + count; index++) 'p$index',
};

PlayerStatsPool pool(
  int count,
  List<Set<String>> history,
  Map<String, int> streaks,
) {
  return PlayerStatsPool(
    [
      for (final id in ids(0, count))
        PlayerWithStats(
          player: Player(id: id, name: id, yomigana: '', gender: Gender.male),
          stats: PlayerStats(
            totalMatches: history.where((round) => round.contains(id)).length,
            totalRests: 0,
            typeCounts: {},
            partnerCounts: {},
            opponentCounts: {},
            consecutiveRests: streaks[id] ?? 0,
          ),
        ),
    ],
    previousMaleSelections: history,
    previousFemaleSelections: [for (final _ in history) <String>{}],
  );
}

void main() {
  final planner = RestRotationPlanner();

  for (final courts in [1, 3]) {
    test('${courts * 8} players mix the rotation with one second rest', () {
      final slots = courts * 4;
      final first = ids(0, slots);
      final second = ids(slots, slots);
      final result = planner.plan(
        matchTypes: List.filled(courts, MatchType.maleDoubles),
        pool: pool(slots * 2, [first, second], {for (final id in first) id: 1}),
        baselineIds: first,
      );

      expect(result.normal, isNull);
      final alternative = result.exception!;
      expect(alternative.longestRest, 2);
      expect(alternative.consecutiveRestCount, 1);
      expect(alternative.playerIds.intersection(first), hasLength(slots - 1));
      expect(alternative.playerIds.intersection(second), hasLength(1));
    });
  }

  test('a three-group rotation can require a third consecutive rest', () {
    final first = ids(0, 4);
    final second = ids(4, 4);
    final third = ids(8, 4);
    final result = planner.plan(
      matchTypes: [MatchType.maleDoubles],
      pool: pool(
        12,
        [first, second, third],
        {for (final id in first) id: 2, for (final id in second) id: 1},
      ),
      baselineIds: first,
    );

    expect(result.normal, isNull);
    expect(result.exception?.longestRest, 3);
    expect(result.exception?.playerIds.intersection(first), hasLength(3));
  });

  test('an unseen group with the same rest profile needs no confirmation', () {
    final first = ids(0, 4);
    final second = ids(4, 3);
    final result = planner.plan(
      matchTypes: [MatchType.maleDoubles],
      pool: pool(
        7,
        [
          first,
          {...second, 'p0'},
        ],
        {
          for (final id in ['p1', 'p2', 'p3']) id: 1,
        },
      ),
      baselineIds: first,
    );

    expect(result.exception, isNull);
    expect(result.normal?.playerIds, containsAll(['p1', 'p2', 'p3']));
    expect(result.normal?.longestRest, 1);
  });
}
