import 'match_type.dart';

/// プレイヤーの出場統計を保持するドメインエンティティ
class PlayerStats {
  /// 合計出場回数
  final int totalMatches;
  /// 種目別の出場回数
  final Map<MatchType, int> typeCounts;
  /// このプレイヤーが誰と何回ペア（味方）を組んだか (key: Player.id, value: 回数)
  final Map<String, int> partnerCounts;
  /// このプレイヤーが誰と何回対戦（敵）したか (key: Player.id, value: 回数)
  final Map<String, int> opponentCounts;
  /// 直近のセッションでお休みだったかどうか
  final bool restedLastTime;
  /// 最後にお休みしてから何試合経過したか (0なら直前がお休み)
  final int sessionsSinceLastRest;

  PlayerStats({
    required this.totalMatches,
    required this.typeCounts,
    required this.partnerCounts,
    required this.opponentCounts,
    this.restedLastTime = false,
    this.sessionsSinceLastRest = 0,
  });

  /// 指定した相手と同じコートにいた（味方または敵）合計回数を返す
  int getInteractionCount(String otherId) =>
      (partnerCounts[otherId] ?? 0) + (opponentCounts[otherId] ?? 0);
}
