import 'package:game_member_generator/domain/repository/court_settings_repository.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';
import 'package:game_member_generator/domain/repository/session_repository/session_history_repository.dart';

class AppRepositories {
  final PlayerRepository playerRepository;
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;

  const AppRepositories({
    required this.playerRepository,
    required this.sessionRepository,
    required this.courtSettingsRepository,
  });
}
