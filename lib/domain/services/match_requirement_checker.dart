import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player_stats_pool.dart';

/// 試合形式に対して人数要件を満たしているか判定する結果
class RequirementResult {
  final bool canGenerate;
  final String? errorMessage;

  const RequirementResult(this.canGenerate, this.errorMessage);
}

/// 現在のプレイヤー構成で、指定された試合形式が成立するかを判定する
class MatchRequirementChecker {
  const MatchRequirementChecker();

  RequirementResult check({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerStatsPool,
  }) {
    int reqMale = 0;
    int reqFemale = 0;
    for (final type in matchTypes) {
      if (type == MatchType.menDoubles) {
        reqMale += 4;
      } else if (type == MatchType.womenDoubles) {
        reqFemale += 4;
      } else if (type == MatchType.mixedDoubles) {
        reqMale += 2;
        reqFemale += 2;
      }
    }

    final activeMales = playerStatsPool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.male)
        .length;
    final activeFemales = playerStatsPool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.female)
        .length;

    if (activeMales < reqMale && activeFemales < reqFemale) {
      return RequirementResult(false,
          '男女ともに人数が足りません (男:${reqMale - activeMales}人, 女:${reqFemale - activeFemales}人不足)');
    } else if (activeMales < reqMale) {
      return RequirementResult(false, '男性が足りません (${reqMale - activeMales}人不足)');
    } else if (activeFemales < reqFemale) {
      return RequirementResult(
          false, '女性が足りません (${reqFemale - activeFemales}人不足)');
    }

    return const RequirementResult(true, null);
  }
}
