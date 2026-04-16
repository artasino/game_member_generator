class PenaltyWeights {
  static const double typeImbalance = 1000.0;
  static const double sameTypeAsPrevious = 200.0;
  static const double pairRepeat = 100.0;
  static const double opponentRepeat = 10.0;
  static const double lastTimeRestedGain = 1000.0;
  static const double restTogether = 20000.0;
  static const double restTogetherMaxBonus = 50000.0;
  static const double identicalSelectionPenalty = 1000000.0;
  static const double consecutiveRestPenalty = 100000.0;
}
