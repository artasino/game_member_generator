import 'package:collection/collection.dart';

import 'player_selection.dart';

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
