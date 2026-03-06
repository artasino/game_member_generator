import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/entities/team.dart';
import 'package:game_member_generator/domain/repository/court_settings_repository.dart';
import 'package:game_member_generator/domain/repository/session_repository/session_history_repository.dart';
import 'package:game_member_generator/domain/services/match_making_service.dart';
import 'package:game_member_generator/presentation/notifiers/session_notifier.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';

// モッククラスの定義
class MockSessionHistoryRepository implements SessionHistoryRepository {
  List<Session> sessions = [];
  @override
  Future<List<Session>> getAll() async => sessions;
  @override
  Future<void> add(Session session) async => sessions.add(session);
  @override
  Future<void> update(Session session) async {
    final index = sessions.indexWhere((s) => s.index == session.index);
    if (index != -1) sessions[index] = session;
  }
  @override
  Future<void> clear() async => sessions.clear();
}

class MockCourtSettingsRepository implements CourtSettingsRepository {
  CourtSettings settings = CourtSettings([MatchType.menDoubles]);
  @override
  Future<CourtSettings> get() async => settings;
  @override
  Future<void> update(CourtSettings settings) async => this.settings = settings;
}

class MockPlayerRepository implements PlayerRepository {
  List<Player> players = [];
  @override
  Future<List<Player>> getActive() async => players.where((p) => p.isActive).toList();
  @override
  Future<List<Player>> getAll() async => players;
  @override
  Future<void> add(Player player) async => players.add(player);
  @override
  Future<void> remove(String id) async => players.removeWhere((p) => p.id == id);
  @override
  Future<void> update(Player player) async {
    final index = players.indexWhere((p) => p.id == player.id);
    if (index != -1) players[index] = player;
  }
}

class FixedMatchAlgorithm implements MatchAlgorithm {
  @override
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required Map<int, PlayerStatsPool> maleBuckets,
    required Map<int, PlayerStatsPool> femaleBuckets,
  }) {
    // 男女両方のバケットからプレイヤーを抽出して結合
    final males = maleBuckets.values.expand((pool) => pool.all).map((ps) => ps.player).toList();
    final females = femaleBuckets.values.expand((pool) => pool.all).map((ps) => ps.player).toList();
    final allPlayers = [...males, ...females];
    
    return [
      Game(
        MatchType.menDoubles,
        Team(allPlayers[0], allPlayers[1]),
        Team(allPlayers[2], allPlayers[3]),
      )
    ];
  }
}

void main() {
  late SessionNotifier notifier;
  late MockSessionHistoryRepository sessionRepo;
  late MockCourtSettingsRepository courtRepo;
  late MockPlayerRepository playerRepo;

  setUp(() {
    sessionRepo = MockSessionHistoryRepository();
    courtRepo = MockCourtSettingsRepository();
    playerRepo = MockPlayerRepository();
    final service = MatchMakingService(FixedMatchAlgorithm(), playerRepo);

    notifier = SessionNotifier(
      sessionRepository: sessionRepo,
      courtSettingsRepository: courtRepo,
      matchMakingService: service,
    );
  });

  group('SessionNotifier - 統計計算', () {
    test('試合履歴に基づいて正しく出場回数と詳細統計が計算されること', () async {
      final p1 = Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      final p2 = Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.male);
      final p3 = Player(id: '3', name: 'P3', yomigana: 'p3', gender: Gender.male);
      final p4 = Player(id: '4', name: 'P4', yomigana: 'p4', gender: Gender.male);
      playerRepo.players = [p1, p2, p3, p4];

      await notifier.generateSessionWithSettings(CourtSettings([MatchType.menDoubles]));

      final stats1 = notifier.playerStatsPool.all.firstWhere((p) => p.player.id == '1').stats;
      
      expect(stats1.totalMatches, 1);
      expect(stats1.partnerCounts['2'], 1);
      expect(stats1.opponentCounts['3'], 1);
      expect(stats1.opponentCounts['4'], 1);
    });
  });

  group('SessionNotifier - メンバー入れ替え', () {
    test('入れ替え後に詳細統計も再計算されること', () async {
      final p1 = Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      final p2 = Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.male);
      final p3 = Player(id: '3', name: 'P3', yomigana: 'p3', gender: Gender.male);
      final p4 = Player(id: '4', name: 'P4', yomigana: 'p4', gender: Gender.male);
      final p5 = Player(id: '5', name: 'P5', yomigana: 'p5', gender: Gender.male);
      playerRepo.players = [p1, p2, p3, p4, p5];

      await notifier.generateSessionWithSettings(CourtSettings([MatchType.menDoubles]));
      
      final session = notifier.sessions.first;
      // P1 と P5 を入れ替える
      final newGames = [
        Game(MatchType.menDoubles, Team(p5, p2), Team(p3, p4))
      ];
      await notifier.updateSession(session.copyWith(games: newGames, restingPlayers: [p1]));

      final pool = notifier.playerStatsPool;
      expect(pool.all.firstWhere((p) => p.player.id == '1').stats.totalMatches, 0);
      expect(pool.all.firstWhere((p) => p.player.id == '5').stats.totalMatches, 1);
    });
  });
}
