import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/repository/session_repository/session_history_repository.dart';

class InMemorySessionRepository implements SessionHistoryRepository {
  final List<Session> _sessions = [];

  @override
  Future<void> add(Session session) async {
    _sessions.add(session);
  }

  @override
  Future<void> clear() async {
    _sessions.clear();
  }

  @override
  Future<List<Session>> getAll() async {
    return List.unmodifiable(_sessions);
  }

  @override
  Future<void> update(Session session) async {
    final index = _sessions.indexWhere((s) => s.index == session.index);
    if (index >= 0) {
      _sessions[index] = session;
    } else {
      _sessions.add(session);
    }
  }

  @override
  Future<void> delete(int sessionIndex) async {
    _sessions.removeWhere((s) => s.index == sessionIndex);
  }
}
