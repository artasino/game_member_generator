import 'dart:math';

import 'gender.dart';
import 'player_with_stats.dart';

/// プレイヤー統計の集合（プール）を管理するドメインオブジェクト
class PlayerStatsPool {
  final List<PlayerWithStats> _players;

  PlayerStatsPool(this._players);

  /// 参加メンバ全員
  List<PlayerWithStats> get all => List.unmodifiable(_players);

  /// 現在のプールの人数
  int get length {
    // リスト自体が初期化されていない、または要素がない場合は0を返す
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
