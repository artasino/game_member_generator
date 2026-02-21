import '../entities/player.dart';

abstract class PlayerRepository {
  List<Player> getAll();
  List<Player> getActive();
  void add(Player player);
  void update(Player player);
  void remove(String id);
}