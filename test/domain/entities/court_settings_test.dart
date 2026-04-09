import 'package:flutter_test/flutter_test.dart';
import 'package:game_member_generator/domain/entities/court_settings.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';

void main() {
  group('CourtSettings.fromJson', () {
    test('キー欠損時はコンストラクタ既定値を使う', () {
      final settings = CourtSettings.fromJson({
        'matchTypes': [MatchType.mixedDoubles.index],
      });

      expect(settings.matchTypes, [MatchType.mixedDoubles]);
      expect(settings.autoCourtCount, 3);
      expect(settings.autoCourtPolicy, AutoCourtPolicy.balance);
      expect(settings.isAutoRecommendMode, isFalse);
    });

    test('旧形式(List)を読み込める', () {
      final settings = CourtSettings.fromJson([
        MatchType.menSingles.index,
        MatchType.womenSingles.index,
      ]);

      expect(
        settings.matchTypes,
        [MatchType.menSingles, MatchType.womenSingles],
      );
      expect(settings.autoCourtCount, 3);
      expect(settings.autoCourtPolicy, AutoCourtPolicy.balance);
      expect(settings.isAutoRecommendMode, isFalse);
    });
  });
}
