import 'package:flutter/material.dart';
import 'domain/algorithm/random_match_algorithm.dart';
import 'domain/entities/gender.dart';
import 'domain/entities/player.dart';
import 'domain/repository/court_settings_repository.dart';
import 'domain/repository/player_repository/in_memory_repository.dart';
import 'domain/repository/session_repository/in_memory_session_repository.dart';
import 'domain/services/match_making_service.dart';
import 'presentation/notifiers/player_notifier.dart';
import 'presentation/notifiers/session_notifier.dart';
import 'presentation/screens/main_navigation_screen.dart';

void main() {
  // 1. 各リポジトリの準備
  final playerRepo = InMemoryPlayerRepository();

  // 初期データの投入（男女5人ずつ）
  for (int i = 1; i <= 5; i++) {
    playerRepo.add(Player(id: 'M$i', name: '男子$i', gender: Gender.male));
    playerRepo.add(Player(id: 'F$i', name: '女子$i', gender: Gender.female));
  }

  final sessionRepo = InMemorySessionRepository();
  final courtSettingsRepo = InMemoryCourtSettingsRepository();

  // 2. サービスの準備
  final algorithm = RandomMatchAlgorithm();
  final matchService = MatchMakingService(algorithm, playerRepo);

  // 3. 各Notifierの準備
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
