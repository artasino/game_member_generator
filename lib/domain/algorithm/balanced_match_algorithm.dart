import 'dart:developer' as dev;

import 'package:collection/collection.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_selection.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

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
    required Map<int, PlayerStatsPool> maleBuckets,
    required Map<int, PlayerStatsPool> femaleBuckets,
  }) {
    final int requiredMale = matchTypes.requiredPlayerCount(isMale: true);
    final int requiredFemale = matchTypes.requiredPlayerCount(isMale: false);

    dev.log('--- マッチ生成開始: 男子必要 $requiredMale, 女子必要 $requiredFemale ---',
        name: 'MatchAlgo');

    // 1. 休み希望者を除外し、初期選出（Must枠と抽選プールの分離）を行う
    final malePool = _flattenAndFilter(maleBuckets);
    final femalePool = _flattenAndFilter(femaleBuckets);

    var maleSelection = malePool.splitSelection(requiredMale);
    var femaleSelection = femalePool.splitSelection(requiredFemale);

    // 2. 同時出場制限（Excluded Partner）の解消ループ
    int retryCount = 0;
    const int maxRetries = 5;

    while (_hasCrossGenderConflict(maleSelection, femaleSelection) &&
        retryCount < maxRetries) {
      dev.log('コンフリクト検知。解消試行 ${retryCount + 1} 回目', name: 'MatchAlgo');

      // コンフリクト解消
      (maleSelection, femaleSelection) =
          _resolveCrossGenderConflicts(maleSelection, femaleSelection);

      // 欠員補充（PlayerStatsPoolに委譲）
      maleSelection = malePool.refillSelection(maleSelection, requiredMale);
      femaleSelection =
          femalePool.refillSelection(femaleSelection, requiredFemale);

      retryCount++;
    }

    if (retryCount >= maxRetries) {
      dev.log('警告: $maxRetries 回試行しましたが、一部の制限ペアが解消しきれませんでした。',
          name: 'MatchAlgo');
    }

    // 3. 最適な試合組み合わせ（コート割り当て）を探索
    return _findOptimalMatches(
      matchTypes: matchTypes,
      maleSelection: maleSelection,
      femaleSelection: femaleSelection,
    );
  }

  /// バケットを平坦化し、isMustRest フラグを持つプレイヤーを除外する
  PlayerStatsPool _flattenAndFilter(Map<int, PlayerStatsPool> buckets) {
    final allPlayers = buckets.values.expand((pool) => pool.all).toList();
    final filtered = allPlayers.where((p) => !p.player.isMustRest).toList();
    return PlayerStatsPool(filtered);
  }

  /// 男女の選出データを受け取り、相互制限ペアのコンフリクトを解消する
  (PlayerSelection male, PlayerSelection female) _resolveCrossGenderConflicts(
    PlayerSelection maleSelection,
    PlayerSelection femaleSelection,
  ) {
    final Set<String> toRemoveIds = {};

    // 男性側の全候補者をMap化
    final maleMap = {for (var p in maleSelection.allCandidates) p.id: p};

    // 女性側の全候補者を走査
    for (var female in femaleSelection.allCandidates) {
      final partnerId = female.player.excludedPartnerId;
      if (partnerId == null) continue;

      final malePartner = maleMap[partnerId];
      // 相互制限の確認
      if (malePartner != null &&
          malePartner.player.excludedPartnerId == female.id) {
        final removeId = _decideWhichInPartnerToRemove(female, malePartner);
        toRemoveIds.add(removeId);

        final removedName = (removeId == female.id)
            ? female.player.name
            : malePartner.player.name;
        dev.log('制限ペア解消: $removedName を選外へ', name: 'MatchAlgo');
      }
    }

    return (
      maleSelection.removePlayers(toRemoveIds),
      femaleSelection.removePlayers(toRemoveIds),
    );
  }

  bool _hasCrossGenderConflict(PlayerSelection male, PlayerSelection female) {
    final maleIds = male.allCandidates.map((p) => p.id).toSet();

    for (var f in female.allCandidates) {
      final partnerId = f.player.excludedPartnerId;
      if (partnerId != null && maleIds.contains(partnerId)) {
        final m = male.allCandidates.firstWhereOrNull((p) => p.id == partnerId);
        if (m != null && m.player.excludedPartnerId == f.id) {
          return true;
        }
      }
    }
    return false;
  }

  String _decideWhichInPartnerToRemove(PlayerWithStats a, PlayerWithStats b) {
    if (a.stats.sessionsSinceLastRest != b.stats.sessionsSinceLastRest) {
      return a.stats.sessionsSinceLastRest > b.stats.sessionsSinceLastRest
          ? a.id
          : b.id;
    }
    if (a.stats.totalMatches != b.stats.totalMatches) {
      return a.stats.totalMatches > b.stats.totalMatches ? a.id : b.id;
    }
    return a.id.hashCode > b.id.hashCode ? a.id : b.id;
  }

  List<Game> _findOptimalMatches({
    required List<MatchType> matchTypes,
    required PlayerSelection maleSelection,
    required PlayerSelection femaleSelection,
  }) {
    final assignmentResult = courtAssignmentAlgorithm.searchBestAssignment(
      types: matchTypes,
      mustMales: maleSelection.mustPlayers,
      mustFemales: femaleSelection.mustPlayers,
      candidateMales: maleSelection.candidatePool.all,
      candidateFemales: femaleSelection.candidatePool.all,
    );

    if (assignmentResult.games.isEmpty) {
      throw Exception('最適な試合構成が見つかりませんでした。');
    }
    return assignmentResult.games;
  }
}
