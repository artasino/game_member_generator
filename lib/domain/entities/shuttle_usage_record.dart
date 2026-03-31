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
}
