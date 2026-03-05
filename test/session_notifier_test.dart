import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
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
    required List<Player> players,
    required List<MatchType> matchTypes,
    required Map<String, PlayerStats> playerStats, // 追加
  }) {
    return [
      Game(
        MatchType.menDoubles,
        Team(players[0], players[1]),
        Team(players[2], players[3]),
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

      // 合計回数
      expect(notifier.playerStats['1']?.totalMatches, 1);
      // 味方回数 (P1の味方はP2)
      expect(notifier.playerStats['1']?.partnerCounts['2'], 1);
      // 敵回数 (P1の敵はP3, P4)
      expect(notifier.playerStats['1']?.opponentCounts['3'], 1);
      expect(notifier.playerStats['1']?.opponentCounts['4'], 1);
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

      expect(notifier.playerStats['1']?.totalMatches, 0);
      expect(notifier.playerStats['5']?.totalMatches, 1);
      expect(notifier.playerStats['5']?.partnerCounts['2'], 1);
    });
  });
}
