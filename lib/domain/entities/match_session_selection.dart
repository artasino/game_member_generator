import 'package:collection/collection.dart';

import 'player_selection.dart';
import 'player_stats_pool.dart';

/// 1つのセッション（1回のマッチメイキング）における全プレイヤーの選抜状態
class MatchSessionSelection {
  final PlayerSelection male;
  final PlayerSelection female;

  // キャッシュ用のフィールド
  bool? _hasConflict;

  MatchSessionSelection({
    required this.male,
    required this.female,
  });

  /// 性別を跨いだ同時出場制限（Excluded Partner）のコンフリクトがあるか
  bool get hasCrossGenderConflict {
    if (_hasConflict != null) return _hasConflict!;

    final maleIds = male.allCandidateIds;
    for (var f in female.allCandidates) {
      final partnerId = f.player.excludedPartnerId;
      if (partnerId != null && maleIds.contains(partnerId)) {
        final m = male.allCandidates.firstWhereOrNull((p) => p.id == partnerId);
        if (m != null && m.player.excludedPartnerId == f.id) {
          _hasConflict = true;
          return true;
        }
      }
    }
    _hasConflict = false;
    return false;
  }

  /// コンフリクトを解消し、必要に応じて補充を行う。
  /// [maxRetries] 回まで試行する。
  MatchSessionSelection resolveAndRefill({
    required int requiredMale,
    required int requiredFemale,
    required PlayerStatsPool malePool,
    required PlayerStatsPool femalePool,
    int maxRetries = 5,
  }) {
    MatchSessionSelection current = this;
    int retryCount = 0;

    while (current.hasCrossGenderConflict && retryCount < maxRetries) {
      // 1. コンフリクトしているペアを見つけ、条件の悪い方を排除
      current = current.resolveConflicts();

      // 2. 排除によって不足した人数を元のプールから補充
      current = MatchSessionSelection(
        male: malePool.refillSelection(current.male, requiredMale),
        female: femalePool.refillSelection(current.female, requiredFemale),
      );

      retryCount++;
    }

    return current;
  }

  /// コンフリクトしているペアを見つけ、条件の悪い方を排除した新しい選抜状態を返す
  MatchSessionSelection resolveConflicts() {
    final Set<String> toRemoveIds = {};
    final maleMap = {for (var p in male.allCandidates) p.id: p};

    for (var f in female.allCandidates) {
      final partnerId = f.player.excludedPartnerId;
      if (partnerId == null) continue;

      final m = maleMap[partnerId];
      if (m != null && m.player.excludedPartnerId == f.id) {
        toRemoveIds.add(f.shouldRestOver(m) ? f.id : m.id);
      }
    }

    if (toRemoveIds.isEmpty) return this;

    return MatchSessionSelection(
      male: male.removePlayers(toRemoveIds),
      female: female.removePlayers(toRemoveIds),
    );
  }
}
