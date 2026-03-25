import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/entities/team.dart';
import 'package:game_member_generator/domain/repository/court_settings_repository.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';
import 'package:game_member_generator/domain/repository/session_repository/session_history_repository.dart';
import 'package:game_member_generator/domain/services/match_making_service.dart';
import 'package:game_member_generator/presentation/notifiers/session_notifier.dart';

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
  Future<List<Player>> getActive() async =>
      players.where((p) => p.isActive).toList();

  @override
  Future<List<Player>> getAll() async => players;

  @override
  Future<void> add(Player player) async => players.add(player);

  @override
  Future<void> remove(String id) async =>
      players.removeWhere((p) => p.id == id);

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
    required PlayerStatsPool playerPool,
  }) {
    final allPlayers = playerPool.all.map((ps) => ps.player).toList();

    if (allPlayers.length < 4) return [];

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
      const p1 =
          Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      const p2 =
          Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.male);
      const p3 =
          Player(id: '3', name: 'P3', yomigana: 'p3', gender: Gender.male);
      const p4 =
          Player(id: '4', name: 'P4', yomigana: 'p4', gender: Gender.male);
      playerRepo.players = [p1, p2, p3, p4];

      // プレイヤーが追加されたことを通知して notifier 内部のキャッシュプールを更新する
      await notifier.onPlayersUpdated();

      await notifier
          .generateSessionWithSettings(CourtSettings([MatchType.menDoubles]));

      final stats1 = notifier.playerStatsPool.all
          .firstWhere((p) => p.player.id == '1')
          .stats;

      expect(stats1.totalMatches, 1);
      expect(stats1.partnerCounts['2'], 1);
      expect(stats1.opponentCounts['3'], 1);
      expect(stats1.opponentCounts['4'], 1);
    });

    test('指定セッション時点までの統計を取得できること', () async {
      const p1 =
          Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      const p2 =
          Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.male);
      const p3 =
          Player(id: '3', name: 'P3', yomigana: 'p3', gender: Gender.male);
      const p4 =
          Player(id: '4', name: 'P4', yomigana: 'p4', gender: Gender.male);
      const p5 =
          Player(id: '5', name: 'P5', yomigana: 'p5', gender: Gender.male);

      playerRepo.players = [p1, p2, p3, p4, p5];
      sessionRepo.sessions = [
        Session(
          1,
          [Game(MatchType.menDoubles, Team(p1, p3), Team(p2, p4))],
          restingPlayers: [p5],
        ),
        Session(
          2,
          [Game(MatchType.menDoubles, Team(p1, p2), Team(p3, p4))],
          restingPlayers: [p5],
        ),
      ];

      final service = MatchMakingService(FixedMatchAlgorithm(), playerRepo);
      final scopedNotifier = SessionNotifier(
        sessionRepository: sessionRepo,
        courtSettingsRepository: courtRepo,
        matchMakingService: service,
      );
      await Future<void>.delayed(Duration.zero);
      await scopedNotifier.onPlayersUpdated();

      final upTo1 = scopedNotifier.getPlayerStatsPoolUpToSession(1);
      final upTo2 = scopedNotifier.getPlayerStatsPoolUpToSession(2);

      final p1StatsUpTo1 =
          upTo1.all.firstWhere((p) => p.player.id == '1').stats;
      final p1StatsUpTo2 =
          upTo2.all.firstWhere((p) => p.player.id == '1').stats;
      final p5StatsUpTo1 =
          upTo1.all.firstWhere((p) => p.player.id == '5').stats;

      expect(p1StatsUpTo1.partnerCounts['2'], isNull);
      expect(p1StatsUpTo2.partnerCounts['2'], 1);
      expect(p5StatsUpTo1.restedLastTime, isTrue);
      expect(p5StatsUpTo1.sessionsSinceLastRest, 0);
    });
  });

  group('SessionNotifier - メンバー入れ替え', () {
    test('入れ替え後に詳細統計も再計算されること', () async {
      const p1 =
          Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      const p2 =
          Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.male);
      const p3 =
          Player(id: '3', name: 'P3', yomigana: 'p3', gender: Gender.male);
      const p4 =
          Player(id: '4', name: 'P4', yomigana: 'p4', gender: Gender.male);
      const p5 =
          Player(id: '5', name: 'P5', yomigana: 'p5', gender: Gender.male);
      playerRepo.players = [p1, p2, p3, p4, p5];

      await notifier.onPlayersUpdated();

      await notifier
          .generateSessionWithSettings(CourtSettings([MatchType.menDoubles]));

      final session = notifier.sessions.first;
      // P1 と P5 を入れ替える
      final newGames = [Game(MatchType.menDoubles, Team(p5, p2), Team(p3, p4))];
      await notifier.updateSession(
          session.copyWith(games: newGames, restingPlayers: [p1]));

      final pool = notifier.playerStatsPool;
      expect(
          pool.all.firstWhere((p) => p.player.id == '1').stats.totalMatches, 0);
      expect(
          pool.all.firstWhere((p) => p.player.id == '5').stats.totalMatches, 1);
    });
  });
}
