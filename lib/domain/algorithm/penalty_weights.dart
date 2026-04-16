class PenaltyWeights {
  /// 休みや入っている人が全く同じ場合のペナルティ
  static const double identicalSelectionPenalty = 10000000.0;

  /// 連続休み関連のペナルティ
  static const double consecutiveRestPenalty = 1000000.0;
  static const double lastTimeRestedGain = 100000.0;

  /// 一緒に休みになった回数に基づくペナルティ（優先度は連続休みより低く、種目より高い位置に設定）
  static const double restTogether = 10000.0;
  static const double restTogetherMaxBonus = 20000.0;

  /// 種目ペナルティ
  static const double typeImbalance = 1000.0;
  static const double sameTypeAsPrevious = 500.0;

  /// ペア回数ペナルティ
  static const double pairRepeat = 100.0;

  /// 敵対回数ペナルティ
  static const double opponentRepeat = 10.0;
}
