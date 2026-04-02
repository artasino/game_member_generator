enum MatchType {
  menDoubles,
  womenDoubles,
  mixedDoubles,
}

extension MatchTypeX on MatchType {
  String get displayName {
    switch (this) {
      case MatchType.menDoubles:
        return 'MD';
      case MatchType.womenDoubles:
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
        case MatchType.menDoubles:
          return sum + (isMale ? 4 : 0);
        case MatchType.womenDoubles:
          return sum + (isMale ? 0 : 4);
        case MatchType.mixedDoubles:
          return sum + 2;
      }
    });
  }
}
