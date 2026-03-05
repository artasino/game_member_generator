import 'package:game_member_generator/presentation/notifiers/session_notifier.dart';

import '../algorithm/match_algorithm.dart';
import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/player_stats.dart';
import '../repository/player_repository/player_repository.dart';

/// 試合の組み合わせ（マッチメイキング）を担当するドメインサービス
class MatchMakingService {
  final MatchAlgorithm algorithm;
  final PlayerRepository playerRepository;

  MatchMakingService(this.algorithm, this.playerRepository);

  /// 指定されたマッチタイプとプレイヤー統計に基づいて試合を生成する
  Future<List<Game>> generateMatches({
    required List<MatchType> matchTypes,
    required Map<String, PlayerStats> playerStats,
  }) async {
    // 保存されている「アクティブな」プレイヤーを取得
    final players = await playerRepository.getActive();
    
    // アルゴリズムに統計データも渡して試合を生成
    return algorithm.generateMatches(
      players: players,
      matchTypes: matchTypes,
      playerStats: playerStats,
    );
  }
}
