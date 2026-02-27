import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/entities/team.dart';

void main() {
  group('Entity JSON Serialization Tests', () {
    test('Player: toJson / fromJson roundtrip', () {
      final player = Player(
        id: 'p1',
        name: '山田 太郎',
        yomigana: 'やまだ たろう',
        gender: Gender.male,
        isActive: true,
      );

      final json = player.toJson();
      final recovered = Player.fromJson(json);

      expect(recovered.id, player.id);
      expect(recovered.name, player.name);
      expect(recovered.yomigana, player.yomigana);
      expect(recovered.gender, player.gender);
      expect(recovered.isActive, player.isActive);
    });

    test('Team: toJson / fromJson roundtrip', () {
      final p1 = Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      final p2 = Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.female);
      final team = Team(p1, p2);

      final json = team.toJson();
      final recovered = Team.fromJson(json);

      expect(recovered.player1.name, 'P1');
      expect(recovered.player2.gender, Gender.female);
    });

    test('Session: complex nested toJson / fromJson roundtrip', () {
      // 複雑なネスト構造を持つSessionデータを作成
      final p1 = Player(id: '1', name: 'P1', yomigana: 'p1', gender: Gender.male);
      final p2 = Player(id: '2', name: 'P2', yomigana: 'p2', gender: Gender.male);
      final p3 = Player(id: '3', name: 'P3', yomigana: 'p3', gender: Gender.male);
      final p4 = Player(id: '4', name: 'P4', yomigana: 'p4', gender: Gender.male);
      final pRest = Player(id: '5', name: 'Rest', yomigana: 'rest', gender: Gender.female);

      final game = Game(
        MatchType.menDoubles,
        Team(p1, p2),
        Team(p3, p4),
      );

      final session = Session(
        1,
        [game],
        restingPlayers: [pRest],
      );

      // 一旦JSON文字列に変換（デコード時の dynamic リスト問題をシミュレート）
      final jsonString = jsonEncode(session.toJson());
      final decodedMap = jsonDecode(jsonString) as Map<String, dynamic>;

      // 復元
      final recovered = Session.fromJson(decodedMap);

      expect(recovered.index, 1);
      expect(recovered.games.length, 1);
      expect(recovered.games.first.type, MatchType.menDoubles);
      expect(recovered.games.first.teamA.player1.name, 'P1');
      expect(recovered.games.first.teamB.player2.name, 'P4');
      expect(recovered.restingPlayers.first.name, 'Rest');
    });
  });
}
