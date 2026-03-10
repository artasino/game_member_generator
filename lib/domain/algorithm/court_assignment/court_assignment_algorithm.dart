import 'package:game_member_generator/domain/algorithm/session_score.dart';

import '../../entities/match_type.dart';
import '../../entities/player_with_stats.dart';

/// an interface of optimizing the match from given members.
abstract class CourtAssignmentAlgorithm {
  SessionScore searchBestAssignment({
    required List<MatchType> types,
    required List<PlayerWithStats> availableMales,
    required List<PlayerWithStats> availableFemales,
  });
}
