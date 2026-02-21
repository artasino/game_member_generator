import '../../entities/session.dart';

abstract class SessionHistoryRepository {
  Future<List<Session>> getAll();

  Future<void> add(Session session);

  Future<void> clear();
}