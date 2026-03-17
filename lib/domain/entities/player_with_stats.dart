import 'package:equatable/equatable.dart';

import 'player.dart';
import 'player_stats.dart';

/// プレイヤーとその統計情報をセットで保持するエンティティ
class PlayerWithStats extends Equatable {
  final Player player;
  final PlayerStats stats;

  const PlayerWithStats({
    required this.player,
    required this.stats,
  });

  String get id => player.id;
  String get name => player.name;

  bool get mustRest => player.isMustRest;

  /// 他のプレイヤーと比較して、自分の方が「お休み（Rest）」すべき優先度が高いか判定する
  /// アルゴリズムの制限ペア解消などで使用される
  bool shouldRestOver(PlayerWithStats other) {
    // 1. 連続出場数（sessionsSinceLastRest）が多い方を優先的に休ませる
    if (stats.sessionsSinceLastRest != other.stats.sessionsSinceLastRest) {
      return stats.sessionsSinceLastRest > other.stats.sessionsSinceLastRest;
    }
    // 2. 累計試合数が多い方を優先的に休ませる
    if (stats.totalMatches != other.stats.totalMatches) {
      return stats.totalMatches > other.stats.totalMatches;
    }
    // 3. 同条件なら決定論的なランダム（IDのハッシュ）で判定
    return id.hashCode > other.id.hashCode;
  }

  @override
  List<Object?> get props => [player, stats];
}
