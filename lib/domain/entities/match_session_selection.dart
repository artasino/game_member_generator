import 'package:collection/collection.dart';

import 'player_selection.dart';

/// 1つのセッション（1回のマッチメイキング）における全プレイヤーの選抜状態
class MatchSessionSelection {
  final PlayerSelection male;
  final PlayerSelection female;

  MatchSessionSelection({
    required this.male,
    required this.female,
  });

  /// 性別を跨いだ同時出場制限（Excluded Partner）のコンフリクトがあるか
  bool get hasCrossGenderConflict {
    final maleIds = male.allCandidates.map((p) => p.id).toSet();

    for (var f in female.allCandidates) {
      final partnerId = f.player.excludedPartnerId;
      if (partnerId != null && maleIds.contains(partnerId)) {
        // 相手側も制限しているか（双方向制限の確認）
        final m = male.allCandidates.firstWhereOrNull((p) => p.id == partnerId);
        if (m != null && m.player.excludedPartnerId == f.id) {
          return true;
        }
      }
    }
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
        // どちらを休ませるか
        final bool fShouldRest = f.shouldRestOver(m);
        final removeId = fShouldRest ? f.id : m.id;
        toRemoveIds.add(removeId);
      }
    }

    return MatchSessionSelection(
      male: male.removePlayers(toRemoveIds),
      female: female.removePlayers(toRemoveIds),
    );
  }
}
