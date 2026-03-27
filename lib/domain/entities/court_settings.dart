import 'package:game_member_generator/domain/entities/match_type.dart';

enum AutoCourtPolicy {
  genderSeparated,
  balance,
  mix,
}

extension AutoCourtPolicyX on AutoCourtPolicy {
  String get displayName {
    switch (this) {
      case AutoCourtPolicy.genderSeparated:
        return '男女別';
      case AutoCourtPolicy.balance:
        return 'バランス';
      case AutoCourtPolicy.mix:
        return 'ミックス';
    }
  }
}

class CourtSettings {
  List<MatchType> matchTypes;
  int autoCourtCount;
  AutoCourtPolicy autoCourtPolicy;

  CourtSettings(
    this.matchTypes, {
    this.autoCourtCount = 2,
    this.autoCourtPolicy = AutoCourtPolicy.balance,
  });
}
