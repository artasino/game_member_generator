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
    _sessions = await sessionRepository.getAll();
    notifyListeners();
  }

  Future<void> generateSessionWithSettings(CourtSettings settings) async {
    courtSettingsRepository.update(settings);
    
    // 全てのアクティブプレイヤーを取得
    final allActivePlayers = matchMakingService.playerRepository.getActive();
    
    // 試合を生成
    final games = matchMakingService.generateMatches(
      matchTypes: settings.matchTypes,
    );

    // 試合に出るプレイヤーのIDを抽出
    final playingPlayerIds = <String>{};
    for (var game in games) {
      playingPlayerIds.add(game.teamA.player1.id);
      playingPlayerIds.add(game.teamA.player2.id);
      playingPlayerIds.add(game.teamB.player1.id);
      playingPlayerIds.add(game.teamB.player2.id);
    }

    // お休みのプレイヤーを特定
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
