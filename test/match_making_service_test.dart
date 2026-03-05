import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/algorithm/random_match_algorithm.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';
import 'package:game_member_generator/domain/services/match_making_service.dart';

// テスト用のモックリポジトリ（非同期対応）
class MockPlayerRepository implements PlayerRepository {
  List<Player> players = [];

  @override
  Future<List<Player>> getActive() async => players;

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

void main() {
  late MatchMakingService service;
  late MockPlayerRepository mockRepository;

  setUp(() {
    mockRepository = MockPlayerRepository();
    service = MatchMakingService(RandomMatchAlgorithm(), mockRepository);
  });

  group('MatchMakingService - 正常系', () {
    test('保存されているプレイヤーから試合が生成されること', () async {
      mockRepository.players = [
        const Player(id: '1', name: 'M1', yomigana: 'm1', gender: Gender.male),
        const Player(id: '2', name: 'M2', yomigana: 'm2', gender: Gender.male),
        const Player(id: '3', name: 'M3', yomigana: 'm3', gender: Gender.male),
        const Player(id: '4', name: 'M4', yomigana: 'm4', gender: Gender.male),
      ];

      final result = await service.generateMatches(
        matchTypes: [MatchType.menDoubles],
        playerStats: {}, // 新しい引数
      );

      expect(result.length, 1);
    });
  });
}
