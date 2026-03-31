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
}
