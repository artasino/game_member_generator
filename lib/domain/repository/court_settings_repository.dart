import '../entities/court_settings.dart';

abstract class CourtSettingsRepository {
  Future<CourtSettings> get();

  Future<void> update(CourtSettings settings);
}
