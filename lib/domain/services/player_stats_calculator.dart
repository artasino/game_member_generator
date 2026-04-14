import '../entities/gender.dart';
import '../entities/match_type.dart';
import '../entities/player.dart';
import '../entities/player_stats.dart';
import '../entities/player_stats_pool.dart';
import '../entities/player_with_stats.dart';
import '../entities/session.dart';

/// セッション履歴からプレイヤー統計を構築するドメインサービス
class PlayerStatsCalculator {
  PlayerStatsPool buildPool({
    required List<Player> allPlayers,
    required List<Session> sessions,
  }) {
    final accumulator = _StatsAccumulator.initialize(allPlayers);

    _collectLastMatchType(
      allPlayers: allPlayers,
      sessions: sessions,
      accumulator: accumulator,
    );

    for (final session in sessions) {
      _collectGameStats(session: session, accumulator: accumulator);
      _collectRestStats(session: session, accumulator: accumulator);
    }

    final sessionsSinceLastRest =
        _countSessionsSinceLastRest(allPlayers: allPlayers, sessions: sessions);
    final consecutiveRests =
        _countConsecutiveRests(allPlayers: allPlayers, sessions: sessions);

    final previousMaleSelections = sessions.map((session) {
      return session.games
          .expand((g) => [
                g.teamA.player1,
                g.teamA.player2,
                g.teamB.player1,
                g.teamB.player2
              ])
          .where((p) => p.gender == Gender.male)
          .map((p) => p.id)
          .toSet();
    }).toList();

    final previousFemaleSelections = sessions.map((session) {
      return session.games
          .expand((g) => [
                g.teamA.player1,
                g.teamA.player2,
                g.teamB.player1,
                g.teamB.player2
              ])
          .where((p) => p.gender == Gender.female)
          .map((p) => p.id)
          .toSet();
    }).toList();

    final stats = allPlayers
        .map(
          (player) => PlayerWithStats(
            player: player,
            stats: PlayerStats(
              totalMatches: accumulator.totalMatches[player.id] ?? 0,
              totalRests: accumulator.totalRests[player.id] ?? 0,
              typeCounts: accumulator.typeCounts[player.id] ?? {},
              partnerCounts: accumulator.partnerCounts[player.id] ?? {},
              opponentCounts: accumulator.opponentCounts[player.id] ?? {},
              restTogetherCounts:
                  accumulator.restTogetherCounts[player.id] ?? {},
              restedLastTime: sessions.isNotEmpty &&
                  sessions.last.restingPlayers.any((p) => p.id == player.id),
              sessionsSinceLastRest: sessionsSinceLastRest[player.id] ?? 0,
              consecutiveRests: consecutiveRests[player.id] ?? 0,
              lastMatchType: accumulator.lastMatchType[player.id],
            ),
          ),
        )
        .toList(growable: false);

    return PlayerStatsPool(
      stats,
      previousMaleSelections: previousMaleSelections,
      previousFemaleSelections: previousFemaleSelections,
    );
  }

  void _collectLastMatchType({
    required List<Player> allPlayers,
    required List<Session> sessions,
    required _StatsAccumulator accumulator,
  }) {
    for (final player in allPlayers) {
      MatchType? foundType;
      for (final session in sessions.reversed) {
        for (final game in session.games) {
          final isPlaying = game.teamA.player1.id == player.id ||
              game.teamA.player2.id == player.id ||
              game.teamB.player1.id == player.id ||
              game.teamB.player2.id == player.id;
          if (isPlaying) {
            foundType = game.type;
            break;
          }
        }
        if (foundType != null) {
          break;
        }
      }
      accumulator.lastMatchType[player.id] = foundType;
    }
  }

  void _collectGameStats({
    required Session session,
    required _StatsAccumulator accumulator,
  }) {
    for (final game in session.games) {
      final teamA = [game.teamA.player1, game.teamA.player2];
      final teamB = [game.teamB.player1, game.teamB.player2];

      _recordPlayerInGame(
        player: teamA[0],
        partner: teamA[1],
        opponents: teamB,
        type: game.type,
        accumulator: accumulator,
      );
      _recordPlayerInGame(
        player: teamA[1],
        partner: teamA[0],
        opponents: teamB,
        type: game.type,
        accumulator: accumulator,
      );
      _recordPlayerInGame(
        player: teamB[0],
        partner: teamB[1],
        opponents: teamA,
        type: game.type,
        accumulator: accumulator,
      );
      _recordPlayerInGame(
        player: teamB[1],
        partner: teamB[0],
        opponents: teamA,
        type: game.type,
        accumulator: accumulator,
      );
    }
  }

  void _recordPlayerInGame({
    required Player player,
    required Player partner,
    required List<Player> opponents,
    required MatchType type,
    required _StatsAccumulator accumulator,
  }) {
    final playerId = player.id;

    if (!accumulator.typeCounts.containsKey(playerId)) {
      return;
    }

    accumulator.totalMatches[playerId] =
        (accumulator.totalMatches[playerId] ?? 0) + 1;
    accumulator.typeCounts[playerId]![type] =
        (accumulator.typeCounts[playerId]![type] ?? 0) + 1;
    accumulator.partnerCounts[playerId]![partner.id] =
        (accumulator.partnerCounts[playerId]![partner.id] ?? 0) + 1;

    for (final opponent in opponents) {
      accumulator.opponentCounts[playerId]![opponent.id] =
          (accumulator.opponentCounts[playerId]![opponent.id] ?? 0) + 1;
    }
  }

  void _collectRestStats({
    required Session session,
    required _StatsAccumulator accumulator,
  }) {
    final restingPlayers = session.restingPlayers;
    for (int i = 0; i < restingPlayers.length; i++) {
      final p1 = restingPlayers[i];
      if (!accumulator.totalRests.containsKey(p1.id)) continue;

      accumulator.totalRests[p1.id] = (accumulator.totalRests[p1.id] ?? 0) + 1;

      for (int j = i + 1; j < restingPlayers.length; j++) {
        final p2 = restingPlayers[j];
        if (!accumulator.totalRests.containsKey(p2.id)) continue;

        accumulator.restTogetherCounts[p1.id]![p2.id] =
            (accumulator.restTogetherCounts[p1.id]![p2.id] ?? 0) + 1;
        accumulator.restTogetherCounts[p2.id]![p1.id] =
            (accumulator.restTogetherCounts[p2.id]![p1.id] ?? 0) + 1;
      }
    }
  }

  Map<String, int> _countSessionsSinceLastRest({
    required List<Player> allPlayers,
    required List<Session> sessions,
  }) {
    final result = <String, int>{};

    for (final player in allPlayers) {
      var count = 0;
      for (final session in sessions.reversed) {
        final rested = session.restingPlayers.any((p) => p.id == player.id);
        if (rested) {
          break;
        }
        count++;
      }
      result[player.id] = count;
    }

    return result;
  }

  Map<String, int> _countConsecutiveRests({
    required List<Player> allPlayers,
    required List<Session> sessions,
  }) {
    final result = <String, int>{};

    for (final player in allPlayers) {
      var count = 0;
      for (final session in sessions.reversed) {
        final rested = session.restingPlayers.any((p) => p.id == player.id);
        if (!rested) {
          break;
        }
        count++;
      }
      result[player.id] = count;
    }

    return result;
  }
}

class _StatsAccumulator {
  final Map<String, int> totalMatches;
  final Map<String, int> totalRests;
  final Map<String, Map<MatchType, int>> typeCounts;
  final Map<String, Map<String, int>> partnerCounts;
  final Map<String, Map<String, int>> opponentCounts;
  final Map<String, Map<String, int>> restTogetherCounts;
  final Map<String, MatchType?> lastMatchType;

  _StatsAccumulator({
    required this.totalMatches,
    required this.totalRests,
    required this.typeCounts,
    required this.partnerCounts,
    required this.opponentCounts,
    required this.restTogetherCounts,
    required this.lastMatchType,
  });

  factory _StatsAccumulator.initialize(List<Player> players) {
    final totalMatches = <String, int>{};
    final totalRests = <String, int>{};
    final typeCounts = <String, Map<MatchType, int>>{};
    final partnerCounts = <String, Map<String, int>>{};
    final opponentCounts = <String, Map<String, int>>{};
    final restTogetherCounts = <String, Map<String, int>>{};
    final lastMatchType = <String, MatchType?>{};

    for (final player in players) {
      totalMatches[player.id] = 0;
      totalRests[player.id] = 0;
      typeCounts[player.id] = {};
      partnerCounts[player.id] = {};
      opponentCounts[player.id] = {};
      restTogetherCounts[player.id] = {};
      lastMatchType[player.id] = null;
    }

    return _StatsAccumulator(
      totalMatches: totalMatches,
      totalRests: totalRests,
      typeCounts: typeCounts,
      partnerCounts: partnerCounts,
      opponentCounts: opponentCounts,
      restTogetherCounts: restTogetherCounts,
      lastMatchType: lastMatchType,
    );
  }
}
