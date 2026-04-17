import 'package:game_member_generator/domain/repository/court_settings_repository.dart';
import 'package:game_member_generator/domain/repository/expense_repository.dart';
import 'package:game_member_generator/domain/repository/inquiry_repository.dart';
import 'package:game_member_generator/domain/repository/player_repository/player_repository.dart';
import 'package:game_member_generator/domain/repository/session_repository/session_history_repository.dart';
import 'package:game_member_generator/domain/repository/shuttle_stock_repository.dart';
import 'package:game_member_generator/domain/repository/shuttle_usage_repository.dart';

class AppRepositories {
  final PlayerRepository playerRepository;
  final SessionHistoryRepository sessionRepository;
  final CourtSettingsRepository courtSettingsRepository;
  final ShuttleStockRepository shuttleStockRepository;
  final ShuttleUsageRepository shuttleUsageRepository;
  final ExpenseRepository expenseRepository;
  final InquiryRepository inquiryRepository;

  const AppRepositories({
    required this.playerRepository,
    required this.sessionRepository,
    required this.courtSettingsRepository,
    required this.shuttleStockRepository,
    required this.shuttleUsageRepository,
    required this.expenseRepository,
    required this.inquiryRepository,
  });
}
