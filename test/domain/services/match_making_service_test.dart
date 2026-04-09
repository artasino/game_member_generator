import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';
import 'package:game_member_generator/domain/entities/team.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';
import 'package:game_member_generator/domain/services/match_making_service.dart';

class RecordingAlgorithm implements MatchAlgorithm {
  List<String> receivedIds = [];

  @override
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerPool,
  }) {
    receivedIds = playerPool.all.map((p) => p.player.id).toList()..sort();

    final players = playerPool.all.map((p) => p.player).toList();
    return [
      Game(
        matchTypes.first,
        Team(players[0], players[1]),
        Team(players[2], players[3]),
      ),
    ];
  }
}

class FakePlayerRepository implements PlayerRepository {
  final List<Player> players;

  FakePlayerRepository(this.players);

  @override
  Future<void> add(Player player) async => players.add(player);

  @override
  Future<List<Player>> getActive() async =>
      players.where((p) => p.isActive).toList(growable: false);

  @override
  Future<List<Player>> getAll() async => List<Player>.from(players);

  @override
  Future<void> remove(String id) async => players.removeWhere((p) => p.id == id);

  @override
  Future<void> update(Player player) async {
    final i = players.indexWhere((p) => p.id == player.id);
    if (i != -1) {
      players[i] = player;
    }
  }
}

PlayerWithStats withStats(Player player) {
  return PlayerWithStats(
    player: player,
    stats: PlayerStats(
      totalMatches: 0,
      totalRests: 0,
      typeCounts: {},
      partnerCounts: {},
      opponentCounts: {},
    ),
  );
}

void main() {
  group('MatchMakingService', () {
    test('非アクティブを除外したプールで生成し、未出場のアクティブを休憩にする', () async {
      const p1 = Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      const p2 = Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.male);
      const p3 = Player(id: '3', name: 'P3', yomigana: 'p3', gender: Gender.male);
      const p4 = Player(id: '4', name: 'P4', yomigana: 'p4', gender: Gender.male);
      const p5 = Player(id: '5', name: 'P5', yomigana: 'p5', gender: Gender.male);
      const p6 = Player(
        id: '6',
        name: 'P6',
        yomigana: 'p6',
        gender: Gender.male,
        isActive: false,
      );

      final repository = FakePlayerRepository([p1, p2, p3, p4, p5, p6]);
      final algorithm = RecordingAlgorithm();
      final service = MatchMakingService(algorithm, repository);

      final playerStats = PlayerStatsPool([
        withStats(p1),
        withStats(p2),
        withStats(p3),
        withStats(p4),
        withStats(p5),
        withStats(p6),
      ]);

      final result = await service.generateMatchSession(
        matchTypes: [MatchType.menDoubles],
        playerStats: playerStats,
      );

      expect(algorithm.receivedIds, ['1', '2', '3', '4', '5']);
      expect(result.games, hasLength(1));
      expect(result.restingPlayers.map((p) => p.id), ['5']);
    });
  });
}
