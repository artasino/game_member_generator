import 'dart:developer' as dev;

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
  RequirementResult check(List<MatchType> types, PlayerStatsPool pool) {
    if (types.isEmpty) return RequirementResult.empty();

    // 1. 必要人数の算出
    final counts = calculateRequired(types);

    // 2. 有効プレイヤーの抽出 (Active かつ 休み希望でない)
    final available = PlayerStatsPool(
      pool.all.where((p) => p.player.isActive && !p.player.isMustRest).toList(),
    );

    // 3. 基本的な人数チェック
    if (available.males.length < counts.male ||
        available.females.length < counts.female) {
      return RequirementResult(
        canGenerate: false,
        errorMessage: _buildShortageMsg(counts.male - available.males.length,
            counts.female - available.females.length),
      );
    }

    // 4. 同時出場制限の解消シミュレーション
    final (restNames, resolvedSel) =
        _simulateConflictResolution(counts.male, counts.female, available);

    dev.log('--- 同時出場制限の解消シミュレーション結果 ---$restNames', name: 'MatchAlgo');

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
      if (t == MatchType.menDoubles) {
        m += 4;
      } else if (t == MatchType.womenDoubles)
        f += 4;
      else {
        m += 2;
        f += 2;
      }
    }
    return RequiredPlayerCounts(male: m, female: f);
  }

  /// 制限解消のシミュレーションを行い、選外となったプレイヤー名と最終的な選抜状態を返す
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
    final maleMap = {for (final m in sel.male.allCandidates) m.id: m};
    for (final f in sel.female.allCandidates) {
      final pId = f.player.excludedPartnerId;
      if (pId == null) continue;
      final m = maleMap[pId];
      if (m != null && m.player.excludedPartnerId == f.id) {
        names.add(f.shouldRestOver(m) ? f.name : m.name);
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

  const RequiredPlayerCounts({
    required this.male,
    required this.female,
  });
}
