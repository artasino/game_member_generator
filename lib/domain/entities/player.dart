import 'package:equatable/equatable.dart';

import 'gender.dart';

/// プレイヤーの情報を保持するクラス
class Player extends Equatable {
  final String id;
  final String name;
  final String yomigana;
  final Gender gender;
  final bool isActive;
  final bool isMustRest;

  /// the flag for excluded partner(they can't be in session together, e.g. for childcare)
  final String? excludedPartnerId;

  const Player({
    required this.id,
    required this.name,
    required this.yomigana,
    required this.gender,
    this.isActive = true,
    this.isMustRest = false,
    this.excludedPartnerId,
  });

  Player copyWith({
    String? id,
    String? name,
    String? yomigana,
    Gender? gender,
    bool? isActive,
    bool? isMustRest,
    String? excludedPartnerId,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      yomigana: yomigana ?? this.yomigana,
      gender: gender ?? this.gender,
      isActive: isActive ?? this.isActive,
      isMustRest: isMustRest ?? this.isMustRest,
      excludedPartnerId: excludedPartnerId ?? this.excludedPartnerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'yomigana': yomigana,
      'gender': gender.index,
      'isActive': isActive ? 1 : 0,
      'isMustRest': isMustRest ? 1 : 0,
      'excludedPartnerId': excludedPartnerId,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    final genderValue = json['gender'];
    final isActiveValue = json['isActive'];
    final isMustRestValue = json['isMustRest'];

    int parseGender(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool parseBool(dynamic value, {required bool defaultValue}) {
      if (value is bool) return value;
      if (value is int) return value == 1;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == '1' || normalized == 'true') return true;
        if (normalized == '0' || normalized == 'false') return false;
      }
      return defaultValue;
    }

    final parsedGenderIndex = parseGender(genderValue);
    final safeGenderIndex = (parsedGenderIndex >= 0 &&
            parsedGenderIndex < Gender.values.length)
        ? parsedGenderIndex
        : 0;

    return Player(
      id: json['id'],
      name: json['name'],
      yomigana: json['yomigana'] ?? '',
      gender: Gender.values[safeGenderIndex],
      isActive: parseBool(isActiveValue, defaultValue: true),
      isMustRest: parseBool(isMustRestValue, defaultValue: false),
      excludedPartnerId: json['excludedPartnerId'],
    );
  }

  @override
  List<Object?> get props =>
      [id, name, gender, isActive, isMustRest, excludedPartnerId];
}
