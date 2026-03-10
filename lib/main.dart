import 'package:flutter/material.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';

import 'domain/algorithm/balanced_match_algorithm.dart';
import 'domain/algorithm/court_assignment/best_force_court_assignment.dart';
import 'domain/algorithm/game_evaluator.dart';
import 'domain/entities/gender.dart';
import 'domain/entities/player.dart';
import 'domain/services/match_making_service.dart';
import 'infrastructure/sqlite/database_helper.dart';
import 'infrastructure/sqlite/sqlite_court_settings_repository.dart';
import 'infrastructure/sqlite/sqlite_player_repository.dart';
import 'infrastructure/sqlite/sqlite_session_history_repository.dart';
import 'presentation/notifiers/player_notifier.dart';
import 'presentation/notifiers/session_notifier.dart';
import 'presentation/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Linux/デスクトップ環境用のSQLite初期化 (FFI)
  DatabaseHelper.initFfi();

  // 2. リポジトリの準備
  final playerRepo = SqlitePlayerRepository();
  final sessionRepo = SqliteSessionHistoryRepository();
  final courtSettingsRepo = SqliteCourtSettingsRepository();

  // 3. サービスとNotifierの準備
  final GameEvaluator gameEvaluator = GameEvaluator();
  final CourtAssignmentAlgorithm courtAssignmentAlgorithm =
      BestForceCourtAssignmentAlgorithm(gameEvaluator: gameEvaluator);
  final algorithm = BalancedMatchAlgorithm(
      gameEvaluator: gameEvaluator,
      courtAssignmentAlgorithm: courtAssignmentAlgorithm); // Balancedに変更
  final matchService = MatchMakingService(algorithm, playerRepo);

  final playerNotifier = PlayerNotifier(playerRepo);
  final sessionNotifier = SessionNotifier(
    sessionRepository: sessionRepo,
    courtSettingsRepository: courtSettingsRepo,
    matchMakingService: matchService,
  );

  // Notifier同士を接続（Playerの変更をSessionに通知するため）
  playerNotifier.setSessionNotifier(sessionNotifier);

  // 4. 初回起動時のみサンプルデータを投入するロジック
  final players = await playerRepo.getAll();
  if (players.isEmpty) {
    for (int i = 1; i <= 5; i++) {
      await playerNotifier.addPlayer(Player(
          id: 'M$i', name: '男子$i', yomigana: 'だんし$i', gender: Gender.male));
      await playerNotifier.addPlayer(Player(
          id: 'F$i', name: '女子$i', yomigana: 'じょし$i', gender: Gender.female));
    }
  }

  runApp(MyApp(
    playerNotifier: playerNotifier,
    sessionNotifier: sessionNotifier,
  ));
}

class MyApp extends StatelessWidget {
  final PlayerNotifier playerNotifier;
  final SessionNotifier sessionNotifier;

  const MyApp({
    super.key,
    required this.playerNotifier,
    required this.sessionNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Member Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: MainNavigationScreen(
        playerNotifier: playerNotifier,
        sessionNotifier: sessionNotifier,
      ),
    );
  }
}
