import 'gender.dart';

class Player {
  final String id;
  final String name;
  final String yomigana; // 追加
  final Gender gender;
  final bool isActive;

  const Player({
    required this.id,
    required this.name,
    required this.gender,
    this.isActive = true,
    this.yomigana="#", // 追加
  });

  Player copyWith({
    String? id,
    String? name,
    String? yomigana,
    Gender? gender,
    bool? isActive,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      yomigana: yomigana ?? this.yomigana,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
    );
  }
}
