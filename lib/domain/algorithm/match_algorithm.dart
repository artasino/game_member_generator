import 'package:game_member_generator/domain/entities/player_stats_pool.dart';

import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/player.dart';

/// マッチメイキングアルゴリズムのインターフェース
abstract class MatchAlgorithm {
  /// 指定されたプレイヤーと統計情報に基づいて試合を生成する
  List<Game> generateMatches({
    required List<Player> players,
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerStats,
  });
}
