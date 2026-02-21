import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
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

  // 設定を保存し、その設定で試合を生成する
  Future<void> generateSessionWithSettings(CourtSettings settings) async {
    // リポジトリの設定も更新しておく（次回のデフォルトになる）
    courtSettingsRepository.update(settings);
    
    // 現在のアクティブプレイヤーを元に試合を生成
    final games = matchMakingService.generateMatches(
      matchTypes: settings.matchTypes,
    );

    final nextIndex = _sessions.length + 1;
    final newSession = Session(nextIndex, games);

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
