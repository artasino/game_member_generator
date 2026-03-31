import 'package:equatable/equatable.dart';

class ShuttleStock extends Equatable {
  final int? id;
  final String name;
  final double pricePerDozens;
  final String? payerId;
  final DateTime purchaseDate;

  const ShuttleStock({
    this.id,
    required this.name,
    required this.pricePerDozens,
    this.payerId,
    required this.purchaseDate,
  });

  @override
  List<Object?> get props => [id, name, pricePerDozens, payerId, purchaseDate];

  ShuttleStock copyWith({
    int? id,
    String? name,
    double? pricePerDozens,
    String? payerId,
    DateTime? purchaseDate,
  }) {
    return ShuttleStock(
      id: id ?? this.id,
      name: name ?? this.name,
      pricePerDozens: pricePerDozens ?? this.pricePerDozens,
      payerId: payerId ?? this.payerId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price_per_dozens': pricePerDozens,
      'payer_id': payerId,
      'purchase_date': purchaseDate.toIso8601String(),
    };
  }

  factory ShuttleStock.fromJson(Map<String, dynamic> json) {
    return ShuttleStock(
      id: json['id'] as int?,
      name: json['name'] as String,
      pricePerDozens: (json['price_per_dozens'] as num).toDouble(),
      payerId: json['payer_id'] as String?,
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
    );
  }
}
