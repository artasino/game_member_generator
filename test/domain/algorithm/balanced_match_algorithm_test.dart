import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/algorithm/balanced_match_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/best_force_court_assignment.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

void main() {
  late BalancedMatchAlgorithm algorithm;
  late GameEvaluator evaluator;

  setUp(() {
    evaluator = GameEvaluator();
    algorithm = BalancedMatchAlgorithm(
      gameEvaluator: evaluator,
      courtAssignmentAlgorithm:
          BestForceCourtAssignmentAlgorithm(gameEvaluator: evaluator),
    );
  });

  PlayerWithStats p(String id, Gender gender,
      {int matches = 0,
      int sessionsSinceLastRest = 0,
      String? excludedPartnerId,
      bool isMustRest = false}) {
    return PlayerWithStats(
      player: Player(
        id: id,
        name: 'Player $id',
        yomigana: 'p$id',
        gender: gender,
        excludedPartnerId: excludedPartnerId,
        isMustRest: isMustRest,
      ),
      stats: PlayerStats(
        totalMatches: matches,
        totalRests: 0,
        typeCounts: {},
        partnerCounts: {},
        opponentCounts: {},
        sessionsSinceLastRest: sessionsSinceLastRest,
      ),
    );
  }

  Map<int, PlayerStatsPool> toBuckets(List<PlayerWithStats> players) {
    final Map<int, List<PlayerWithStats>> groups = {};
    for (final p in players) {
      groups.putIfAbsent(p.stats.totalMatches, () => []).add(p);
    }
    return groups.map((k, v) => MapEntry(k, PlayerStatsPool(v)));
  }

  group('BalancedMatchAlgorithm', () {
    test('基本的なマッチ生成: 必要な人数が選出されること', () {
      final males = [
        p('m1', Gender.male),
        p('m2', Gender.male),
        p('m3', Gender.male),
        p('m4', Gender.male)
      ];
      final females = [
        p('f1', Gender.female),
        p('f2', Gender.female),
        p('f3', Gender.female),
        p('f4', Gender.female)
      ];

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.mixedDoubles, MatchType.mixedDoubles],
        maleBuckets: toBuckets(males),
        femaleBuckets: toBuckets(females),
      );

      expect(result.length, 2);
      final players = result
          .expand((g) => [
                g.teamA.player1.id,
                g.teamA.player2.id,
                g.teamB.player1.id,
                g.teamB.player2.id
              ])
          .toSet();
      expect(players.length, 8);
    });

    test('男子ダブルスと女子ダブルスの混在', () {
      final males = [
        p('m1', Gender.male),
        p('m2', Gender.male),
        p('m3', Gender.male),
        p('m4', Gender.male)
      ];
      final females = [
        p('f1', Gender.female),
        p('f2', Gender.female),
        p('f3', Gender.female),
        p('f4', Gender.female)
      ];

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.menDoubles, MatchType.womenDoubles],
        maleBuckets: toBuckets(males),
        femaleBuckets: toBuckets(females),
      );

      expect(result.length, 2);
      final menDoubles =
          result.firstWhere((g) => g.type == MatchType.menDoubles);
      final womenDoubles =
          result.firstWhere((g) => g.type == MatchType.womenDoubles);

      expect([
        menDoubles.teamA.player1.gender,
        menDoubles.teamA.player2.gender,
        menDoubles.teamB.player1.gender,
        menDoubles.teamB.player2.gender
      ], everyElement(Gender.male));
      expect([
        womenDoubles.teamA.player1.gender,
        womenDoubles.teamA.player2.gender,
        womenDoubles.teamB.player1.gender,
        womenDoubles.teamB.player2.gender
      ], everyElement(Gender.female));
    });

    test('出場回数が少ないプレイヤーが優先されること', () {
      // m5-m8は試合数0、m1-m4は試合数1
      final males = [
        p('m1', Gender.male, matches: 1),
        p('m2', Gender.male, matches: 1),
        p('m3', Gender.male, matches: 1),
        p('m4', Gender.male, matches: 1),
        p('m5', Gender.male, matches: 0),
        p('m6', Gender.male, matches: 0),
        p('m7', Gender.male, matches: 0),
        p('m8', Gender.male, matches: 0),
      ];
      final females = [
        p('f1', Gender.female),
        p('f2', Gender.female),
        p('f3', Gender.female),
        p('f4', Gender.female)
      ];

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.mixedDoubles], // 男子2名必要
        maleBuckets: toBuckets(males),
        femaleBuckets: toBuckets(females),
      );

      final selectedMaleIds = result
          .expand((g) => [
                g.teamA.player1,
                g.teamA.player2,
                g.teamB.player1,
                g.teamB.player2
              ])
          .where((pl) => pl.gender == Gender.male)
          .map((pl) => pl.id)
          .toSet();

      // 2名選ばれるはずで、その2名とも試合数0のグループから選ばれるべき
      expect(selectedMaleIds.length, 2);
      expect(selectedMaleIds, everyElement(anyOf('m5', 'm6', 'm7', 'm8')));
      expect(selectedMaleIds.intersection({'m1', 'm2', 'm3', 'm4'}), isEmpty);
    });

    test('isMustRestがtrueのプレイヤーは選出されないこと', () {
      final males = [
        p('m1', Gender.male, isMustRest: true),
        p('m2', Gender.male),
        p('m3', Gender.male),
        p('m4', Gender.male),
        p('m5', Gender.male)
      ];
      final females = [
        p('f1', Gender.female),
        p('f2', Gender.female),
        p('f3', Gender.female),
        p('f4', Gender.female)
      ];

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.menDoubles],
        maleBuckets: toBuckets(males),
        femaleBuckets: toBuckets(females),
      );

      final selectedIds = result
          .expand((g) => [
                g.teamA.player1.id,
                g.teamA.player2.id,
                g.teamB.player1.id,
                g.teamB.player2.id
              ])
          .toSet();
      expect(selectedIds, isNot(contains('m1')));
    });

    test('同時出場制限（excludedPartnerId）が解消され、補充されること', () {
      // m1とf1が同時出場制限ペア
      // m1のほうが sessionsSinceLastRest が大きいので、m1が削られる
      final m1 = p('m1', Gender.male,
          excludedPartnerId: 'f1', sessionsSinceLastRest: 2);
      final m2 = p('m2', Gender.male, sessionsSinceLastRest: 0);
      final m3 = p('m3', Gender.male, sessionsSinceLastRest: 0);

      // f1を確実に選ばせるために sessionsSinceLastRest を 0 にし、他の女子がいない状態にする
      final f1 = p('f1', Gender.female,
          excludedPartnerId: 'm1', sessionsSinceLastRest: 0);
      final f2 = p('f2', Gender.female, sessionsSinceLastRest: 0);

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.mixedDoubles], // 男女各2名必要
        maleBuckets: toBuckets([m1, m2, m3]),
        femaleBuckets: toBuckets([f1, f2]),
      );

      final selectedIds = result
          .expand((g) => [
                g.teamA.player1.id,
                g.teamA.player2.id,
                g.teamB.player1.id,
                g.teamB.player2.id
              ])
          .toSet();

      // m1とf1が同時に選ばれていないことを確認
      expect(selectedIds.contains('m1') && selectedIds.contains('f1'), isFalse);

      // m1が削られ、f1が選ばれているはず
      expect(selectedIds, isNot(contains('m1')));
      expect(selectedIds, contains('f1'));
    });

    test('制限ペアの優先度: 連続出場数が同じなら試合数が多い方を削る', () {
      // m1(試合数5)とf1(試合数2)が制限ペア。m1(5) > f1(2) なので m1 が削られるべき。
      final m1 = p('m1', Gender.male,
          excludedPartnerId: 'f1', sessionsSinceLastRest: 1, matches: 5);
      final m2 = p('m2', Gender.male, matches: 5);
      final m3 = p('m3', Gender.male, matches: 5); // 補充用

      // f1, f2を確実に選ばせるために matches: 0 にし、f3を matches: 1 にして選外にする
      final f1 = p('f1', Gender.female,
          excludedPartnerId: 'm1', sessionsSinceLastRest: 1, matches: 0);
      final f2 = p('f2', Gender.female, sessionsSinceLastRest: 1, matches: 0);
      final f3 =
          p('f3', Gender.female, sessionsSinceLastRest: 1, matches: 1); // 補充用

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.mixedDoubles], // 男女各2名必要
        maleBuckets: toBuckets([m1, m2, m3]),
        femaleBuckets: toBuckets([f1, f2, f3]),
      );

      final selectedIds = result
          .expand((g) => [
                g.teamA.player1.id,
                g.teamA.player2.id,
                g.teamB.player1.id,
                g.teamB.player2.id
              ])
          .toSet();

      // m1が削られ、f1が残ることを確認
      expect(selectedIds, isNot(contains('m1')));
      expect(selectedIds, contains('f1'));
      expect(selectedIds.length, 4); // 男女各2名選出されている
    });

    test('選外(unselected)からの補充が正しく機能すること', () {
      // 男子2名必要。m1, m2が初期選出。m1が制限で削られる。m3が補充されるべき。
      final m1 = p('m1', Gender.male,
          excludedPartnerId: 'f1', sessionsSinceLastRest: 10);
      final m2 = p('m2', Gender.male, matches: 0);
      final m3 = p('m3', Gender.male, matches: 1); // unselectedになるはず

      final f1 = p('f1', Gender.female,
          excludedPartnerId: 'm1', sessionsSinceLastRest: 1);
      final f2 = p('f2', Gender.female, sessionsSinceLastRest: 1);

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.mixedDoubles],
        maleBuckets: {
          0: PlayerStatsPool([m1, m2]),
          1: PlayerStatsPool([m3])
        },
        femaleBuckets: toBuckets([f1, f2]),
      );

      final selectedMaleIds = result
          .expand((g) => [
                g.teamA.player1,
                g.teamA.player2,
                g.teamB.player1,
                g.teamB.player2
              ])
          .where((pl) => pl.gender == Gender.male)
          .map((pl) => pl.id)
          .toSet();

      expect(selectedMaleIds, containsAll(['m2', 'm3']));
      expect(selectedMaleIds, isNot(contains('m1')));
    });

    test('人数が足りない場合に例外が発生するか(CourtAssignmentAlgorithm依存)', () {
      // 男子4人必要なのに3人しかいない場合
      final males = [
        p('m1', Gender.male),
        p('m2', Gender.male),
        p('m3', Gender.male)
      ];
      final females = [
        p('f1', Gender.female),
        p('f2', Gender.female),
        p('f3', Gender.female),
        p('f4', Gender.female)
      ];

      expect(
        () => algorithm.generateMatches(
          matchTypes: [MatchType.menDoubles],
          maleBuckets: toBuckets(males),
          femaleBuckets: toBuckets(females),
        ),
        throwsA(anyOf(isA<RangeError>(), isA<Exception>())),
      );
    });
    test('同じ優先度の補充候補が複数いる場合、ランダムに選ばれ人数がピッタリになること', () {
      // 男子2名必要。m1(制限で消える)、m2(確定)。補充候補にm3, m4。
      final m1 = p('m1', Gender.male,
          excludedPartnerId: 'f1', sessionsSinceLastRest: 10);
      final m2 = p('m2', Gender.male, matches: 0);
      // m3, m4 は同じ matches: 1 なので、どちらかが選ばれるはず
      final m3 = p('m3', Gender.male, matches: 1);
      final m4 = p('m4', Gender.male, matches: 1);

      final f1 = p('f1', Gender.female, excludedPartnerId: 'm1');
      final f2 = p('f2', Gender.female);

      final result = algorithm.generateMatches(
        matchTypes: [MatchType.mixedDoubles],
        maleBuckets: {
          0: PlayerStatsPool([m1, m2]),
          1: PlayerStatsPool([m3, m4])
        },
        femaleBuckets: toBuckets([f1, f2]),
      );

      final selectedMales = result
          .expand((g) => [
                g.teamA.player1,
                g.teamA.player2,
                g.teamB.player1,
                g.teamB.player2
              ])
          .where((pl) => pl.gender == Gender.male)
          .toList();

      // 人数が2名（m2 + [m3 or m4]）であることを確認
      expect(selectedMales.length, 2);
      expect(selectedMales.map((e) => e.id), contains('m2'));
      // m3かm4のいずれか一方が含まれている
      expect(
          selectedMales.map((e) => e.id).any((id) => id == 'm3' || id == 'm4'),
          isTrue);
    });
  });
}
