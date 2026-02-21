import '../algorithm/match_algorithm.dart';
import '../entities/game.dart';
import '../entities/match_type.dart';
import '../repository/player_repository.dart';

class MatchMakingService {
  final MatchAlgorithm algorithm;
  final PlayerRepository playerRepository;

  MatchMakingService(this.algorithm, this.playerRepository);

  List<Game> generateMatches({
    required List<MatchType> matchTypes,
  }) {
    // 保存されている「アクティブな」プレイヤーを取得してマッチングに利用する
    final players = playerRepository.getActive();
    return algorithm.generateMatches(players: players, matchTypes: matchTypes);
  }
}
