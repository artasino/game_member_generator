import '../../entities/session.dart';

abstract class SessionHistoryRepository {
  Future<List<Session>> getAll();
  Future<void> add(Session session);
  Future<void> update(Session session); // 追加
  Future<void> clear();
}
