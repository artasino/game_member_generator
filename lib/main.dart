import 'package:flutter/material.dart';
import 'package:game_member_generator/config/app_config.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';

import 'domain/algorithm/balanced_match_algorithm.dart';
import 'domain/algorithm/court_assignment/stochastic_court_assignment_algorithm.dart';
import 'domain/algorithm/game_evaluator.dart';
import 'domain/services/match_making_service.dart';
import 'infrastructure/persistence/app_repositories.dart';
import 'infrastructure/persistence/repository_provider.dart';
import 'presentation/notifiers/player_notifier.dart';
import 'presentation/notifiers/session_notifier.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 設定ファイルの読み込み
  await AppConfig.load();

  // プラットフォームごとの永続化リポジトリを準備
  final repositories = await createRepositories();

  // サービスとNotifierの準備
  final GameEvaluator gameEvaluator = GameEvaluator();
  final CourtAssignmentAlgorithm courtAssignmentAlgorithm =
      StochasticCourtAssignmentAlgorithm(gameEvaluator: gameEvaluator);
  final algorithm = BalancedMatchAlgorithm(
      gameEvaluator: gameEvaluator,
      courtAssignmentAlgorithm: courtAssignmentAlgorithm);
  final matchService =
      MatchMakingService(algorithm, repositories.playerRepository);

  final playerNotifier = PlayerNotifier(repositories.playerRepository);
  final sessionNotifier = SessionNotifier(
    sessionRepository: repositories.sessionRepository,
    courtSettingsRepository: repositories.courtSettingsRepository,
    matchMakingService: matchService,
  );

  // Notifier同士を接続
  playerNotifier.setSessionNotifier(sessionNotifier);

  runApp(MyApp(
    playerNotifier: playerNotifier,
    sessionNotifier: sessionNotifier,
    repositories: repositories,
  ));
}

class MyApp extends StatelessWidget {
  final PlayerNotifier playerNotifier;
  final SessionNotifier sessionNotifier;
  final AppRepositories repositories;

  const MyApp({
    super.key,
    required this.playerNotifier,
    required this.sessionNotifier,
    required this.repositories,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Member Generator',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(context),
      home: MainNavigationScreen(
        playerNotifier: playerNotifier,
        sessionNotifier: sessionNotifier,
        repositories: repositories,
      ),
    );
  }
}
