import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/player_stats_pool.dart';

/// マッチメイキングアルゴリズムのインターフェース
abstract class MatchAlgorithm {
  /// 与えられたプレイヤー候補と試合形式に基づいて試合を生成する
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerPool,
  });
}
