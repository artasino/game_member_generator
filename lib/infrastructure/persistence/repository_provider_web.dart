import 'package:game_member_generator/infrastructure/persistence/app_repositories.dart';
import 'package:game_member_generator/infrastructure/shared_preferences/shared_preferences_court_settings_repository.dart';
import 'package:game_member_generator/infrastructure/shared_preferences/shared_preferences_player_repository.dart';
import 'package:game_member_generator/infrastructure/shared_preferences/shared_preferences_session_history_repository.dart';

Future<AppRepositories> createRepositories() async {
  return AppRepositories(
    playerRepository: SharedPreferencesPlayerRepository(),
    sessionRepository: SharedPreferencesSessionHistoryRepository(),
    courtSettingsRepository: SharedPreferencesCourtSettingsRepository(),
  );
}
