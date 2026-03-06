import 'player.dart';
import 'player_stats.dart';

/// プレイヤーとその統計情報を組み合わせたドメインエンティティ
class PlayerWithStats {
  final Player player;
  final PlayerStats stats;

  const PlayerWithStats({
    required this.player,
    required this.stats,
  });

  /// 試合数の少なさをベースにしたスコア（ソート用）
  int get totalMatches => stats.totalMatches;
}
