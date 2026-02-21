import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/algorithm/random_match_algorithm.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/repository/player_repository.dart';
import 'package:game_member_generator/domain/services/match_making_service.dart';

// テスト用のモックリポジトリ
class MockPlayerRepository implements PlayerRepository {
  List<Player> players = [];

  @override
  List<Player> getActive() => players;

  @override
  List<Player> getAll() => players;

  @override
  void add(Player player) => players.add(player);

  @override
  void remove(String id) => players.removeWhere((p) => p.id == id);

  @override
  void update(Player player) {
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
    test('保存されているプレイヤーから男子ダブルスと女子ダブルスが生成されること', () {
      // Given: リポジトリにプレイヤーが保存されている
      mockRepository.players = [
        const Player(id: '1', name: 'M1', gender: Gender.male),
        const Player(id: '2', name: 'M2', gender: Gender.male),
        const Player(id: '3', name: 'M3', gender: Gender.male),
        const Player(id: '4', name: 'M4', gender: Gender.male),
        const Player(id: '5', name: 'F1', gender: Gender.female),
        const Player(id: '6', name: 'F2', gender: Gender.female),
        const Player(id: '7', name: 'F3', gender: Gender.female),
        const Player(id: '8', name: 'F4', gender: Gender.female),
      ];

      // When: matchTypesのみを指定して実行
      final result = service.generateMatches(
        matchTypes: [MatchType.menDoubles, MatchType.womenDoubles],
      );

      // Then
      expect(result.length, 2);
      expect(result.any((g) => g.type == MatchType.menDoubles), isTrue);
      expect(result.any((g) => g.type == MatchType.womenDoubles), isTrue);
    });

    test('保存されているプレイヤーから混合ダブルスが生成されること', () {
      mockRepository.players = [
        const Player(id: '1', name: 'M1', gender: Gender.male),
        const Player(id: '2', name: 'M2', gender: Gender.male),
        const Player(id: '3', name: 'F1', gender: Gender.female),
        const Player(id: '4', name: 'F2', gender: Gender.female),
      ];

      final result = service.generateMatches(
        matchTypes: [MatchType.mixedDoubles],
      );

      expect(result.length, 1);
      expect(result.first.type, MatchType.mixedDoubles);
    });
  });

  group('MatchMakingService - 異常系', () {
    test('リポジトリの男性プレイヤーが不足している場合、例外を投げること', () {
      mockRepository.players = [
        const Player(id: '1', name: 'M1', gender: Gender.male),
        const Player(id: '2', name: 'M2', gender: Gender.male),
        const Player(id: '3', name: 'M3', gender: Gender.male),
        const Player(id: '4', name: 'F1', gender: Gender.female),
      ];

      expect(
        () => service.generateMatches(matchTypes: [MatchType.menDoubles]),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Not enough male players'))),
      );
    });

    test('リポジトリが空の場合、例外を投げること', () {
      mockRepository.players = [];

      expect(
        () => service.generateMatches(matchTypes: [MatchType.menDoubles]),
        throwsA(isA<Exception>()),
      );
    });
  });
}
