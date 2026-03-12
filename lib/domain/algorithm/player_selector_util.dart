import 'dart:math';

import '../entities/player_with_stats.dart';

class PlayerSelectorUtil {
  // pick court member from the player court count
  static List<PlayerWithStats> pickCourtMembers(
    List<PlayerWithStats> must,
    List<PlayerWithStats> candidates,
    int requiredCount,
  ) {
    final random = Random();
    final picked = List<PlayerWithStats>.from(must);
    final needed = requiredCount - picked.length;
    if (needed <= 0) return picked;

    final sortedCandidates = List<PlayerWithStats>.from(candidates);
    // 偏りを防ぐためにまずシャッフル
    sortedCandidates.shuffle(random);
    // 「前の休みからの試合間隔」が短い順（sessionsSinceLastRestが小さい＝直近で休んだ人）にソート
    sortedCandidates.sort((a, b) =>
        a.stats.sessionsSinceLastRest.compareTo(b.stats.sessionsSinceLastRest));

    picked.addAll(sortedCandidates.take(needed));
    return picked;
  }
}
