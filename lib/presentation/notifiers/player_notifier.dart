import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/player.dart';
import '../../domain/repository/player_repository/player_repository.dart';
import 'session_notifier.dart';

class PlayerNotifier extends ChangeNotifier {
  final PlayerRepository repository;
  List<Player> _players = [];
  SessionNotifier? _sessionNotifier;

  PlayerNotifier(this.repository);

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

  Future<bool> addPlayer(Player player) async {
    await _refresh(); // 最新状態を確保
    if (_exists(player)) {
      return false; // 重複のため追加失敗
    }
    await repository.add(player);
    await _refresh();
    return true;
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

  /// クリップボードにJSONをエクスポート
  Future<void> exportPlayersToClipboard() async {
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

      final List<dynamic> decoded = jsonDecode(data.text!);
      return await _importFromList(decoded);
    } catch (e) {
      return 'インポートに失敗しました: 無効な形式です';
    }
  }

  /// ファイル(JSON/CSV)をエクスポート
  Future<void> exportPlayersToFile(String format) async {
    String content = '';
    String extension = format == 'json' ? 'json' : 'csv';
    String fileName =
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
      content = const ListToCsvConverter().convert(rows);
    }

    if (!kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '保存先を選択してください',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [extension],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.$extension')) {
          outputFile = '$outputFile.$extension';
        }
        final file = File(outputFile);
        await file.writeAsString(content);
      }
    } else {
      await Share.shareXFiles([
        XFile.fromData(
          utf8.encode(content),
          name: fileName,
          mimeType: format == 'json' ? 'application/json' : 'text/csv',
        )
      ]);
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
        final List<dynamic> decoded = jsonDecode(content);
        return await _importFromList(decoded);
      } else if (extension == 'csv') {
        final List<List<dynamic>> rows =
            const CsvToListConverter().convert(content);
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
      try {
        final player = Player.fromJson(item as Map<String, dynamic>);
        
        // ID一致チェック
        final existingById = _players.any((p) => p.id == player.id);
        if (existingById) {
          await repository.update(player);
          count++;
          continue;
        }

        // 名前と性別一致チェック (Playerクラスでオーバーライドした == を利用)
        if (_exists(player)) {
          skipCount++;
          continue;
        }

        await repository.add(player);
        count++;
        // 連続追加時にリストを更新しておく
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
