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
    // RepositoryをDIしてサービスを初期化
    service = MatchMakingService(RandomMatchAlgorithm(), mockRepository);
  });

  group('MatchMakingService - 正常系', () {
    test('保存されているプレイヤーから男子ダブルスと女子ダブルスが生成されること', () async {
      // Given: リポジトリにプレイヤーが保存されている
      mockRepository.players = [
        const Player(id: '1', name: 'M1', yomigana: 'm1', gender: Gender.male),
        const Player(id: '2', name: 'M2', yomigana: 'm2', gender: Gender.male),
        const Player(id: '3', name: 'M3', yomigana: 'm3', gender: Gender.male),
        const Player(id: '4', name: 'M4', yomigana: 'm4', gender: Gender.male),
        const Player(id: '5', name: 'F1', yomigana: 'f1', gender: Gender.female),
        const Player(id: '6', name: 'F2', yomigana: 'f2', gender: Gender.female),
        const Player(id: '7', name: 'F3', yomigana: 'f3', gender: Gender.female),
        const Player(id: '8', name: 'F4', yomigana: 'f4', gender: Gender.female),
      ];

      // When: matchTypesのみを指定して実行
      final result = await service.generateMatches(
        matchTypes: [MatchType.menDoubles, MatchType.womenDoubles],
      );

      // Then
      expect(result.length, 2);
      expect(result.any((g) => g.type == MatchType.menDoubles), isTrue);
      expect(result.any((g) => g.type == MatchType.womenDoubles), isTrue);
    });

    test('保存されているプレイヤーから混合ダブルスが生成されること', () async {
      mockRepository.players = [
        const Player(id: '1', name: 'M1', yomigana: 'm1', gender: Gender.male),
        const Player(id: '2', name: 'M2', yomigana: 'm2', gender: Gender.male),
        const Player(id: '3', name: 'F1', yomigana: 'f1', gender: Gender.female),
        const Player(id: '4', name: 'F2', yomigana: 'f2', gender: Gender.female),
      ];

      final result = await service.generateMatches(
        matchTypes: [MatchType.mixedDoubles],
      );

      expect(result.length, 1);
      expect(result.first.type, MatchType.mixedDoubles);
    });
  });

  group('MatchMakingService - 異常系', () {
    test('リポジトリの男性プレイヤーが不足している場合、例外を投げること', () async {
      mockRepository.players = [
        const Player(id: '1', name: 'M1', yomigana: 'm1', gender: Gender.male),
        const Player(id: '2', name: 'M2', yomigana: 'm2', gender: Gender.male),
        const Player(id: '3', name: 'M3', yomigana: 'm3', gender: Gender.male),
        const Player(id: '4', name: 'F1', yomigana: 'f1', gender: Gender.female),
      ];

      expect(
        () async => await service.generateMatches(matchTypes: [MatchType.menDoubles]),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Not enough male players'))),
      );
    });

    test('リポジトリが空の場合、例外を投げること', () async {
      mockRepository.players = [];

      expect(
        () async => await service.generateMatches(matchTypes: [MatchType.menDoubles]),
        throwsA(isA<Exception>()),
      );
    });
  });
}
