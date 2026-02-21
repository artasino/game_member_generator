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
}