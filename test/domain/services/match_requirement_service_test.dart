import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';
import 'package:game_member_generator/domain/services/match_requirement_service.dart';

PlayerWithStats ps(
  String id,
  Gender gender, {
  String? excludedPartnerId,
  bool isActive = true,
  bool isMustRest = false,
  int totalMatches = 0,
  int sessionsSinceLastRest = 0,
}) {
  return PlayerWithStats(
    player: Player(
      id: id,
      name: id.toUpperCase(),
      yomigana: id,
      gender: gender,
      isActive: isActive,
      isMustRest: isMustRest,
      excludedPartnerId: excludedPartnerId,
    ),
    stats: PlayerStats(
      totalMatches: totalMatches,
      totalRests: 0,
      typeCounts: {},
      partnerCounts: {},
      opponentCounts: {},
      sessionsSinceLastRest: sessionsSinceLastRest,
    ),
  );
}

void main() {
  group('MatchRequirementService', () {
    const service = MatchRequirementService();

    test('calculateRequired は種目構成に応じて必要人数を合算できる', () {
      final counts = service.calculateRequired([
        MatchType.maleDoubles,
        MatchType.femaleDoubles,
        MatchType.mixedDoubles,
      ]);

      expect(counts.male, 6);
      expect(counts.female, 6);
    });

    test('check は inactive / isMustRest を除外して不足判定する', () {
      final pool = PlayerStatsPool([
        ps('m1', Gender.male),
        ps('m2', Gender.male, isActive: false),
        ps('m3', Gender.male, isMustRest: true),
        ps('m4', Gender.male),
      ]);

      final result = service.check([MatchType.maleDoubles], pool);

      expect(result.canGenerate, isFalse);
      expect(result.errorMessage, contains('男性が不足します'));
    });

    test('check は同時出場制限で補充不能な場合に生成不可を返す', () {
      final pool = PlayerStatsPool([
        ps('m1', Gender.male,
            excludedPartnerId: 'f1', sessionsSinceLastRest: 5),
        ps('m2', Gender.male),
        ps('f1', Gender.female,
            excludedPartnerId: 'm1', sessionsSinceLastRest: 0),
        ps('f2', Gender.female),
      ]);

      final result = service.check([MatchType.mixedDoubles], pool);

      expect(result.canGenerate, isFalse);
      expect(result.errorMessage, contains('同時出場制限'));
      expect(result.predictedRestPlayerNames, isNotEmpty);
    });

    test('calculateEffectiveCounts は双方向の同時出場制限ペアを実質人数から減算する', () {
      final pool = PlayerStatsPool([
        ps('m1', Gender.male, excludedPartnerId: 'f1', sessionsSinceLastRest: 2),
        ps('m2', Gender.male),
        ps('f1', Gender.female, excludedPartnerId: 'm1', sessionsSinceLastRest: 0),
        ps('f2', Gender.female),
      ]);

      final effective = service.calculateEffectiveCounts(pool);

      // m1-f1 の制限ペアでは m1 の休憩優先度が高いため、男性側が1人減る
      expect(effective.male, 1);
      expect(effective.female, 2);
    });
  });
}
