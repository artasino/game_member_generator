import 'package:flutter/widgets.dart';

import '../../domain/algorithm/balanced_match_algorithm.dart';
import '../../domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import '../../domain/algorithm/court_assignment/stochastic_court_assignment_algorithm.dart';
import '../../domain/algorithm/game_evaluator.dart';
import '../../domain/services/match_making_service.dart';
import '../../infrastructure/persistence/app_repositories.dart';
import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';

class AppScope extends StatefulWidget {
  final AppRepositories repositories;
  final Widget child;

  const AppScope({
    super.key,
    required this.repositories,
    required this.child,
  });

  static AppScopeContainer of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AppScopeInherited>();
    assert(scope != null, 'AppScope is not found in widget tree.');
    return scope!.container;
  }

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  late final AppScopeContainer _container;

  @override
  void initState() {
    super.initState();
    _container = AppScopeContainer.create(widget.repositories);
  }

  @override
  void dispose() {
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppScopeInherited(
      container: _container,
      child: widget.child,
    );
  }
}

class _AppScopeInherited extends InheritedWidget {
  final AppScopeContainer container;

  const _AppScopeInherited({
    required super.child,
    required this.container,
  });

  @override
  bool updateShouldNotify(_AppScopeInherited oldWidget) => false;
}

class AppScopeContainer {
  final AppRepositories repositories;
  final GameEvaluator gameEvaluator;
  final CourtAssignmentAlgorithm courtAssignmentAlgorithm;
  final BalancedMatchAlgorithm matchAlgorithm;
  final MatchMakingService matchMakingService;
  final SessionNotifier sessionNotifier;
  final PlayerNotifier playerNotifier;

  AppScopeContainer._({
    required this.repositories,
    required this.gameEvaluator,
    required this.courtAssignmentAlgorithm,
    required this.matchAlgorithm,
    required this.matchMakingService,
    required this.sessionNotifier,
    required this.playerNotifier,
  });

  factory AppScopeContainer.create(AppRepositories repositories) {
    final gameEvaluator = GameEvaluator();
    final courtAssignmentAlgorithm = StochasticCourtAssignmentAlgorithm(
      gameEvaluator: gameEvaluator,
    );
    final matchAlgorithm = BalancedMatchAlgorithm(
      gameEvaluator: gameEvaluator,
      courtAssignmentAlgorithm: courtAssignmentAlgorithm,
    );
    final matchMakingService = MatchMakingService(
      matchAlgorithm,
      repositories.playerRepository,
    );
    final sessionNotifier = SessionNotifier(
      sessionRepository: repositories.sessionRepository,
      courtSettingsRepository: repositories.courtSettingsRepository,
      matchMakingService: matchMakingService,
    );
    final playerNotifier = PlayerNotifier(repositories.playerRepository);
    playerNotifier.setSessionNotifier(sessionNotifier);

    return AppScopeContainer._(
      repositories: repositories,
      gameEvaluator: gameEvaluator,
      courtAssignmentAlgorithm: courtAssignmentAlgorithm,
      matchAlgorithm: matchAlgorithm,
      matchMakingService: matchMakingService,
      sessionNotifier: sessionNotifier,
      playerNotifier: playerNotifier,
    );
  }

  void dispose() {
    playerNotifier.dispose();
    sessionNotifier.dispose();
  }
}
