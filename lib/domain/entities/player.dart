import 'gender.dart';

class Player {
  final String id;
  final String name;
  final Gender gender;
  final bool isActive;

  const Player({
    required this.id,
    required this.name,
    required this.gender,
    this.isActive = true,
  });

  Player copyWith({
    String? id,
    String? name,
    Gender? gender,
    bool? isActive,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
    );
  }
}
