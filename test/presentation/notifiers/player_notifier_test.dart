import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/gender.dart';
import 'package:game_member_generator/domain/entities/player.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';
import 'package:game_member_generator/presentation/notifiers/player_notifier.dart';

class MockPlayerRepository implements PlayerRepository {
  final List<Player> _players;

  MockPlayerRepository(this._players);

  @override
  Future<List<Player>> getActive() async =>
      _players.where((p) => p.isActive).toList();

  @override
  Future<List<Player>> getAll() async => List<Player>.from(_players);

  @override
  Future<void> add(Player player) async => _players.add(player);

  @override
  Future<void> addAll(List<Player> players) async {
    for (final player in players) {
      await add(player);
    }
  }

  @override
  Future<void> remove(String id) async =>
      _players.removeWhere((p) => p.id == id);

  @override
  Future<void> removeAll(List<String> ids) async {
    final idSet = ids.toSet();
    _players.removeWhere((p) => idSet.contains(p.id));
  }

  @override
  Future<void> update(Player player) async {
    final index = _players.indexWhere((p) => p.id == player.id);
    if (index != -1) {
      _players[index] = player;
    }
  }

  @override
  Future<void> updateAll(List<Player> players) async {
    for (final player in players) {
      await update(player);
    }
  }
}

void main() {
  group('Player.copyWith', () {
    test('excludedPartnerId は未指定なら維持し、null 指定ならクリアできること', () {
      const player = Player(
        id: 'p1',
        name: 'P1',
        yomigana: 'p1',
        gender: Gender.male,
        excludedPartnerId: 'p2',
      );

      final unchanged = player.copyWith(name: 'P1 updated');
      final cleared = player.copyWith(excludedPartnerId: null);

      expect(unchanged.excludedPartnerId, 'p2');
      expect(cleared.excludedPartnerId, isNull);
    });
  });

  group('PlayerNotifier partner link/unlink', () {
    test('unlinkPartner で copyWith(excludedPartnerId: null) が保存後に反映されること', () async {
      final repo = MockPlayerRepository([
        const Player(
          id: 'a',
          name: 'A',
          yomigana: 'a',
          gender: Gender.male,
          excludedPartnerId: 'b',
        ),
        const Player(
          id: 'b',
          name: 'B',
          yomigana: 'b',
          gender: Gender.female,
          excludedPartnerId: 'a',
        ),
      ]);

      final notifier = PlayerNotifier(repo);
      await Future<void>.delayed(Duration.zero);

      await notifier.unlinkPartner('a');

      final updatedA = repo._players.firstWhere((p) => p.id == 'a');
      final updatedB = repo._players.firstWhere((p) => p.id == 'b');

      expect(updatedA.excludedPartnerId, isNull);
      expect(updatedB.excludedPartnerId, isNull);
      expect(
        notifier.players.firstWhere((p) => p.id == 'a').excludedPartnerId,
        isNull,
      );
    });

    test('linkPartner で既存ペア解除時の null 指定が保存後に反映されること', () async {
      final repo = MockPlayerRepository([
        const Player(
          id: 'a',
          name: 'A',
          yomigana: 'a',
          gender: Gender.male,
          excludedPartnerId: 'c',
        ),
        const Player(
          id: 'b',
          name: 'B',
          yomigana: 'b',
          gender: Gender.female,
          excludedPartnerId: 'd',
        ),
        const Player(
          id: 'c',
          name: 'C',
          yomigana: 'c',
          gender: Gender.female,
          excludedPartnerId: 'a',
        ),
        const Player(
          id: 'd',
          name: 'D',
          yomigana: 'd',
          gender: Gender.male,
          excludedPartnerId: 'b',
        ),
      ]);

      final notifier = PlayerNotifier(repo);
      await Future<void>.delayed(Duration.zero);

      await notifier.linkPartner('a', 'b');

      final updatedA = repo._players.firstWhere((p) => p.id == 'a');
      final updatedB = repo._players.firstWhere((p) => p.id == 'b');
      final updatedC = repo._players.firstWhere((p) => p.id == 'c');
      final updatedD = repo._players.firstWhere((p) => p.id == 'd');

      expect(updatedA.excludedPartnerId, 'b');
      expect(updatedB.excludedPartnerId, 'a');
      expect(updatedC.excludedPartnerId, isNull);
      expect(updatedD.excludedPartnerId, isNull);
      expect(
        notifier.players.firstWhere((p) => p.id == 'c').excludedPartnerId,
        isNull,
      );
      expect(
        notifier.players.firstWhere((p) => p.id == 'd').excludedPartnerId,
        isNull,
      );
    });
  });
}
