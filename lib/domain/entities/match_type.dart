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
}

extension MatchTypeIterableX on Iterable<MatchType> {
  int requiredPlayerCount({required bool isMale}) {
    return fold(0, (sum, type) {
      switch (type) {
        case MatchType.maleDoubles:
          return sum + (isMale ? 4 : 0);
        case MatchType.femaleDoubles:
          return sum + (isMale ? 0 : 4);
        case MatchType.mixedDoubles:
          return sum + 2;
      }
    });
  }
}
