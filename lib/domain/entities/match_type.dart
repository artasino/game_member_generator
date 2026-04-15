import 'gender.dart';

enum MatchType {
  maleDoubles,
  femaleDoubles,
  mixedDoubles,
}

extension MatchTypeX on MatchType {
  String get displayName {
    switch (this) {
      case MatchType.maleDoubles:
        return 'MD';
      case MatchType.femaleDoubles:
        return 'WD';
      case MatchType.mixedDoubles:
        return 'XD';
    }
  }

  /// この試合形式に必要な男性数
  int get requiredMaleCount {
    switch (this) {
      case MatchType.maleDoubles:
        return 4;
      case MatchType.femaleDoubles:
        return 0;
      case MatchType.mixedDoubles:
        return 2;
    }
  }

  /// この試合形式に必要な女性数
  int get requiredFemaleCount {
    switch (this) {
      case MatchType.maleDoubles:
        return 0;
      case MatchType.femaleDoubles:
        return 4;
      case MatchType.mixedDoubles:
        return 2;
    }
  }

  /// 指定した性別がこの試合形式に参加可能か
  bool isAppropriateFor(Gender gender) {
    switch (this) {
      case MatchType.maleDoubles:
        return gender == Gender.male;
      case MatchType.femaleDoubles:
        return gender == Gender.female;
      case MatchType.mixedDoubles:
        return true;
    }
  }
}

extension MatchTypeIterableX on Iterable<MatchType> {
  int requiredPlayerCount({required bool isMale}) {
    return fold(
        0,
        (sum, type) =>
            sum + (isMale ? type.requiredMaleCount : type.requiredFemaleCount));
  }
}
