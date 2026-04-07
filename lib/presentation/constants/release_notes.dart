class ReleaseNote {
  const ReleaseNote({
    required this.version,
    required this.changes,
  });

  final String version;
  final List<String> changes;
}

const List<ReleaseNote> releaseNotes = [
  ReleaseNote(
    version: '1.0.0',
    changes: ['初回リリース'],
  ),
];
