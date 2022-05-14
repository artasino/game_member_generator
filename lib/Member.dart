import 'package:flutter/material.dart';
import 'package:game_member_generator/Gender.dart';

class Member implements Comparable<Member> {
  final String name;
  final Gender gender;

  Member({
    required this.name,
    required this.gender,
  });

  Icon getGenderIcon() {
    if (gender == Gender.male) {
      return const Icon(Icons.male, color: Colors.blue);
    } else {
      return const Icon(Icons.female, color: Colors.pink);
    }
  }

  Map toJson() => {
        "name": name,
        "gender": gender.name,
      };

  Member.fromJson(Map json)
      : name = json["name"],
        gender = stringToGender(json["gender"]);

  @override
  int compareTo(Member member) {
    if (name == member.name && gender == member.gender) {
      return 0;
    }
    return name.compareTo(member.name);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          gender == other.gender;

  @override
  int get hashCode => name.hashCode ^ gender.hashCode;

  @override
  String toString() {
    return 'Member{name: $name, gender: $gender}';
  }
}
