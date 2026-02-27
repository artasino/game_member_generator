import 'package:flutter/material.dart';
import 'domain/algorithm/random_match_algorithm.dart';
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

  // 3. 初回起動時のみサンプルデータを投入するロジック
  final players = await playerRepo.getAll();
  // if (players.isEmpty) {
  //   for (int i = 1; i <= 5; i++) {
  //     await playerRepo.add(Player(id: 'M$i', name: '男子$i', yomigana: 'だんし$i', gender: Gender.male));
  //     await playerRepo.add(Player(id: 'F$i', name: '女子$i', yomigana: 'じょし$i', gender: Gender.female));
  //   }
  // }

  // 4. サービスとNotifierの準備
  final algorithm = RandomMatchAlgorithm();
  final matchService = MatchMakingService(algorithm, playerRepo);

  final playerNotifier = PlayerNotifier(playerRepo);
  final sessionNotifier = SessionNotifier(
    sessionRepository: sessionRepo,
    courtSettingsRepository: courtSettingsRepo,
    matchMakingService: matchService,
  );

  runApp(MyApp(
    playerNotifier: playerNotifier,
    sessionNotifier: sessionNotifier,
  ));
}

class MyApp extends StatelessWidget {
  final PlayerNotifier playerNotifier;
  final SessionNotifier sessionNotifier;

  const MyApp({
    Key? key,
    required this.playerNotifier,
    required this.sessionNotifier,
  }) : super(key: key);

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
