import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import '../entities/game.dart';
import '../entities/match_type.dart';

/// マッチメイキングアルゴリズムのインターフェース
abstract class MatchAlgorithm {
  /// 試合数ごとにグループ化されたプレイヤー（バケット）に基づいて試合を生成する
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required Map<int, PlayerStatsPool> playerBuckets,
  });
}
