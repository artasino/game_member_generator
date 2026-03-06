import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import '../algorithm/match_algorithm.dart';
import '../entities/game.dart';
import '../entities/match_type.dart';
import '../repository/player_repository/player_repository.dart';

/// 試合の組み合わせ（マッチメイキング）を担当するドメインサービス
class MatchMakingService {
  final MatchAlgorithm algorithm;
  final PlayerRepository playerRepository;

  MatchMakingService(this.algorithm, this.playerRepository);

  /// 指定されたマッチタイプと統計プールに基づいて試合を生成する
  Future<List<Game>> generateMatches({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerStats,
  }) async {
    // 1. 保存されている「アクティブな」プレイヤーのIDを取得
    final activePlayers = await playerRepository.getActive();
    final activeIds = activePlayers.map((p) => p.id).toSet();
    
    // 2. アクティブなプレイヤーのみのプールを作成
    final activePool = PlayerStatsPool(
      playerStats.all.where((p) => activeIds.contains(p.player.id)).toList()
    );
    
    // 3. 男女別にプールを分け、それぞれのバケットを取得してアルゴリズムに渡す
    return algorithm.generateMatches(
      matchTypes: matchTypes,
      maleBuckets: activePool.males.buckets,
      femaleBuckets: activePool.females.buckets,
    );
  }
}
