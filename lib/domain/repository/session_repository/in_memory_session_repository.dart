import 'package:game_member_generator/domain/entities/session.dart';
import 'package:game_member_generator/domain/repository/session_repository/session_history_repository.dart';

class InMemorySessionRepository implements SessionHistoryRepository{
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
  Future<List<Session>> getAll() async{
    return List.unmodifiable(_sessions);
  }
}