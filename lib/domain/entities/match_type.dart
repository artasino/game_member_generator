enum MatchType {
  menDoubles,
  womenDoubles,
  mixedDoubles,
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
