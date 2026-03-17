import 'dart:developer' as dev;

import 'package:collection/collection.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
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
    // 1. 必要人数の計算
    final int requiredMale = matchTypes.requiredPlayerCount(isMale: true);
    final int requiredFemale = matchTypes.requiredPlayerCount(isMale: false);

    dev.log('--- マッチ生成開始: 男子必要 $requiredMale, 女子必要 $requiredFemale ---',
        name: 'MatchAlgo');

    // 2. 休み希望者を除外し、初期選出（Must枠と抽選プールの分離）を行う
    final filteredMaleBuckets = _filterMustRest(maleBuckets);
    final filteredFemaleBuckets = _filterMustRest(femaleBuckets);

    var maleSelection = _splitSelection(filteredMaleBuckets, requiredMale);
    var femaleSelection =
        _splitSelection(filteredFemaleBuckets, requiredFemale);

    // 3. 同時出場制限（Excluded Partner）の解消ループ
    // 解消後に人数が減ったら補充し、再度コンフリクトがないか確認する
    int retryCount = 0;
    const int maxRetries = 5;

    while (_hasCrossGenderConflict(maleSelection, femaleSelection) &&
        retryCount < maxRetries) {
      dev.log('コンフリクト検知。解消試行 ${retryCount + 1} 回目', name: 'MatchAlgo');

      // コンフリクト解消（条件の悪い方をリストから削除）
      (maleSelection, femaleSelection) =
          _resolveCrossGenderConflicts(maleSelection, femaleSelection);

      // 欠員が出た分を選外(unselected)から補充
      maleSelection = _refillIfLacking(maleSelection, requiredMale);
      femaleSelection = _refillIfLacking(femaleSelection, requiredFemale);

      retryCount++;
    }

    if (retryCount >= maxRetries) {
      dev.log('警告: $maxRetries 回試行しましたが、一部の制限ペアが解消しきれませんでした。',
          name: 'MatchAlgo');
    }

    // 4. 最終的な選出メンバーで最適な試合組み合わせ（コート割り当て）を探索
    return _findOptimalMatches(
      matchTypes: matchTypes,
      maleSelection: maleSelection,
      femaleSelection: femaleSelection,
    );
  }

  /// 男女の選出データを受け取り、相互制限ペアのコンフリクトを解消する
  (_SelectionSplit male, _SelectionSplit female) _resolveCrossGenderConflicts(
    _SelectionSplit maleSplit,
    _SelectionSplit femaleSplit,
  ) {
    final List<PlayerWithStats> resolvedMaleMust =
        List.from(maleSplit.mustPlayers);
    final List<PlayerWithStats> resolvedFemaleMust =
        List.from(femaleSplit.mustPlayers);
    final List<PlayerWithStats> resolvedMaleCandidates =
        List.from(maleSplit.candidatePool.all);
    final List<PlayerWithStats> resolvedFemaleCandidates =
        List.from(femaleSplit.candidatePool.all);

    final Set<String> toRemoveIds = {};

    // 男性側の全選出者（Must + Candidate）を高速検索用にMap化
    final allMaleInSelection = [...resolvedMaleMust, ...resolvedMaleCandidates];
    final maleMap = {for (var p in allMaleInSelection) p.id: p};

    // 女性側の全選出者を走査してチェック
    final allFemaleInSelection = [
      ...resolvedFemaleMust,
      ...resolvedFemaleCandidates
    ];

    for (var female in allFemaleInSelection) {
      final partnerId = female.player.excludedPartnerId;
      if (partnerId == null) continue;

      final malePartner = maleMap[partnerId];
      // 相互に指名し合っているか（双方向制限の確認）
      if (malePartner != null &&
          malePartner.player.excludedPartnerId == female.id) {
        // 休みが必要な条件（連続出場数など）が悪い方を特定
        final removeId = _decideWhichInPartnerToRemove(female, malePartner);
        toRemoveIds.add(removeId);

        final removedName = (removeId == female.id)
            ? female.player.name
            : malePartner.player.name;
        dev.log('制限ペア解消: $removedName を選外へ', name: 'MatchAlgo');
      }
    }

    // 指定されたIDを全リストから削除
    resolvedMaleMust.removeWhere((p) => toRemoveIds.contains(p.id));
    resolvedMaleCandidates.removeWhere((p) => toRemoveIds.contains(p.id));
    resolvedFemaleMust.removeWhere((p) => toRemoveIds.contains(p.id));
    resolvedFemaleCandidates.removeWhere((p) => toRemoveIds.contains(p.id));

    return (
      _SelectionSplit(
        resolvedMaleMust,
        PlayerStatsPool(resolvedMaleCandidates),
        maleSplit.unselectedPool,
      ),
      _SelectionSplit(
        resolvedFemaleMust,
        PlayerStatsPool(resolvedFemaleCandidates),
        femaleSplit.unselectedPool,
      ),
    );
  }

  /// 選出メンバーに制限ペアのコンフリクトが残っているか判定
  bool _hasCrossGenderConflict(_SelectionSplit male, _SelectionSplit female) {
    final maleIds = male.mustAndCandidate.map((p) => p.id).toSet();
    final femaleSelection = female.mustAndCandidate;

    for (var f in femaleSelection) {
      final partnerId = f.player.excludedPartnerId;
      if (partnerId != null && maleIds.contains(partnerId)) {
        // 相手側も制限しているか（厳密なチェック）
        final m =
            male.mustAndCandidate.firstWhereOrNull((p) => p.id == partnerId);
        if (m != null && m.player.excludedPartnerId == f.id) {
          return true;
        }
      }
    }
    return false;
  }

  /// どちらのプレイヤーを「お休み」にするか判定する基準
  String _decideWhichInPartnerToRemove(PlayerWithStats a, PlayerWithStats b) {
    // 1. 休みなしでの連続出場が長い方を優先的に削る
    if (a.stats.sessionsSinceLastRest != b.stats.sessionsSinceLastRest) {
      return a.stats.sessionsSinceLastRest > b.stats.sessionsSinceLastRest
          ? a.id
          : b.id;
    }
    // 2. 累計試合数が多い方を削る
    if (a.stats.totalMatches != b.stats.totalMatches) {
      return a.stats.totalMatches > b.stats.totalMatches ? a.id : b.id;
    }
    // 3. 完全に同条件ならIDのハッシュで決定（一貫性のあるランダム性）
    return a.id.hashCode > b.id.hashCode ? a.id : b.id;
  }

  /// 解消によって人数が不足した場合、選外から補充する
  _SelectionSplit _refillIfLacking(_SelectionSplit split, int requiredCount) {
    final currentCount = split.mustPlayers.length + split.candidatePool.length;
    final int lack = requiredCount - currentCount;

    if (lack <= 0) return split;

    final List<PlayerWithStats> unselected =
        List.from(split.unselectedPool.all);
    if (unselected.isEmpty) return split;

    // 出場回数（totalMatches）が少ない人を優先するためのバケット化
    final Map<int, List<PlayerWithStats>> buckets = {};
    for (var p in unselected) {
      buckets.putIfAbsent(p.stats.totalMatches, () => []).add(p);
    }

    final List<PlayerWithStats> newCandidates =
        List.from(split.candidatePool.all);
    final List<PlayerWithStats> remainingUnselected = [];
    final sortedMatches = buckets.keys.toList()..sort();

    int needed = lack;
    for (var matchCount in sortedMatches) {
      final pool = buckets[matchCount]!;
      if (needed <= 0) {
        remainingUnselected.addAll(pool);
        continue;
      }

      if (pool.length <= needed) {
        newCandidates.addAll(pool);
        needed -= pool.length;
      } else {
        // 同じ出場回数の中からはランダムに選出
        pool.shuffle();
        newCandidates.addAll(pool.sublist(0, needed));
        remainingUnselected.addAll(pool.sublist(needed));
        needed = 0;
      }
    }

    return _SelectionSplit(
      split.mustPlayers,
      PlayerStatsPool(newCandidates),
      PlayerStatsPool(remainingUnselected),
    );
  }

  /// 休み希望フラグ(isMustRest)を持つプレイヤーを事前に除外
  Map<int, PlayerStatsPool> _filterMustRest(Map<int, PlayerStatsPool> buckets) {
    return buckets.map((count, pool) {
      final filtered = pool.all.where((p) => !p.player.isMustRest).toList();
      return MapEntry(count, PlayerStatsPool(filtered));
    });
  }

  /// 出場回数バケットから「確定枠」「抽選枠」「選外」に分類する
  _SelectionSplit _splitSelection(
      Map<int, PlayerStatsPool> buckets, int requiredCount) {
    final List<PlayerWithStats> must = [];
    final List<PlayerWithStats> candidates = [];
    final List<PlayerWithStats> unselected = [];
    final sortedKeys = buckets.keys.toList()..sort();

    for (final count in sortedKeys) {
      final pool = buckets[count]!;
      if (must.length >= requiredCount) {
        unselected.addAll(pool.all);
      } else if (must.length + pool.length <= requiredCount) {
        must.addAll(pool.all);
      } else {
        candidates.addAll(pool.all);
      }
    }

    return _SelectionSplit(
        must, PlayerStatsPool(candidates), PlayerStatsPool(unselected));
  }

  /// 最終的なコート割り当てを実行
  List<Game> _findOptimalMatches({
    required List<MatchType> matchTypes,
    required _SelectionSplit maleSelection,
    required _SelectionSplit femaleSelection,
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

/// 選出状態を保持する内部クラス
class _SelectionSplit {
  final List<PlayerWithStats> mustPlayers;
  final PlayerStatsPool candidatePool;
  final PlayerStatsPool unselectedPool;

  List<PlayerWithStats> get mustAndCandidate =>
      List.unmodifiable([...mustPlayers, ...candidatePool.all]);

  _SelectionSplit(this.mustPlayers, this.candidatePool, this.unselectedPool);
}
