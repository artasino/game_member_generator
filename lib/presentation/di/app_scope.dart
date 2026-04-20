import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../domain/algorithm/balanced_match_algorithm.dart';
import '../../domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import '../../domain/algorithm/court_assignment/stochastic_court_assignment_algorithm.dart';
import '../../domain/algorithm/game_evaluator.dart';
import '../../domain/services/match_making_service.dart';
import '../../infrastructure/persistence/app_repositories.dart';
import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';

class AppScope extends StatelessWidget {
  final AppRepositories repositories;
  final Widget child;

  const AppScope({
    super.key,
    required this.repositories,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppRepositories>.value(value: repositories),
        Provider<GameEvaluator>(create: (_) => GameEvaluator()),
        Provider<CourtAssignmentAlgorithm>(
          create: (context) => StochasticCourtAssignmentAlgorithm(
            gameEvaluator: context.read<GameEvaluator>(),
          ),
        ),
        Provider<BalancedMatchAlgorithm>(
          create: (context) => BalancedMatchAlgorithm(
            gameEvaluator: context.read<GameEvaluator>(),
            courtAssignmentAlgorithm: context.read<CourtAssignmentAlgorithm>(),
          ),
        ),
        Provider<MatchMakingService>(
          create: (context) => MatchMakingService(
            context.read<BalancedMatchAlgorithm>(),
            context.read<AppRepositories>().playerRepository,
          ),
        ),
        ChangeNotifierProvider<SessionNotifier>(
          create: (context) => SessionNotifier(
            sessionRepository: context.read<AppRepositories>().sessionRepository,
            courtSettingsRepository:
                context.read<AppRepositories>().courtSettingsRepository,
            matchMakingService: context.read<MatchMakingService>(),
          ),
        ),
        ChangeNotifierProvider<PlayerNotifier>(
          create: (context) {
            final notifier = PlayerNotifier(
              context.read<AppRepositories>().playerRepository,
            );
            notifier.setSessionNotifier(context.read<SessionNotifier>());
            return notifier;
          },
        ),
      ],
      child: child,
    );
  }
}
