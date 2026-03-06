import 'dart:math';
import 'gender.dart';
import 'player_with_stats.dart';

/// プレイヤー統計の集合（プール）を管理するドメインオブジェクト
class PlayerStatsPool {
  final List<PlayerWithStats> _players;

  PlayerStatsPool(this._players);

  /// 参加メンバ全員
  List<PlayerWithStats> get all => List.unmodifiable(_players);

  /// 男性のみのプールを返す
  PlayerStatsPool get males => PlayerStatsPool(
        _players.where((p) => p.player.gender == Gender.male).toList(),
      );

  /// 女性のみのプールを返す
  PlayerStatsPool get females => PlayerStatsPool(
        _players.where((p) => p.player.gender == Gender.female).toList(),
      );

  /// 試合数が少ない順にソートしたリストを返す（同じ回数ならランダム）
  List<PlayerWithStats> getByLeastPlayed(Random random) {
    final list = List<PlayerWithStats>.from(_players);
    // 同じ試合数の人たちの中で偏りが出ないよう、ソート前にシャッフルする
    list.shuffle(random);
    list.sort((a, b) => a.stats.totalMatches.compareTo(b.stats.totalMatches));
    return list;
  }

  /// 指定した人数を「出場回数が少ない順」に選出し、残りのプールを返す
  ///
  /// 戻り値: [選出されたメンバのリスト, 残りのメンバによる新しいプール]
  SelectionResult pickCandidates(int count, Random random) {
    final sorted = getByLeastPlayed(random);
    final picked = sorted.take(count).toList();
    final remaining = sorted.skip(count).toList();

    return SelectionResult(picked, PlayerStatsPool(remaining));
  }

  /// 現在のプールの人数
  int get length => _players.length;
}

/// 選出結果を保持するデータ構造
class SelectionResult {
  final List<PlayerWithStats> picked;
  final PlayerStatsPool remainingPool;

  SelectionResult(this.picked, this.remainingPool);
}
