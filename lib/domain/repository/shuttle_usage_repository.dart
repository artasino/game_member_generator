import '../entities/shuttle_usage_record.dart';

abstract class ShuttleUsageRepository {
  Future<void> save(ShuttleUsageRecord record);

  Future<List<ShuttleUsageRecord>> getAll();

  Future<void> delete(int id);
}
