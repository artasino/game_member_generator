import '../../entities/player.dart';

abstract class PlayerRepository {
  Future<List<Player>> getAll();
  Future<List<Player>> getActive();
  Future<void> add(Player player);
  Future<void> update(Player player);
  Future<void> remove(String id);
}
