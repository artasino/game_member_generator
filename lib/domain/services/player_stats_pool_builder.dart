import '../entities/match_type.dart';
import '../entities/player.dart';
import '../entities/player_stats.dart';
import '../entities/player_stats_pool.dart';
import '../entities/player_with_stats.dart';
import '../entities/session.dart';

/// セッション履歴からプレイヤー統計プールを構築する
class PlayerStatsPoolBuilder {
  const PlayerStatsPoolBuilder();

  PlayerStatsPool build({
    required List<Player> allPlayers,
    required List<Session> sessions,
  }) {
    final Map<String, int> totals = {};
    final Map<String, int> rests = {};
    final Map<String, Map<MatchType, int>> typeBreakdowns = {};
    final Map<String, Map<String, int>> partnerBreakdowns = {};
    final Map<String, Map<String, int>> opponentBreakdowns = {};
    final Map<String, MatchType?> lastMatchTypes = {};

    for (final player in allPlayers) {
      final id = player.id;
      totals[id] = 0;
      rests[id] = 0;
      typeBreakdowns[id] = {};
      partnerBreakdowns[id] = {};
      opponentBreakdowns[id] = {};
      lastMatchTypes[id] = null;
    }

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
        if (foundType != null) break;
      }
      lastMatchTypes[player.id] = foundType;
    }

    for (final session in sessions) {
      for (final game in session.games) {
        final teamA = [game.teamA.player1, game.teamA.player2];
        final teamB = [game.teamB.player1, game.teamB.player2];

        void record(Player p, Player partner, List<Player> opponents) {
          final id = p.id;
          if (!typeBreakdowns.containsKey(id)) return;

          totals[id] = (totals[id] ?? 0) + 1;
          typeBreakdowns[id]![game.type] =
              (typeBreakdowns[id]![game.type] ?? 0) + 1;
          partnerBreakdowns[id]![partner.id] =
              (partnerBreakdowns[id]![partner.id] ?? 0) + 1;
          for (final opp in opponents) {
            opponentBreakdowns[id]![opp.id] =
                (opponentBreakdowns[id]![opp.id] ?? 0) + 1;
          }
        }

        record(teamA[0], teamA[1], teamB);
        record(teamA[1], teamA[0], teamB);
        record(teamB[0], teamB[1], teamA);
        record(teamB[1], teamB[0], teamA);
      }
      for (final rp in session.restingPlayers) {
        if (rests.containsKey(rp.id)) {
          rests[rp.id] = (rests[rp.id] ?? 0) + 1;
        }
      }
    }

    final sessionsSinceLastRest = _buildSessionsSinceLastRest(allPlayers, sessions);
    final consecutiveRests = _buildConsecutiveRests(allPlayers, sessions);

    final playerWithStatsList = allPlayers.map((p) {
      return PlayerWithStats(
        player: p,
        stats: PlayerStats(
          totalMatches: totals[p.id] ?? 0,
          totalRests: rests[p.id] ?? 0,
          typeCounts: typeBreakdowns[p.id] ?? {},
          partnerCounts: partnerBreakdowns[p.id] ?? {},
          opponentCounts: opponentBreakdowns[p.id] ?? {},
          restedLastTime: sessions.isNotEmpty &&
              sessions.last.restingPlayers.any((rp) => rp.id == p.id),
          sessionsSinceLastRest: sessionsSinceLastRest[p.id] ?? 0,
          consecutiveRests: consecutiveRests[p.id] ?? 0,
          lastMatchType: lastMatchTypes[p.id],
        ),
      );
    }).toList(growable: false);

    return PlayerStatsPool(playerWithStatsList);
  }

  Map<String, int> _buildSessionsSinceLastRest(
      List<Player> allPlayers, List<Session> sessions) {
    final Map<String, int> result = {};
    for (final player in allPlayers) {
      int count = 0;
      for (final session in sessions.reversed) {
        final rested = session.restingPlayers.any((p) => p.id == player.id);
        if (rested) break;
        count++;
      }
      result[player.id] = count;
    }
    return result;
  }

  Map<String, int> _buildConsecutiveRests(
      List<Player> allPlayers, List<Session> sessions) {
    final Map<String, int> result = {};
    for (final player in allPlayers) {
      int count = 0;
      for (final session in sessions.reversed) {
        final rested = session.restingPlayers.any((p) => p.id == player.id);
        if (!rested) break;
        count++;
      }
      result[player.id] = count;
    }
    return result;
  }
}
