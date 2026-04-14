import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:game_member_generator/infrastructure/shared_preferences/shared_preferences_court_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesCourtSettingsRepository', () {
    test('isAutoRecommendMode が保存・復元される', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = SharedPreferencesCourtSettingsRepository();

      const settings = CourtSettings(
        [MatchType.maleDoubles, MatchType.mixedDoubles],
        autoCourtCount: 3,
        autoCourtPolicy: AutoCourtPolicy.balance,
        isAutoRecommendMode: true,
      );

      await repository.update(settings);
      final loaded = await repository.get();

      expect(loaded.matchTypes, settings.matchTypes);
      expect(loaded.autoCourtCount, settings.autoCourtCount);
      expect(loaded.autoCourtPolicy, settings.autoCourtPolicy);
      expect(loaded.isAutoRecommendMode, isTrue);
    });
  });
}
