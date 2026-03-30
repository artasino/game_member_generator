import '../entities/gender.dart';
import '../entities/match_session_selection.dart';
import '../entities/match_type.dart';
import '../entities/player_stats_pool.dart';

/// 性別ごとの必要人数を保持するクラス
class RequiredPlayerCounts {
  final int male;
  final int female;

  const RequiredPlayerCounts({required this.male, required this.female});
}

/// 人数不足や同時出場制限などの判定結果を保持するクラス
class RequirementResult {
  final bool canGenerate;
  final String? errorMessage;
  final List<String> predictedRestPlayerNames;

  const RequirementResult(
    this.canGenerate,
    this.errorMessage, {
    this.predictedRestPlayerNames = const [],
  });
}

/// 試合生成の要件（人数、制限ペア）をチェックするドメインサービス
class MatchRequirementService {
  const MatchRequirementService();

  /// 指定されたマッチタイプとプレイヤープールに基づいて要件をチェックする
  RequirementResult check(List<MatchType> types, PlayerStatsPool pool) {
    final required = calculateRequiredCounts(types);
    final activeAvailable = _getActiveAvailablePool(pool);

    final activeMaleCount = activeAvailable.males.length;
    final activeFemaleCount = activeAvailable.females.length;

    // 1. 基本的な人数不足チェック
    final initialShortage = _buildShortageResult(
      requiredCounts: required,
      availableMale: activeMaleCount,
      availableFemale: activeFemaleCount,
      reasonPrefix: '',
    );
    if (initialShortage != null) return initialShortage;

    // 2. 同時出場制限（コンフリクト）の影響を評価
    final conflictImpact = _evaluateConflictImpact(
      requiredMale: required.male,
      requiredFemale: required.female,
      availablePool: activeAvailable,
    );

    final predictedRestNames = conflictImpact.predictedRestPlayerNames;

    // 3. コンフリクト考慮後の人数不足チェック
    final effectiveMaleCount =
        activeMaleCount - conflictImpact.removedMaleCount;
    final effectiveFemaleCount =
        activeFemaleCount - conflictImpact.removedFemaleCount;

    final conflictShortage = _buildShortageResult(
      requiredCounts: required,
      availableMale: effectiveMaleCount,
      availableFemale: effectiveFemaleCount,
      reasonPrefix: '同時出場制限により',
      predictedRestPlayerNames: predictedRestNames,
    );
    if (conflictShortage != null) return conflictShortage;

    // 4. コンフリクト解消不可チェック
    if (conflictImpact.hasUnresolvedConflict) {
      return RequirementResult(
        false,
        '同時出場制限を解消できない組み合わせです。コートタイプを変更してください。',
        predictedRestPlayerNames: predictedRestNames,
      );
    }

    return RequirementResult(
      true,
      null,
      predictedRestPlayerNames: predictedRestNames,
    );
  }

  /// 試合形式のリストから、必要な男女それぞれの人数を算出する
  RequiredPlayerCounts calculateRequiredCounts(List<MatchType> types) {
    var male = 0;
    var female = 0;
    for (final type in types) {
      switch (type) {
        case MatchType.menDoubles:
          male += 4;
          break;
        case MatchType.womenDoubles:
          female += 4;
          break;
        case MatchType.mixedDoubles:
          male += 2;
          female += 2;
          break;
      }
    }
    return RequiredPlayerCounts(male: male, female: female);
  }

  PlayerStatsPool _getActiveAvailablePool(PlayerStatsPool pool) {
    return PlayerStatsPool(
      pool.all
          .where((p) => p.player.isActive && !p.player.isMustRest)
          .toList(growable: false),
    );
  }

  RequirementResult? _buildShortageResult({
    required RequiredPlayerCounts requiredCounts,
    required int availableMale,
    required int availableFemale,
    required String reasonPrefix,
    List<String> predictedRestPlayerNames = const [],
  }) {
    final missingMale = requiredCounts.male - availableMale;
    final missingFemale = requiredCounts.female - availableFemale;

    if (missingMale <= 0 && missingFemale <= 0) return null;

    final shortagePrefix = reasonPrefix.isEmpty ? '' : '$reasonPrefix';
    String message;
    if (missingMale > 0 && missingFemale > 0) {
      final suffix = reasonPrefix.isEmpty ? '足りません' : '不足します';
      message =
          '$shortagePrefix男女ともに人数が$suffix (男:$missingMale人, 女:$missingFemale人不足)';
    } else if (missingMale > 0) {
      message = '$shortagePrefix男性が足りません ($missingMale人不足)';
    } else {
      message = '$shortagePrefix女性が足りません ($missingFemale人不足)';
    }

    return RequirementResult(
      false,
      message,
      predictedRestPlayerNames: predictedRestPlayerNames,
    );
  }

  _ConflictImpact _evaluateConflictImpact({
    required int requiredMale,
    required int requiredFemale,
    required PlayerStatsPool availablePool,
  }) {
    var session = MatchSessionSelection(
      male: availablePool.males.splitSelection(requiredMale),
      female: availablePool.females.splitSelection(requiredFemale),
    );

    int retryCount = 0;
    const int maxRetries = 5;
    final removedMaleIds = <String>{};
    final removedFemaleIds = <String>{};
    final predictedRestNames = <String>{};

    while (session.hasCrossGenderConflict && retryCount < maxRetries) {
      final maleMap = {for (final m in session.male.allCandidates) m.id: m};
      for (final female in session.female.allCandidates) {
        final partnerId = female.player.excludedPartnerId;
        if (partnerId == null) continue;
        final male = maleMap[partnerId];
        if (male == null || male.player.excludedPartnerId != female.id)
          continue;

        final bool fShouldRest = female.shouldRestOver(male);
        final removed = fShouldRest ? female : male;

        predictedRestNames.add(removed.name);
        if (removed.player.gender == Gender.male) {
          removedMaleIds.add(removed.id);
        } else {
          removedFemaleIds.add(removed.id);
        }
      }

      session = session.resolveConflicts();
      session = MatchSessionSelection(
        male: availablePool.males.refillSelection(session.male, requiredMale),
        female: availablePool.females
            .refillSelection(session.female, requiredFemale),
      );
      retryCount++;
    }

    return _ConflictImpact(
      removedMaleCount: removedMaleIds.length,
      removedFemaleCount: removedFemaleIds.length,
      hasUnresolvedConflict: session.hasCrossGenderConflict,
      predictedRestPlayerNames: predictedRestNames.toList(growable: false),
    );
  }
}

class _ConflictImpact {
  final int removedMaleCount;
  final int removedFemaleCount;
  final bool hasUnresolvedConflict;
  final List<String> predictedRestPlayerNames;

  const _ConflictImpact({
    required this.removedMaleCount,
    required this.removedFemaleCount,
    required this.hasUnresolvedConflict,
    required this.predictedRestPlayerNames,
  });
}
