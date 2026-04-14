import 'dart:developer' as dev;

import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_session_selection.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';

/// 試合数や対戦履歴の偏りを抑えつつ、同時出場制限ペアを自動解消するマッチメイキングアルゴリズム
class BalancedMatchAlgorithm implements MatchAlgorithm {
  final GameEvaluator gameEvaluator;
  final CourtAssignmentAlgorithm courtAssignmentAlgorithm;

  BalancedMatchAlgorithm({
    required this.gameEvaluator,
    required this.courtAssignmentAlgorithm,
  });

  @override
  List<Game> generateMatches({
    required List<MatchType> matchTypes,
    required PlayerStatsPool playerPool,
  }) {
    final int requiredMale = matchTypes.requiredPlayerCount(isMale: true);
    final int requiredFemale = matchTypes.requiredPlayerCount(isMale: false);

    dev.log('--- マッチ生成開始: 男子必要 $requiredMale, 女子必要 $requiredFemale ---',
        name: 'MatchAlgo');

    // 1. 利用可能なプレイヤー（isMustRest以外）を抽出
    final available = playerPool.filterAvailable();

    // 2. セッション選抜状態の初期化
    var session = MatchSessionSelection(
      male: available.males.splitSelection(requiredMale),
      female: available.females.splitSelection(requiredFemale),
    );

    // 3. 制限ペア解消ループ (MatchSessionSelectionに責務を委譲)
    int retryCount = 0;
    const int maxRetries = 5;

    while (session.hasCrossGenderConflict && retryCount < maxRetries) {
      dev.log('コンフリクト検知。解消試行 ${retryCount + 1} 回目', name: 'MatchAlgo');

      // 解消
      session = session.resolveConflicts();

      // 補充 (それぞれの性別の元のプールから補充)
      session = MatchSessionSelection(
        male: available.males.refillSelection(session.male, requiredMale),
        female:
            available.females.refillSelection(session.female, requiredFemale),
      );

      retryCount++;
    }

    if (retryCount >= maxRetries) {
      dev.log('警告: $maxRetries 回試行しましたが、一部の制限ペアが解消しきれませんでした。',
          name: 'MatchAlgo');
    }

    // 4. 最適な試合構成（コート割り当て）を探索
    return _findOptimalMatches(matchTypes, session);
  }

  List<Game> _findOptimalMatches(
      List<MatchType> types, MatchSessionSelection session) {
    final assignmentResult = courtAssignmentAlgorithm.searchBestAssignment(
      types: types,
      mustMales: session.male.mustPlayers,
      mustFemales: session.female.mustPlayers,
      candidateMales: session.male.candidatePool.all,
      candidateFemales: session.female.candidatePool.all,
      previousMaleSelections: session.male.candidatePool.previousMaleSelections,
      previousFemaleSelections:
          session.female.candidatePool.previousFemaleSelections,
    );

    if (assignmentResult.games.isEmpty) {
      throw Exception('最適な試合構成が見つかりませんでした。');
    }
    return assignmentResult.games;
  }
}
