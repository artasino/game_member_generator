import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferencesのキー変更時に、旧キーから新キーへ値を引き継ぐためのヘルパー。
class SharedPreferencesKeyMigrator {
  static Future<String?> readStringWithMigration(
    SharedPreferences prefs, {
    required String currentKey,
    List<String> legacyKeys = const [],
  }) async {
    final currentValue = prefs.getString(currentKey);
    if (currentValue != null && currentValue.isNotEmpty) {
      return currentValue;
    }

    for (final legacyKey in legacyKeys) {
      final legacyValue = prefs.getString(legacyKey);
      if (legacyValue == null || legacyValue.isEmpty) continue;

      // 新しいキーへデータを移行
      await prefs.setString(currentKey, legacyValue);
      // 移行が完了したら、古いキーは削除して二重持ちを防止する
      await prefs.remove(legacyKey);

      return legacyValue;
    }

    return null;
  }
}
