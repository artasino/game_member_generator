import '../entities/shuttle_stock.dart';

abstract class ShuttleStockRepository {
  Future<void> save(ShuttleStock stock);

  Future<List<ShuttleStock>> getAll();

  Future<void> delete(int id);
}
