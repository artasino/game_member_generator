import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';

import '../algorithm/match_algorithm.dart';
import '../entities/game.dart';
import '../entities/match_type.dart';
import '../repository/player_repository/player_repository.dart';

class MatchGenerationResult {
  final List<Game> games;
  final List<Player> restingPlayers;

  MatchGenerationResult({
    required this.games,
    required this.restingPlayers,
  });
}

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
    final result = await generateMatchSession(
      matchTypes: matchTypes,
      playerStats: playerStats,
    );
    return result.games;
  }

  /// 試合生成と休憩プレイヤーの算出をまとめて実行する
  Future<MatchGenerationResult> generateMatchSession({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerStats,
  }) async {
    final activePlayers = await playerRepository.getActive();
    final activeIds = activePlayers.map((player) => player.id).toSet();
    final activePool = playerStats.filterByIds(activeIds);

    final games = algorithm.generateMatches(
      matchTypes: matchTypes,
      playerPool: activePool,
    );

    final playingPlayerIds = games
        .expand(
          (game) => [
            game.teamA.player1.id,
            game.teamA.player2.id,
            game.teamB.player1.id,
            game.teamB.player2.id,
          ],
        )
        .toSet();

    final restingPlayers = activePlayers
        .where((player) => !playingPlayerIds.contains(player.id))
        .toList(growable: false);

    return MatchGenerationResult(
      games: games,
      restingPlayers: restingPlayers,
    );
  }
}
