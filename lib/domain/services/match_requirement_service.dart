import 'dart:developer' as dev;

import '../entities/gender.dart';
import '../entities/match_session_selection.dart';
import '../entities/match_type.dart';
import '../entities/player_stats_pool.dart';

/// 試合生成の要件判定結果
class RequirementResult {
  final bool canGenerate;
  final String? errorMessage;
  final List<String> predictedRestPlayerNames;

  const RequirementResult({
    required this.canGenerate,
    this.errorMessage,
    this.predictedRestPlayerNames = const [],
  });

  factory RequirementResult.empty() =>
      const RequirementResult(canGenerate: true);
}

/// 試合生成に必要な人数と同時出場制限をチェックするサービス
class MatchRequirementService {
  const MatchRequirementService();

  /// 指定された構成で判定を行う
  RequirementResult check(List<MatchType> types, PlayerStatsPool pool,
      {bool silent = false}) {
    if (types.isEmpty) return RequirementResult.empty();

    // 1. 必要人数の算出
    final counts = calculateRequired(types);

    // 2. 有効プレイヤーの抽出 (Active かつ 休み希望でない)
    final allAvailable = pool.all
        .where((p) => p.player.isActive && !p.player.isMustRest)
        .toList();
    final males =
        allAvailable.where((p) => p.player.gender == Gender.male).toList();
    final females =
        allAvailable.where((p) => p.player.gender == Gender.female).toList();

    // 3. 基本的な人数チェック
    if (males.length < counts.male || females.length < counts.female) {
      return RequirementResult(
        canGenerate: false,
        errorMessage: _buildShortageMsg(
            counts.male - males.length, counts.female - females.length),
      );
    }

    // 4. 同時出場制限の解消シミュレーション
    final availablePool = PlayerStatsPool(allAvailable);
    final (restNames, resolvedSel) =
        _simulateConflictResolution(counts.male, counts.female, availablePool);

    if (!silent) {
      dev.log('--- 同時出場制限の解消シミュレーション結果 ---$restNames', name: 'MatchAlgo');
    }

    // 5. 最終判定
    final shortageM = counts.male - resolvedSel.male.selectedCount;
    final shortageF = counts.female - resolvedSel.female.selectedCount;

    if (shortageM > 0 || shortageF > 0) {
      return RequirementResult(
        canGenerate: false,
        errorMessage:
            _buildShortageMsg(shortageM, shortageF, prefix: '同時出場制限により'),
        predictedRestPlayerNames: restNames,
      );
    }

    if (resolvedSel.hasCrossGenderConflict) {
      return RequirementResult(
        canGenerate: false,
        errorMessage: '同時出場制限を解消できない組み合わせです。',
        predictedRestPlayerNames: restNames,
      );
    }

    return RequirementResult(
      canGenerate: true,
      predictedRestPlayerNames: restNames,
    );
  }

  /// 必要人数を算出
  RequiredPlayerCounts calculateRequired(List<MatchType> types) {
    int m = 0, f = 0;
    for (final t in types) {
      if (t == MatchType.maleDoubles) {
        m += 4;
      } else if (t == MatchType.femaleDoubles) {
        f += 4;
      } else {
        m += 2;
        f += 2;
      }
    }
    return RequiredPlayerCounts(male: m, female: f);
  }

  /// 同時出場制限を考慮した「実質的な」有効人数を計算する
  EffectivePlayerCounts calculateEffectiveCounts(PlayerStatsPool pool) {
    final available = pool.all
        .where((p) => p.player.isActive && !p.player.isMustRest)
        .toList();

    final idMap = {for (final p in available) p.player.id: p};
    final Set<String> processedIds = {};
    final List<String> restrictedNames = [];

    int m = 0;
    int f = 0;

    for (final p in available) {
      if (processedIds.contains(p.player.id)) continue;

      final partnerId = p.player.excludedPartnerId;
      if (partnerId != null) {
        final partner = idMap[partnerId];
        if (partner != null &&
            partner.player.excludedPartnerId == p.player.id &&
            !processedIds.contains(partnerId)) {
          // 制限ペア：どちらか一方が休む
          final restPlayer = p.shouldRestOver(partner) ? p : partner;
          final stayPlayer = restPlayer == p ? partner : p;

          restrictedNames.add(restPlayer.name);

          if (stayPlayer.player.gender == Gender.male) {
            m++;
          } else {
            f++;
          }
          processedIds.add(p.player.id);
          processedIds.add(partner.player.id);
          continue;
        }
      }
      // 制限なし、または相手がいない/処理済み
      if (p.player.gender == Gender.male) {
        m++;
      } else {
        f++;
      }
      processedIds.add(p.player.id);
    }

    return EffectivePlayerCounts(
      male: m.toDouble(),
      female: f.toDouble(),
      restrictedPlayerNames: restrictedNames,
    );
  }

  /// 制限解消のシミュレーション
  (List<String> names, MatchSessionSelection finalSel)
      _simulateConflictResolution(int reqM, int reqF, PlayerStatsPool pool) {
    var sel = MatchSessionSelection(
      male: pool.males.splitSelection(reqM),
      female: pool.females.splitSelection(reqF),
    );

    final restedNames = <String>{};
    for (int i = 0; i < 5 && sel.hasCrossGenderConflict; i++) {
      _collectConflictNames(sel, restedNames);

      sel = sel.resolveConflicts();
      sel = MatchSessionSelection(
        male: pool.males.refillSelection(sel.male, reqM),
        female: pool.females.refillSelection(sel.female, reqF),
      );
    }
    return (restedNames.toList(), sel);
  }

  void _collectConflictNames(MatchSessionSelection sel, Set<String> names) {
    final maleIds = sel.male.allCandidateIds;
    for (final f in sel.female.allCandidates) {
      final pId = f.player.excludedPartnerId;
      if (pId != null && maleIds.contains(pId)) {
        final m = sel.male.allCandidates.firstWhere((p) => p.id == pId);
        if (m.player.excludedPartnerId == f.id) {
          names.add(f.shouldRestOver(m) ? f.name : m.name);
        }
      }
    }
  }

  String _buildShortageMsg(int m, int f, {String prefix = ''}) {
    final p = prefix.isNotEmpty ? '$prefix ' : '';
    if (m > 0 && f > 0) return '$p男女ともに人数が不足します (男:$m, 女:$f)';
    return '$p${m > 0 ? '男性' : '女性'}が不足します (${m > 0 ? m : f}人)';
  }
}

class RequiredPlayerCounts {
  final int male;
  final int female;

  const RequiredPlayerCounts({required this.male, required this.female});
}

class EffectivePlayerCounts {
  final double male;
  final double female;
  final List<String> restrictedPlayerNames;

  const EffectivePlayerCounts({
    required this.male,
    required this.female,
    this.restrictedPlayerNames = const [],
  });
}
