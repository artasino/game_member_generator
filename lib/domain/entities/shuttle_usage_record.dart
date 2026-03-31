import 'dart:convert';

import 'package:equatable/equatable.dart';

import 'match_type.dart';

class ShuttleUsageRecord extends Equatable {
  final int? id;
  final DateTime date;
  final int totalShuttles;
  final Map<MatchType, int> matchTypeCounts;

  const ShuttleUsageRecord({
    this.id,
    required this.date,
    required this.totalShuttles,
    required this.matchTypeCounts,
  });

  @override
  List<Object?> get props => [id, date, totalShuttles, matchTypeCounts];

  Map<String, dynamic> toJson() {
    final matchCountsJson = jsonEncode(
      matchTypeCounts.map((key, value) => MapEntry(key.name, value)),
    );
    return {
      if (id != null) 'id': id,
      'date': date.toIso8601String(),
      'total_shuttles': totalShuttles,
      'match_counts': matchCountsJson,
    };
  }

  factory ShuttleUsageRecord.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> countsMap =
        jsonDecode(json['match_counts'] as String);
    final matchTypeCounts = countsMap.map((key, value) {
      final matchType = MatchType.values.firstWhere((e) => e.name == key);
      return MapEntry(matchType, value as int);
    });

    return ShuttleUsageRecord(
      id: json['id'] as int?,
      date: DateTime.parse(json['date'] as String),
      totalShuttles: json['total_shuttles'] as int,
      matchTypeCounts: matchTypeCounts,
    );
  }
}
