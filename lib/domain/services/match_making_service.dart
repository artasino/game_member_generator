import 'dart:developer' as dev;
import 'dart:isolate';

import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';

import '../algorithm/match_algorithm.dart';
import '../entities/game.dart';
import '../entities/match_type.dart';
import '../entities/player_stats.dart';
import '../entities/player_with_stats.dart';
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

    final matchDto = _MatchGenerationInputDto.fromDomain(
      matchTypes: matchTypes,
      playerStats: activePool,
    );

    final startAt = DateTime.now();
    final timelineTask = dev.TimelineTask();
    timelineTask.start(
      'matchmaking_search',
      arguments: {'startedAt': startAt.toIso8601String()},
    );
    dev.Timeline.instantSync(
      'matchmaking_search_start',
      arguments: {'startedAt': startAt.toIso8601String()},
    );

    late final List<_GameDto> gameDtos;
    try {
      gameDtos = await Isolate.run(
        () {
          final domainMatchTypes = matchDto.matchTypeIndexes
              .map((index) => MatchType.values[index])
              .toList(growable: false);

          final domainPool = matchDto.toDomainPool();
          final generatedGames = algorithm.generateMatches(
            matchTypes: domainMatchTypes,
            playerPool: domainPool,
          );

          return generatedGames
              .map((game) => _GameDto.fromDomain(game))
              .toList(growable: false);
        },
        debugName: 'matchmaking_search_isolate',
      );
    } finally {
      final endAt = DateTime.now();
      dev.Timeline.instantSync(
        'matchmaking_search_end',
        arguments: {'endedAt': endAt.toIso8601String()},
      );
      timelineTask.finish(arguments: {'endedAt': endAt.toIso8601String()});
    }

    final games = gameDtos.map((dto) => dto.toDomain()).toList(growable: false);

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

class _MatchGenerationInputDto {
  final List<int> matchTypeIndexes;
  final List<Map<String, Object?>> players;
  final List<List<String>> previousMaleSelections;
  final List<List<String>> previousFemaleSelections;

  const _MatchGenerationInputDto({
    required this.matchTypeIndexes,
    required this.players,
    required this.previousMaleSelections,
    required this.previousFemaleSelections,
  });

  factory _MatchGenerationInputDto.fromDomain({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerStats,
  }) {
    return _MatchGenerationInputDto(
      matchTypeIndexes: matchTypes.map((type) => type.index).toList(growable: false),
      players: playerStats.all
          .map(
            (playerWithStats) => {
              'player': playerWithStats.player.toJson(),
              'stats': _playerStatsToDto(playerWithStats.stats),
            },
          )
          .toList(growable: false),
      previousMaleSelections: playerStats.previousMaleSelections
          .map((selection) => selection.toList(growable: false))
          .toList(growable: false),
      previousFemaleSelections: playerStats.previousFemaleSelections
          .map((selection) => selection.toList(growable: false))
          .toList(growable: false),
    );
  }

  PlayerStatsPool toDomainPool() {
    return PlayerStatsPool(
      players
          .map(
            (entry) => PlayerWithStats(
              player: Player.fromJson(entry['player']! as Map<String, dynamic>),
              stats: _playerStatsFromDto(entry['stats']! as Map<String, Object?>),
            ),
          )
          .toList(growable: false),
      previousMaleSelections: previousMaleSelections
          .map((selection) => selection.toSet())
          .toList(growable: false),
      previousFemaleSelections: previousFemaleSelections
          .map((selection) => selection.toSet())
          .toList(growable: false),
    );
  }

  static Map<String, Object?> _playerStatsToDto(PlayerStats stats) {
    return {
      'totalMatches': stats.totalMatches,
      'totalRests': stats.totalRests,
      'typeCounts': {
        for (final entry in stats.typeCounts.entries) entry.key.index.toString(): entry.value,
      },
      'partnerCounts': stats.partnerCounts,
      'opponentCounts': stats.opponentCounts,
      'restTogetherCounts': stats.restTogetherCounts,
      'restedLastTime': stats.restedLastTime,
      'sessionsSinceLastRest': stats.sessionsSinceLastRest,
      'consecutiveRests': stats.consecutiveRests,
      'lastMatchType': stats.lastMatchType?.index,
    };
  }

  static PlayerStats _playerStatsFromDto(Map<String, Object?> dto) {
    final typeCountsDto = dto['typeCounts']! as Map<String, Object?>;
    return PlayerStats(
      totalMatches: dto['totalMatches']! as int,
      totalRests: dto['totalRests']! as int,
      typeCounts: {
        for (final entry in typeCountsDto.entries)
          MatchType.values[int.parse(entry.key)]: entry.value! as int,
      },
      partnerCounts: Map<String, int>.from(dto['partnerCounts']! as Map),
      opponentCounts: Map<String, int>.from(dto['opponentCounts']! as Map),
      restTogetherCounts: Map<String, int>.from(dto['restTogetherCounts']! as Map),
      restedLastTime: dto['restedLastTime']! as bool,
      sessionsSinceLastRest: dto['sessionsSinceLastRest']! as int,
      consecutiveRests: dto['consecutiveRests']! as int,
      lastMatchType: switch (dto['lastMatchType']) {
        final int index => MatchType.values[index],
        _ => null,
      },
    );
  }
}

class _GameDto {
  final int typeIndex;
  final Map<String, dynamic> teamA;
  final Map<String, dynamic> teamB;

  const _GameDto({
    required this.typeIndex,
    required this.teamA,
    required this.teamB,
  });

  factory _GameDto.fromDomain(Game game) {
    return _GameDto(
      typeIndex: game.type.index,
      teamA: game.teamA.toJson(),
      teamB: game.teamB.toJson(),
    );
  }

  Game toDomain() {
    return Game.fromJson({
      'type': typeIndex,
      'teamA': teamA,
      'teamB': teamB,
    });
  }
}
