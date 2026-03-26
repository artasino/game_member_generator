import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';
import 'session_notifier.dart';

class PlayerNotifier extends ChangeNotifier {
  final PlayerRepository repository;
  List<Player> _players = [];
  SessionNotifier? _sessionNotifier;

  PlayerNotifier(this.repository) {
    _refresh(); // 初期化時にデータを読み込む
  }

  void setSessionNotifier(SessionNotifier notifier) {
    _sessionNotifier = notifier;
  }

  List<Player> get players => _players;

  Future<void> _refresh() async {
    _players = await repository.getAll();
    notifyListeners();
    await _sessionNotifier?.onPlayersUpdated();
  }

  /// 名前と性別が一致するプレイヤーが既に存在するかチェック
  bool _exists(Player player) {
    return _players.contains(player);
  }

  String? getPlayerNameById(String id) {
    final player = _players.firstWhereOrNull((p) => p.id == id);
    if (player == null) {
      return null;
    }
    return player.name;
  }

  Future<bool> addPlayer(Player player) async {
    await _refresh(); // 最新状態を確保
    if (_exists(player)) {
      return false; // 重複のため追加失敗
    }
    await repository.add(player);
    await _refresh();
    return true;
  }

  Future<(int added, int skipped)> addPlayersBulk(List<Player> players) async {
    await _refresh();
    int added = 0;
    int skipped = 0;

    for (final player in players) {
      final existingById = _players.any((p) => p.id == player.id);
      if (existingById || _exists(player)) {
        skipped++;
        continue;
      }
      await repository.add(player);
      _players.add(player);
      added++;
    }

    await _refresh();
    return (added, skipped);
  }

  Future<void> updatePlayer(Player player) async {
    await repository.update(player);
    await _refresh();
  }

  Future<void> toggleActive(Player player) async {
    final updated = player.copyWith(isActive: !player.isActive);
    await repository.update(updated);
    await _refresh();
  }

  Future<void> removePlayer(String id) async {
    await repository.remove(id);
    await _refresh();
  }

  Future<int> removePlayersBulk(List<String> ids) async {
    int removed = 0;
    for (final id in ids.toSet()) {
      await repository.remove(id);
      removed++;
    }
    await _refresh();
    return removed;
  }

  // --- 汎用的な一括更新メソッド（内部用） ---
  Future<void> _updatePlayers(List<Player> updatedList) async {
    for (var p in updatedList) {
      await repository.update(p);
    }
    await _refresh();
  }

  Future<void> linkPartner(String playerId, String partnerId) async {
    final player = _players.firstWhereOrNull((p) => p.id == playerId);
    final partner = _players.firstWhereOrNull((p) => p.id == partnerId);

    if (player == null || partner == null) return;

    final List<Player> targets = [];

    // 1. 以前のペア相手がいたら、その人の紐付けを解除しておく（お掃除）
    final oldPartnerA =
        _players.firstWhereOrNull((p) => p.excludedPartnerId == player.id);
    if (oldPartnerA != null && oldPartnerA.id != partnerId) {
      targets.add(oldPartnerA.copyWith(excludedPartnerId: null));
    }
    final oldPartnerB =
        _players.firstWhereOrNull((p) => p.excludedPartnerId == partner.id);
    if (oldPartnerB != null && oldPartnerB.id != playerId) {
      targets.add(oldPartnerB.copyWith(excludedPartnerId: null));
    }

    // 2. 新しいペアをセット
    targets.add(player.copyWith(excludedPartnerId: partner.id));
    targets.add(partner.copyWith(excludedPartnerId: player.id));

    await _updatePlayers(targets);
  }

  Future<void> unlinkPartner(String playerId) async {
    final player = _players.firstWhereOrNull((p) => p.id == playerId);
    if (player == null) return;

    final List<Player> targets = [];

    // 本人の解除
    targets.add(player.copyWith(excludedPartnerId: null));

    // 相手側の解除
    final partner =
        _players.firstWhereOrNull((p) => p.id == player.excludedPartnerId);
    if (partner != null) {
      targets.add(partner.copyWith(excludedPartnerId: null));
    }

    await _updatePlayers(targets);
  }

  /// クリップボードにJSONをエクスポート
  Future<void> exportPlayersToClipboard() async {
    await _refresh(); // エクスポート前に必ず最新化
    if (_players.isEmpty) return; // データがなければ何もしない

    final List<Map<String, dynamic>> jsonList =
        _players.map((p) => p.toJson()).toList();
    final String jsonString = jsonEncode(jsonList);
    await Clipboard.setData(ClipboardData(text: jsonString));
  }

  /// クリップボードからインポート
  Future<String> importPlayersFromClipboard() async {
    try {
      final ClipboardData? data = await Clipboard.getData('text/plain');
      if (data == null || data.text == null || data.text!.isEmpty) {
        return 'クリップボードが空です';
      }

      final dynamic decoded = jsonDecode(data.text!);
      if (decoded is List) {
        return await _importFromList(decoded);
      }
      return 'インポートに失敗しました: 無効な形式です';
    } catch (e) {
      return 'インポートに失敗しました: 無効な形式です';
    }
  }

  /// ファイル(JSON/CSV)をエクスポート
  Future<void> exportPlayersToFile(String format) async {
    await _refresh(); // エクスポート前に必ず最新化
    if (_players.isEmpty) return; // データがなければ何もしない

    String content = '';
    final String extension = format == 'json' ? 'json' : 'csv';
    final String fileName =
        'players_${DateTime.now().millisecondsSinceEpoch}.$extension';

    if (format == 'json') {
      content = jsonEncode(_players.map((p) => p.toJson()).toList());
    } else {
      final List<List<dynamic>> rows = [
        ['id', 'name', 'yomigana', 'gender', 'isActive', 'isMustRest']
      ];
      for (var p in _players) {
        rows.add([
          p.id,
          p.name,
          p.yomigana,
          p.gender.index,
          p.isActive ? 1 : 0,
          p.isMustRest ? 1 : 0,
        ]);
      }
      content = CsvCodec().encode(rows);
    }

    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      // デスクトップ環境
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '保存先を選択してください',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [extension],
      );

      if (outputFile != null) {
        String finalPath = outputFile;
        if (!outputFile.toLowerCase().endsWith('.$extension')) {
          finalPath = '$outputFile.$extension';
        }
        final file = File(finalPath);
        await file.writeAsString(content);
      }
    } else {
      // モバイル環境
      final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              name: fileName,
              mimeType: format == 'json' ? 'application/json' : 'text/csv',
            ),
          ],
        ),
      );
    }
  }

  /// ファイルからインポート
  Future<String> importPlayersFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
      );

      if (result == null || result.files.isEmpty) return 'ファイルが選択されませんでした';

      final file = result.files.first;
      final extension = file.extension?.toLowerCase();

      String content = '';
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }

      if (extension == 'json') {
        final dynamic decoded = jsonDecode(content);
        if (decoded is List) {
          return await _importFromList(decoded);
        }
      } else if (extension == 'csv') {
        final List<List<dynamic>> rows = CsvCodec().decode(content);
        if (rows.length <= 1) return 'CSVデータが空か無効です';

        final dataRows = rows.sublist(1);
        final List<Map<String, dynamic>> jsonList = [];
        for (var row in dataRows) {
          if (row.length < 4) continue;
          jsonList.add({
            'id': row[0].toString(),
            'name': row[1].toString(),
            'yomigana': row[2].toString(),
            'gender': int.tryParse(row[3].toString()) ?? 0,
            'isActive': (int.tryParse(row[4].toString()) ?? 1) == 1 ? 1 : 0,
            'isMustRest': (int.tryParse(row[5].toString()) ?? 0) == 1 ? 1 : 0,
          });
        }
        return await _importFromList(jsonList);
      }
      return '対応していないファイル形式です';
    } catch (e) {
      return 'インポート中にエラーが発生しました: $e';
    }
  }

  Future<String> _importFromList(List<dynamic> list) async {
    await _refresh();
    int count = 0;
    int skipCount = 0;
    for (var item in list) {
      if (item is! Map<String, dynamic>) continue;
      try {
        final player = Player.fromJson(item);

        final existingById = _players.any((p) => p.id == player.id);
        if (existingById) {
          await repository.update(player);
          count++;
          continue;
        }

        if (_exists(player)) {
          skipCount++;
          continue;
        }

        await repository.add(player);
        count++;
        _players.add(player);
      } catch (_) {}
    }
    await _refresh();
    String msg = '$count名のメンバをインポートしました';
    if (skipCount > 0) {
      msg += ' ($skipCount名は重複のためスキップ)';
    }
    return msg;
  }
}
