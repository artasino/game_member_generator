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
    version: '2.1.0',
    changes: [
      'バージョン情報を端末のアプリ情報から自動表示するよう改善',
      '「バージョン」項目からアップデート履歴を確認できる画面を追加',
    ],
  ),
  ReleaseNote(
    version: '2.0.0',
    changes: [
      'メニュー構成を見直し、その他画面の導線を整理',
      'マニュアル導線の改善と軽微な表示調整',
    ],
  ),
  ReleaseNote(
    version: '1.0.0',
    changes: [
      '初回リリース',
    ],
  ),
];
