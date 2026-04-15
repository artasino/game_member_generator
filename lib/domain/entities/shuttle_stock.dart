import 'package:equatable/equatable.dart';

class ShuttleStock extends Equatable {
  final int? id;
  final String name;
  final double unitPrice;
  final bool isPerDozen;
  final String? payerId;
  final DateTime purchaseDate;

  const ShuttleStock({
    this.id,
    required this.name,
    required this.unitPrice,
    this.isPerDozen = true,
    this.payerId,
    required this.purchaseDate,
  });

  double get pricePerDozens => isPerDozen ? unitPrice : unitPrice * 12;

  double get pricePerPiece => isPerDozen ? unitPrice / 12 : unitPrice;

  @override
  List<Object?> get props =>
      [id, name, unitPrice, isPerDozen, payerId, purchaseDate];

  ShuttleStock copyWith({
    int? id,
    String? name,
    double? unitPrice,
    bool? isPerDozen,
    String? payerId,
    DateTime? purchaseDate,
  }) {
    return ShuttleStock(
      id: id ?? this.id,
      name: name ?? this.name,
      unitPrice: unitPrice ?? this.unitPrice,
      isPerDozen: isPerDozen ?? this.isPerDozen,
      payerId: payerId ?? this.payerId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'unit_price': unitPrice,
      'is_per_dozen': isPerDozen ? 1 : 0,
      'payer_id': payerId,
      'purchase_date': purchaseDate.toIso8601String(),
    };
  }

  factory ShuttleStock.fromJson(Map<String, dynamic> json) {
    // Handle old format where unit_price was price_per_dozens
    final double price =
        (json['unit_price'] ?? json['price_per_dozens'] as num).toDouble();
    return ShuttleStock(
      id: json['id'] as int?,
      name: json['name'] as String,
      unitPrice: price,
      isPerDozen: (json['is_per_dozen'] as int? ?? 1) == 1,
      payerId: json['payer_id'] as String?,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
    );
  }
}
