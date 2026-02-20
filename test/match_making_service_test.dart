import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/algorithm/random_match_algorithm.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/services/match_making_service.dart';

void main() {
  late MatchMakingService service;

  setUp(() {
    service = MatchMakingService(RandomMatchAlgorithm());
  });

  group('MatchMakingService - 正常系', () {
    test('男子ダブルスと女子ダブルスが正しく生成されること', () {
      final players = [
        const Player(id: '1', name: 'M1', gender: Gender.male),
        const Player(id: '2', name: 'M2', gender: Gender.male),
        const Player(id: '3', name: 'M3', gender: Gender.male),
        const Player(id: '4', name: 'M4', gender: Gender.male),
        const Player(id: '5', name: 'F1', gender: Gender.female),
        const Player(id: '6', name: 'F2', gender: Gender.female),
        const Player(id: '7', name: 'F3', gender: Gender.female),
        const Player(id: '8', name: 'F4', gender: Gender.female),
      ];
      final matchTypes = [MatchType.menDoubles, MatchType.womenDoubles];

      final result = service.generateMatches(
        players: players,
        matchTypes: matchTypes,
      );

      expect(result.length, 2);
      expect(result.any((g) => g.type == MatchType.menDoubles), isTrue);
      expect(result.any((g) => g.type == MatchType.womenDoubles), isTrue);
    });

    test('混合ダブルスが正しく生成されること', () {
      final players = [
        const Player(id: '1', name: 'M1', gender: Gender.male),
        const Player(id: '2', name: 'M2', gender: Gender.male),
        const Player(id: '3', name: 'F1', gender: Gender.female),
        const Player(id: '4', name: 'F2', gender: Gender.female),
      ];
      final matchTypes = [MatchType.mixedDoubles];

      final result = service.generateMatches(
        players: players,
        matchTypes: matchTypes,
      );

      expect(result.length, 1);
      expect(result.first.type, MatchType.mixedDoubles);
    });
  });

  group('MatchMakingService - 異常系', () {
    test('男子ダブルスを指定したが男性プレイヤーが4人未満の場合、例外を投げること', () {
      final players = [
        const Player(id: '1', name: 'M1', gender: Gender.male),
        const Player(id: '2', name: 'M2', gender: Gender.male),
        const Player(id: '3', name: 'M3', gender: Gender.male),
        const Player(id: '4', name: 'F1', gender: Gender.female), // 女性
      ];
      final matchTypes = [MatchType.menDoubles];

      expect(
        () => service.generateMatches(players: players, matchTypes: matchTypes),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Not enough male players'))),
      );
    });

    test('女子ダブルスを指定したが女性プレイヤーが4人未満の場合、例外を投げること', () {
      final players = [
        const Player(id: '1', name: 'F1', gender: Gender.female),
        const Player(id: '2', name: 'F2', gender: Gender.female),
        const Player(id: '3', name: 'F3', gender: Gender.female),
        const Player(id: '4', name: 'M1', gender: Gender.male), // 男性
      ];
      final matchTypes = [MatchType.womenDoubles];

      expect(
        () => service.generateMatches(players: players, matchTypes: matchTypes),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Not enough female players'))),
      );
    });

    test('混合ダブルスを指定したが男女各2名に満たない場合、例外を投げること', () {
      final players = [
        const Player(id: '1', name: 'M1', gender: Gender.male),
        const Player(id: '2', name: 'M2', gender: Gender.male),
        const Player(id: '3', name: 'M3', gender: Gender.male),
        const Player(id: '4', name: 'F1', gender: Gender.female), // 女性が1人しかいない
      ];
      final matchTypes = [MatchType.mixedDoubles];

      expect(
        () => service.generateMatches(players: players, matchTypes: matchTypes),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Not enough players'))),
      );
    });

    test('空のプレイヤーリストを渡した場合、例外を投げること', () {
      final players = <Player>[];
      final matchTypes = [MatchType.menDoubles];

      expect(
        () => service.generateMatches(players: players, matchTypes: matchTypes),
        throwsA(isA<Exception>()),
      );
    });
  });
}
