import '../../entities/player.dart';

abstract class PlayerRepository {
  Future<List<Player>> getAll();

  Future<List<Player>> getActive();

  Future<void> add(Player player);

  Future<void> addAll(List<Player> players);

  Future<void> update(Player player);

  Future<void> updateAll(List<Player> players);

  Future<void> remove(String id);

  Future<void> removeAll(List<String> ids);
}
