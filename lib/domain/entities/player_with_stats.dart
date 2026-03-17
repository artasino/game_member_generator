import 'gender.dart';
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

  String get id => player.id;

  String get name => player.name;

  Gender get gender => player.gender;

  bool get isActive => player.isActive;

  bool get isMustRest => player.isMustRest;

  String? get excludedPartnerId => player.excludedPartnerId;
}
