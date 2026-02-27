import 'gender.dart';

class Player {
  final String id;
  final String name;
  final String yomigana;
  final Gender gender;
  final bool isActive;

  const Player({
    required this.id,
    required this.name,
    required this.yomigana,
    required this.gender,
    this.isActive = true,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'yomigana': yomigana,
      'gender': gender.index,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'],
      name: json['name'],
      yomigana: json['yomigana'] ?? '',
      gender: Gender.values[json['gender']],
      isActive: json['isActive'] == 1,
    );
  }
}
