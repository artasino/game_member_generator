import '../entities/court_settings.dart';
import '../entities/match_type.dart';

abstract class CourtSettingsRepository {
  CourtSettings get();
  void update(CourtSettings settings);
}

class InMemoryCourtSettingsRepository implements CourtSettingsRepository {
  CourtSettings _settings = CourtSettings([MatchType.menDoubles]);

  @override
  CourtSettings get() => _settings;

  @override
  void update(CourtSettings settings) {
    _settings = settings;
  }
}
