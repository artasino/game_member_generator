import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/session.dart';
import '../../domain/repository/court_settings_repository.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import '../../domain/services/match_making_service.dart';

class SessionNotifier extends ChangeNotifier {
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final MatchMakingService matchMakingService;

  List<Session> _sessions = [];
  List<Session> get sessions => _sessions;

  SessionNotifier({
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.matchMakingService,
  }) {
    _refresh();
  }

  Future<void> _refresh() async {
    // リポジトリが UnmodifiableList を返す可能性があるため、変更可能なリストに変換する
    final fetchedSessions = await sessionRepository.getAll();
    _sessions = List.from(fetchedSessions);
    notifyListeners();
  }

  // 特定のセッションを更新する（入れ替え用）
  Future<void> updateSession(Session session) async {
    final index = _sessions.indexWhere((s) => s.index == session.index);
    if (index != -1) {
      // 変更可能なリストであることを保証して更新
      _sessions[index] = session;
      notifyListeners();
      
      // 注意: 永続化が必要な場合はここで repository.update() などを呼ぶべきですが、
      // 現在のリポジトリインターフェースには add/clear しかないため、メモリ上のみの更新となります。
    }
  }

  Future<void> generateSessionWithSettings(CourtSettings settings) async {
    courtSettingsRepository.update(settings);
    final allActivePlayers = matchMakingService.playerRepository.getActive();
    final games = matchMakingService.generateMatches(
      matchTypes: settings.matchTypes,
    );

    final playingPlayerIds = <String>{};
    for (var game in games) {
      playingPlayerIds.add(game.teamA.player1.id);
      playingPlayerIds.add(game.teamA.player2.id);
      playingPlayerIds.add(game.teamB.player1.id);
      playingPlayerIds.add(game.teamB.player2.id);
    }

    final restingPlayers = allActivePlayers
        .where((p) => !playingPlayerIds.contains(p.id))
        .toList();

    final nextIndex = _sessions.length + 1;
    final newSession = Session(nextIndex, games, restingPlayers: restingPlayers);

    await sessionRepository.add(newSession);
    await _refresh();
  }

  Future<void> clearHistory() async {
    await sessionRepository.clear();
    await _refresh();
  }

  CourtSettings getCurrentSettings() {
    return courtSettingsRepository.get();
  }
}
