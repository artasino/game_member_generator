import 'player_stats_pool.dart';
import 'player_with_stats.dart';

/// プレイヤーの選出状態を保持するドメインオブジェクト
class PlayerSelection {
  /// 優先的に選出されるプレイヤー（出場回数が少ないグループ）
  final List<PlayerWithStats> mustPlayers;

  /// 定員の関係で抽選対象となるプレイヤーのプール
  final PlayerStatsPool candidatePool;

  /// 今回のセッションでは選出されないプレイヤーのプール
  final PlayerStatsPool unselectedPool;

  // キャッシュ用のフィールド
  Set<String>? _allCandidateIds;

  PlayerSelection({
    required this.mustPlayers,
    required this.candidatePool,
    required this.unselectedPool,
  });

  /// 選出候補（確定枠 + 抽選枠）の全員
  List<PlayerWithStats> get allCandidates =>
      List.unmodifiable([...mustPlayers, ...candidatePool.all]);

  /// 選出候補のIDセット（計算効率化のためキャッシュ）
  Set<String> get allCandidateIds {
    _allCandidateIds ??= {
      for (var p in mustPlayers) p.id,
      for (var p in candidatePool.all) p.id,
    };
    return _allCandidateIds!;
  }

  /// 空の選出状態を作成
  factory PlayerSelection.empty() => PlayerSelection(
        mustPlayers: [],
        candidatePool: PlayerStatsPool([]),
        unselectedPool: PlayerStatsPool([]),
      );

  /// 特定のプレイヤーを選出対象から除外し、新しい選出状態を返す
  PlayerSelection removePlayers(Set<String> idsToRemove) {
    final newMust =
        mustPlayers.where((p) => !idsToRemove.contains(p.id)).toList();
    final newCandidates =
        candidatePool.all.where((p) => !idsToRemove.contains(p.id)).toList();

    return PlayerSelection(
      mustPlayers: newMust,
      candidatePool: PlayerStatsPool(newCandidates),
      unselectedPool: unselectedPool,
    );
  }

  /// 現在の選出人数
  int get selectedCount => mustPlayers.length + candidatePool.length;
}
