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
  final List<MatchType> matchTypes;
  final int autoCourtCount;
  final AutoCourtPolicy autoCourtPolicy;
  final bool isAutoRecommendMode;

  const CourtSettings(
    this.matchTypes, {
    this.autoCourtCount = 3,
    this.autoCourtPolicy = AutoCourtPolicy.balance,
    this.isAutoRecommendMode = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'matchTypes': matchTypes.map((t) => t.index).toList(),
      'autoCourtCount': autoCourtCount,
      'autoCourtPolicy': autoCourtPolicy.index,
      'isAutoRecommendMode': isAutoRecommendMode,
    };
  }

  factory CourtSettings.fromJson(dynamic json) {
    if (json is List<dynamic>) {
      // 旧形式互換: matchTypes のみを List で保存していた過去データを読み込む
      return CourtSettings(
        json.map((t) => MatchType.values[t as int]).toList(),
      );
    }

    final Map<String, dynamic> map = json as Map<String, dynamic>;
    final types = (map['matchTypes'] as List<dynamic>? ?? [])
        .map((t) => MatchType.values[t as int])
        .toList();

    return CourtSettings(
      types.isEmpty ? [MatchType.menDoubles] : types,
      autoCourtCount: (map['autoCourtCount'] as int?) ?? 3,
      autoCourtPolicy: AutoCourtPolicy
          .values[(map['autoCourtPolicy'] as int?) ?? AutoCourtPolicy.balance.index],
      isAutoRecommendMode: (map['isAutoRecommendMode'] as bool?) ?? false,
    );
  }

  CourtSettings copyWith({
    List<MatchType>? matchTypes,
    int? autoCourtCount,
    AutoCourtPolicy? autoCourtPolicy,
    bool? isAutoRecommendMode,
  }) {
    return CourtSettings(
      matchTypes ?? this.matchTypes,
      autoCourtCount: autoCourtCount ?? this.autoCourtCount,
      autoCourtPolicy: autoCourtPolicy ?? this.autoCourtPolicy,
      isAutoRecommendMode: isAutoRecommendMode ?? this.isAutoRecommendMode,
    );
  }
}
