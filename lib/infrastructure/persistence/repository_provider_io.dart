import 'package:game_member_generator/infrastructure/persistence/app_repositories.dart';
import 'package:game_member_generator/infrastructure/sqlite/database_helper.dart';
import 'package:game_member_generator/infrastructure/sqlite/sqlite_court_settings_repository.dart';
import 'package:game_member_generator/infrastructure/sqlite/sqlite_player_repository.dart';
import 'package:game_member_generator/infrastructure/sqlite/sqlite_session_history_repository.dart';
import 'package:game_member_generator/infrastructure/sqlite/sqlite_shuttle_stock_repository.dart';
import 'package:game_member_generator/infrastructure/sqlite/sqlite_shuttle_usage_repository.dart';

Future<AppRepositories> createRepositories() async {
  DatabaseHelper.initFfi();
  return AppRepositories(
    playerRepository: SqlitePlayerRepository(),
    sessionRepository: SqliteSessionHistoryRepository(),
    courtSettingsRepository: SqliteCourtSettingsRepository(),
    shuttleStockRepository: SqliteShuttleStockRepository(),
    shuttleUsageRepository: SqliteShuttleUsageRepository(),
  );
}
