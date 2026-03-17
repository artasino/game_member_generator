import 'dart:math';

import 'gender.dart';
import 'player_selection.dart';
import 'player_with_stats.dart';

/// プレイヤー統計の集合（プール）を管理するドメインオブジェクト
class PlayerStatsPool {
  final List<PlayerWithStats> _players;

  PlayerStatsPool(this._players);

  /// 参加メンバ全員
  List<PlayerWithStats> get all => List.unmodifiable(_players);

  /// 現在のプールの人数
  int get length {
    try {
      return _players.length;
    } catch (_) {
      return 0;
    }
  }

  /// 男性のみのプールを返す
  PlayerStatsPool get males => PlayerStatsPool(
        _players.where((p) => p.player.gender == Gender.male).toList(),
      );

  /// 女性のみのプールを返す
  PlayerStatsPool get females => PlayerStatsPool(
        _players.where((p) => p.player.gender == Gender.female).toList(),
      );

  /// 試合数ごとのグループ（バケット）に分割して返す
  /// Key: 出場回数, Value: その回数出場したプレイヤーのプール
  Map<int, PlayerStatsPool> get buckets {
    final Map<int, List<PlayerWithStats>> groups = {};
    for (final p in _players) {
      final count = p.stats.totalMatches;
      groups.putIfAbsent(count, () => []).add(p);
    }
    // 回数（Key）でソートされたMapを作成
    final sortedKeys = groups.keys.toList()..sort();
    return {for (var k in sortedKeys) k: PlayerStatsPool(groups[k]!)};
  }

  /// 試合数が少ない順にソートしたリストを返す（同じ回数ならランダム）
  List<PlayerWithStats> getByLeastPlayed(Random random) {
    final list = List<PlayerWithStats>.from(_players);
    // 同じ試合数の人たちの中で偏りが出ないよう、ソート前にシャッフルする
    list.shuffle(random);
    list.sort((a, b) => a.stats.totalMatches.compareTo(b.stats.totalMatches));
    return list;
  }

  /// 出場回数に基づいて「確定枠」「抽選枠」「選外」に分類した選出状態を返す
  PlayerSelection splitSelection(int requiredCount) {
    final List<PlayerWithStats> must = [];
    final List<PlayerWithStats> candidates = [];
    final List<PlayerWithStats> unselected = [];

    final sortedBuckets = buckets;
    bool capacityReached = false;

    for (final pool in sortedBuckets.values) {
      if (capacityReached) {
        unselected.addAll(pool.all);
        continue;
      }

      if (must.length + pool.length <= requiredCount) {
        must.addAll(pool.all);
        if (must.length == requiredCount) {
          capacityReached = true;
        }
      } else {
        // このバケットで定員を超えるため、このバケットの全員を候補（抽選枠）にする
        candidates.addAll(pool.all);
        capacityReached = true;
      }
    }

    return PlayerSelection(
      mustPlayers: must,
      candidatePool: PlayerStatsPool(candidates),
      unselectedPool: PlayerStatsPool(unselected),
    );
  }

  /// 解消によって人数が不足した場合、選外から補充する
  PlayerSelection refillSelection(
      PlayerSelection selection, int requiredCount) {
    final int lack = requiredCount - selection.selectedCount;
    if (lack <= 0) return selection;

    final List<PlayerWithStats> unselectedList =
        List.from(selection.unselectedPool.all);
    if (unselectedList.isEmpty) return selection;

    // 出場回数（totalMatches）が少ない人を優先するためのバケット化
    final poolForRefill = PlayerStatsPool(unselectedList);
    final sortedBuckets = poolForRefill.buckets;

    final List<PlayerWithStats> newCandidates =
        List.from(selection.candidatePool.all);
    final List<PlayerWithStats> remainingUnselected = [];

    int needed = lack;
    for (final pool in sortedBuckets.values) {
      if (needed <= 0) {
        remainingUnselected.addAll(pool.all);
        continue;
      }

      if (pool.length <= needed) {
        newCandidates.addAll(pool.all);
        needed -= pool.length;
      } else {
        // 同じ出場回数の中からはランダムに選出
        final shuffled = List<PlayerWithStats>.from(pool.all)..shuffle();
        newCandidates.addAll(shuffled.sublist(0, needed));
        remainingUnselected.addAll(shuffled.sublist(needed));
        needed = 0;
      }
    }

    return PlayerSelection(
      mustPlayers: selection.mustPlayers,
      candidatePool: PlayerStatsPool(newCandidates),
      unselectedPool: PlayerStatsPool(remainingUnselected),
    );
  }

  /// 指定した人数を「出場回数が少ない順」に選出し、残りのプールを返す
  SelectionResult pickCandidates(int count, Random random) {
    final sorted = getByLeastPlayed(random);
    final picked = sorted.take(count).toList();
    final remaining = sorted.skip(count).toList();

    return SelectionResult(picked, PlayerStatsPool(remaining));
  }

  PlayerStatsPool removeById(String id) {
    final filtered = _players.where((p) => p.id != id).toList();
    return PlayerStatsPool(filtered);
  }
}

/// 選出結果を保持するデータ構造
class SelectionResult {
  final List<PlayerWithStats> picked;
  final PlayerStatsPool remainingPool;

  SelectionResult(this.picked, this.remainingPool);
}
