import 'package:collection/collection.dart';
import 'package:game_member_generator/domain/algorithm/court_assignment/court_assignment_algorithm.dart';
import 'package:game_member_generator/domain/algorithm/game_evaluator.dart';
import 'package:game_member_generator/domain/algorithm/match_algorithm.dart';
import 'package:game_member_generator/domain/entities/game.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/domain/entities/player_stats_pool.dart';
import 'package:game_member_generator/domain/entities/player_with_stats.dart';

/// 試合数や対戦履歴の偏りを抑えたマッチメイキングアルゴリズム
class BalancedMatchAlgorithm implements MatchAlgorithm {
  GameEvaluator gameEvaluator;
  CourtAssignmentAlgorithm courtAssignmentAlgorithm;

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
    int requiredMale = matchTypes.requiredPlayerCount(isMale: true);
    int requiredFemale = matchTypes.requiredPlayerCount(isMale: false);

    // 2. 出場回数に基づいた選出（Must枠と抽選プールの分離）
    // ここで isMustRest が true のプレイヤーをあらかじめ除外（候補から外す）する
    final filteredMaleBuckets = _filterMustRest(maleBuckets);
    final filteredFemaleBuckets = _filterMustRest(femaleBuckets);

    var maleSelection = _splitSelection(filteredMaleBuckets, requiredMale);
    var femaleSelection =
        _splitSelection(filteredFemaleBuckets, requiredFemale);
    var count = 0;
    while (
        _hasCrossGenderConflict(maleSelection, femaleSelection) && count < 5) {
      (maleSelection, femaleSelection) =
          _resolveCrossGenderConflicts(maleSelection, femaleSelection);
      maleSelection = _refillIfLacking(maleSelection, requiredMale);
      femaleSelection = _refillIfLacking(femaleSelection, requiredFemale);
      count++;
    }

    // 3. 最適な試合セットを探索
    return _findOptimalMatches(
      matchTypes: matchTypes,
      maleSelection: maleSelection,
      femaleSelection: femaleSelection,
    );
  }

  /// 男女の選出データを受け取り、Must枠を含めて相互制限ペアのコンフリクトを解消する
  (_SelectionSplit male, _SelectionSplit female) _resolveCrossGenderConflicts(
    _SelectionSplit maleSplit,
    _SelectionSplit femaleSplit,
  ) {
    // 編集可能なリストとして展開
    final List<PlayerWithStats> resolvedMaleMust =
        List.from(maleSplit.mustPlayers);
    final List<PlayerWithStats> resolvedFemaleMust =
        List.from(femaleSplit.mustPlayers);
    final List<PlayerWithStats> resolvedMaleCandidates =
        List.from(maleSplit.candidatePool.all);
    final List<PlayerWithStats> resolvedFemaleCandidates =
        List.from(femaleSplit.candidatePool.all);

    final Set<String> toRemoveIds = {};

    // 男性側の全選出者（Must + Candidate）をMap化
    final allMaleInSelection = [...resolvedMaleMust, ...resolvedMaleCandidates];
    final maleMap = {for (var p in allMaleInSelection) p.id: p};

    // 女性側の全選出者（Must + Candidate）を走査
    final allFemaleInSelection = [
      ...resolvedFemaleMust,
      ...resolvedFemaleCandidates
    ];

    for (var female in allFemaleInSelection) {
      final partnerId = female.player.excludedPartnerId;
      if (partnerId == null) continue;

      final malePartner = maleMap[partnerId];
      if (malePartner != null &&
          malePartner.player.excludedPartnerId == female.id) {
        // 条件の悪い方を削除対象に決定
        toRemoveIds.add(_decideWhichInPartnerToRemove(female, malePartner));
      }
    }

    // --- 削除処理（unselectedへの移動は行わない） ---
    resolvedMaleMust.removeWhere((p) => toRemoveIds.contains(p.id));
    resolvedMaleCandidates.removeWhere((p) => toRemoveIds.contains(p.id));
    resolvedFemaleMust.removeWhere((p) => toRemoveIds.contains(p.id));
    resolvedFemaleCandidates.removeWhere((p) => toRemoveIds.contains(p.id));

    return (
      _SelectionSplit(
        resolvedMaleMust,
        PlayerStatsPool(resolvedMaleCandidates),
        maleSplit.unselectedPool, // 元の選外リストをそのまま保持
      ),
      _SelectionSplit(
        resolvedFemaleMust,
        PlayerStatsPool(resolvedFemaleCandidates),
        femaleSplit.unselectedPool, // 元の選外リストをそのまま保持
      ),
    );
  }

  /// 選出リスト（Must + Candidate）の中に、同時出場制限のコンフリクトがあるか判定する
  bool _hasCrossGenderConflict(_SelectionSplit male, _SelectionSplit female) {
    // 男性側の全選出者（Must + Candidate）のIDをSetにまとめる
    final maleIds = {
      ...male.mustPlayers.map((p) => p.id),
      ...male.candidatePool.all.map((p) => p.id),
    };

    // 女性側の全選出者を走査
    final allFemaleInSelection = [
      ...female.mustPlayers,
      ...female.candidatePool.all
    ];

    for (var femalePlayer in allFemaleInSelection) {
      final partnerId = femalePlayer.player.excludedPartnerId;
      if (partnerId == null) continue;

      // 「女性のパートナーID」が男性選出リストに含まれているか
      if (maleIds.contains(partnerId)) {
        // 相手（男性）側もこの女性をパートナー指定しているか確認
        // ※ 基本的にデータは双方向である前提ですが、より厳密にチェック
        final malePartner =
            male.mustAndCandidate.firstWhereOrNull((p) => p.id == partnerId);
        if (malePartner != null &&
            malePartner.player.excludedPartnerId == femalePlayer.id) {
          return true; // コンフリクト発見
        }
      }
    }

    return false; // コンフリクトなし
  }

  /// どちらを選外に送るか判定する内部基準
  String _decideWhichInPartnerToRemove(PlayerWithStats a, PlayerWithStats b) {
    // 1. 連続出場（休みなし）が長い方を優先的に削る
    if (a.stats.sessionsSinceLastRest != b.stats.sessionsSinceLastRest) {
      return a.stats.sessionsSinceLastRest > b.stats.sessionsSinceLastRest
          ? a.id
          : b.id;
    }
    // 2. 累計試合数が多い方を削る
    if (a.stats.totalMatches != b.stats.totalMatches) {
      return a.stats.totalMatches > b.stats.totalMatches ? a.id : b.id;
    }
    // 3. 完全に同条件ならIDで一意に決定
    return a.id.hashCode > b.id.hashCode ? a.id : b.id;
  }

  _SelectionSplit _refillIfLacking(
    _SelectionSplit split,
    int requiredCount,
  ) {
    final currentCount = split.mustPlayers.length + split.candidatePool.length;
    final lack = requiredCount - currentCount;

    // 足りている場合は何もしない
    if (lack <= 0) return split;

    final List<PlayerWithStats> unselected =
        List.from(split.unselectedPool.all);
    if (unselected.isEmpty) return split; // 補充できる人がいない場合

    // 1. 出場回数（totalMatches）でグループ化（バケット作成）
    final Map<int, List<PlayerWithStats>> buckets = {};
    for (var p in unselected) {
      buckets.putIfAbsent(p.stats.totalMatches, () => []).add(p);
    }

    final List<PlayerWithStats> newCandidates =
        List.from(split.candidatePool.all);
    final List<PlayerWithStats> remainingUnselected = [];

    // 2. 出場回数が少ないバケット順に走査
    final sortedMatches = buckets.keys.toList()..sort();
    int needed = lack;

    for (var matchCount in sortedMatches) {
      final pool = buckets[matchCount]!;

      if (needed <= 0) {
        remainingUnselected.addAll(pool);
        continue;
      }

      if (pool.length <= needed) {
        // バケット全員を入れてもまだ足りない場合
        newCandidates.addAll(pool);
        needed -= pool.length;
      } else {
        // バケットの一部をランダムに選んで補充する場合
        pool.shuffle(); // ランダム性を確保
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

  /// isMustRest フラグが true のプレイヤーを除外したバケットを返す
  Map<int, PlayerStatsPool> _filterMustRest(Map<int, PlayerStatsPool> buckets) {
    return buckets.map((count, pool) {
      final filtered = pool.all.where((p) => !p.player.isMustRest).toList();
      return MapEntry(count, PlayerStatsPool(filtered));
    });
  }

  List<Game> _findOptimalMatches({
    required List<MatchType> matchTypes,
    required _SelectionSplit maleSelection,
    required _SelectionSplit femaleSelection,
  }) {
    // 2. 試合セットを探索する
    final assignmentResult = courtAssignmentAlgorithm.searchBestAssignment(
      types: matchTypes,
      mustMales: maleSelection.mustPlayers,
      mustFemales: femaleSelection.mustPlayers,
      candidateMales: maleSelection.candidatePool.all,
      candidateFemales: femaleSelection.candidatePool.all,
    );

    if (assignmentResult.games.isEmpty) {
      throw Exception('最適な試合構成が見つかりませんでした');
    }
    return assignmentResult.games;
  }

  _SelectionSplit _splitSelection(
      Map<int, PlayerStatsPool> buckets, int requiredCount) {
    final List<PlayerWithStats> must = [];
    final List<PlayerWithStats> candidates = [];
    final List<PlayerWithStats> unselected = [];

    // 出場回数が少ない順にソート
    final sortedKeys = buckets.keys.toList()..sort();

    for (final count in sortedKeys) {
      final pool = buckets[count]!;

      // 1. すでにMust枠が埋まっている場合、それ以降はすべてUnselected
      if (must.length >= requiredCount) {
        unselected.addAll(pool.all);
        continue;
      }

      // 2. このバケット全員を入れても定員以下なら、全員Mustへ
      if (must.length + pool.length <= requiredCount) {
        must.addAll(pool.all);
      }
      // 3. このバケットを入れると定員を超えるなら、このバケットがCandidate（抽選対象）
      else {
        candidates.addAll(pool.all);
      }
    }

    return _SelectionSplit(
        must, PlayerStatsPool(candidates), PlayerStatsPool(unselected));
  }
}

class _SelectionSplit {
  final List<PlayerWithStats> mustPlayers;
  final PlayerStatsPool candidatePool;
  final PlayerStatsPool unselectedPool;

  List<PlayerWithStats> get mustAndCandidate =>
      List.unmodifiable([...mustPlayers, ...candidatePool.all]);

  _SelectionSplit(this.mustPlayers, this.candidatePool, this.unselectedPool);
}
