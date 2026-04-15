import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum ExpenseType {
  shuttle('消耗品', Symbols.badminton, Colors.orange),
  court('場所代', Icons.stadium, Colors.blue),
  other('その他', Icons.more_horiz, Colors.teal);

  final String label;
  final IconData icon;
  final Color color;

  const ExpenseType(this.label, this.icon, this.color);
}

enum SplitTarget {
  all('全員'),
  male('男子'),
  female('女子');

  final String label;

  const SplitTarget(this.label);
}

class ExpenseEntry {
  String name;
  ExpenseType type;
  double amount;
  double unitPrice;
  bool isPerDozen;
  int shuttleCount;
  String? payerId;
  SplitTarget target;

  ExpenseEntry({
    required this.name,
    required this.type,
    this.amount = 0,
    this.unitPrice = 0,
    this.isPerDozen = true,
    this.shuttleCount = 0,
    this.payerId,
    this.target = SplitTarget.all,
  });

  double get total {
    if (type == ExpenseType.shuttle) {
      if (isPerDozen) {
        return (unitPrice / 12) * shuttleCount;
      } else {
        return unitPrice * shuttleCount;
      }
    }
    return amount;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.index,
      'amount': amount,
      'unitPrice': unitPrice,
      'isPerDozen': isPerDozen,
      'shuttleCount': shuttleCount,
      'payerId': payerId,
      'target': target.index,
    };
  }

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      name: json['name'] as String,
      type: ExpenseType.values[json['type'] as int],
      amount: (json['amount'] as num).toDouble(),
      unitPrice:
          (json['unitPrice'] ?? json['pricePerDozens'] as num).toDouble(),
      isPerDozen: json['isPerDozen'] as bool? ?? true,
      shuttleCount: json['shuttleCount'] as int,
      payerId: json['payerId'] as String?,
      target: SplitTarget.values[json['target'] as int? ?? 0],
    );
  }
}

class ExpenseCalculationState {
  final List<ExpenseEntry> entries;
  final bool useGenderSplit;
  final int? manualMaleCollection;
  final int? manualFemaleCollection;

  const ExpenseCalculationState({
    required this.entries,
    required this.useGenderSplit,
    this.manualMaleCollection,
    this.manualFemaleCollection,
  });

  Map<String, dynamic> toJson() {
    return {
      'entries': entries.map((e) => e.toJson()).toList(),
      'useGenderSplit': useGenderSplit,
      'manualMaleCollection': manualMaleCollection,
      'manualFemaleCollection': manualFemaleCollection,
    };
  }

  factory ExpenseCalculationState.fromJson(Map<String, dynamic> json) {
    return ExpenseCalculationState(
      entries: (json['entries'] as List<dynamic>)
          .map((e) => ExpenseEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      useGenderSplit: json['useGenderSplit'] as bool? ?? false,
      manualMaleCollection: json['manualMaleCollection'] as int?,
      manualFemaleCollection: json['manualFemaleCollection'] as int?,
    );
  }

  ExpenseCalculationState copyWith({
    List<ExpenseEntry>? entries,
    bool? useGenderSplit,
    int? manualMaleCollection,
    int? manualFemaleCollection,
  }) {
    return ExpenseCalculationState(
      entries: entries ?? this.entries,
      useGenderSplit: useGenderSplit ?? this.useGenderSplit,
      manualMaleCollection: manualMaleCollection ?? this.manualMaleCollection,
      manualFemaleCollection:
          manualFemaleCollection ?? this.manualFemaleCollection,
    );
  }
}
