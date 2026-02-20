import 'gender.dart';

class Player {
  final String id;
  final String name;
  final Gender gender;

  const Player({
    required this.id,
    required this.name,
    required this.gender,
});
}