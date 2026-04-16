class ReleaseNote {
  const ReleaseNote({
    required this.version,
    required this.date,
    required this.changes,
  });

  final String version;
  final String date;
  final List<String> changes;

  factory ReleaseNote.fromJson(Map<String, dynamic> json) {
    return ReleaseNote(
      version: json['version'] as String,
      date: json['date'] as String,
      changes: List<String>.from(json['changes'] as List),
    );
  }
}
