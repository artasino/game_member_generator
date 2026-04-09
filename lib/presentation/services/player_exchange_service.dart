import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/player.dart';

class PlayerExchangeService {
  /// クリップボードにJSONをエクスポート
  Future<void> exportToClipboard(List<Player> players) async {
    if (players.isEmpty) return;
    try {
      final jsonString = jsonEncode(players.map((p) => p.toJson()).toList());
      await Clipboard.setData(ClipboardData(text: jsonString));
    } catch (error, stackTrace) {
      _debugLogError('exportToClipboard', error, stackTrace);
      rethrow;
    }
  }

  /// クリップボードからJSONをパース
  Future<List<Player>?> importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data == null || data.text == null || data.text!.isEmpty) return null;

    try {
      final decoded = jsonDecode(data.text!);
      if (decoded is List) {
        return decoded
            .map(
              (item) => Player.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      }
      debugPrint(
        '[PlayerExchangeService] importFromClipboard: decoded JSON is not a List.',
      );
    } catch (error, stackTrace) {
      _debugLogError('importFromClipboard', error, stackTrace);
    }
    return null;
  }

  /// ファイル(JSON/CSV)をエクスポート
  Future<void> exportToFile(List<Player> players, String format) async {
    if (players.isEmpty) return;
    try {
      final String extension = format == 'json' ? 'json' : 'csv';
      final String fileName =
          'players_${DateTime.now().millisecondsSinceEpoch}.$extension';
      String content = '';

      if (format == 'json') {
        content = jsonEncode(players.map((p) => p.toJson()).toList());
      } else {
        final List<List<dynamic>> rows = [
          [
            'id',
            'name',
            'yomigana',
            'gender',
            'isActive',
            'isMustRest',
            'excludedPartnerId'
          ]
        ];
        for (var p in players) {
          rows.add([
            p.id,
            p.name,
            p.yomigana,
            p.gender.index,
            p.isActive ? 1 : 0,
            p.isMustRest ? 1 : 0,
            p.excludedPartnerId ?? '',
          ]);
        }
        content = CsvCodec().encode(rows);
      }

      if (!kIsWeb &&
          (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
        final String? outputFile = await FilePicker.saveFile(
          dialogTitle: '保存先を選択してください',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [extension],
        );

        if (outputFile == null) {
          debugPrint(
            '[PlayerExchangeService] exportToFile: save dialog was canceled.',
          );
          return;
        }

        String finalPath = outputFile;
        if (!outputFile.toLowerCase().endsWith('.$extension')) {
          finalPath = '$outputFile.$extension';
        }
        await File(finalPath).writeAsString(content);
      } else {
        final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              name: fileName,
              mimeType: format == 'json' ? 'application/json' : 'text/csv',
            ),
          ],
        );
      }
    } catch (error, stackTrace) {
      _debugLogError('exportToFile', error, stackTrace);
      rethrow;
    }
  }

  /// ファイルからインポート
  Future<List<Player>?> importFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint(
          '[PlayerExchangeService] importFromFile: picker canceled or no file selected.',
        );
        return null;
      }

      final file = result.files.first;
      final extension = file.extension?.toLowerCase();
      final String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (!kIsWeb && file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        debugPrint(
          '[PlayerExchangeService] importFromFile: file bytes/path unavailable.'
          ' extension=$extension, name=${file.name}, size=${file.size}',
        );
        return null;
      }
      final players =
          parsePlayersForImport(content: content, extension: extension);
      if (players == null) {
        debugPrint(
          '[PlayerExchangeService] importFromFile: failed to parse file.'
          ' extension=$extension, name=${file.name}, size=${file.size}',
        );
      }
      return players;
    } catch (error, stackTrace) {
      _debugLogError('importFromFile', error, stackTrace);
    }
    return null;
  }

  @visibleForTesting
  List<Player>? parsePlayersForImport({
    required String content,
    String? extension,
  }) {
    // Web では拡張子が取れないケースがあるため、JSON/CSV を順にフォールバック判定する
    final normalized = _removeUtf8Bom(content);

    if (extension == 'json' || extension == null || extension.isEmpty) {
      final jsonPlayers = _parseJsonPlayers(normalized);
      if (jsonPlayers != null) return jsonPlayers;
    }

    if (extension == 'csv' || extension == null || extension.isEmpty) {
      return _parseCsvPlayers(normalized);
    }

    return null;
  }

  List<Player>? _parseJsonPlayers(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        debugPrint(
          '[PlayerExchangeService] _parseJsonPlayers: decoded JSON is not a List.',
        );
        return null;
      }
      return decoded
          .map(
            (item) => Player.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (error, stackTrace) {
      _debugLogError('_parseJsonPlayers', error, stackTrace);
      return null;
    }
  }

  List<Player>? _parseCsvPlayers(String content) {
    try {
      final List<List<dynamic>> rows = CsvCodec().decode(content);
      if (rows.length <= 1) {
        debugPrint(
          '[PlayerExchangeService] _parseCsvPlayers: CSV has no data rows.',
        );
        return null;
      }

      return rows.sublist(1).map((row) {
        return Player(
          id: row[0].toString(),
          name: row[1].toString(),
          yomigana: row[2].toString(),
          gender: Gender.values[int.tryParse(row[3].toString()) ?? 0],
          isActive: (int.tryParse(row[4].toString()) ?? 1) == 1,
          isMustRest: (int.tryParse(row[5].toString()) ?? 0) == 1,
          excludedPartnerId: row.length > 6 && row[6].toString().isNotEmpty
              ? row[6].toString()
              : null,
        );
      }).toList();
    } catch (error, stackTrace) {
      _debugLogError('_parseCsvPlayers', error, stackTrace);
      return null;
    }
  }

  String _removeUtf8Bom(String content) {
    if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
      return content.substring(1);
    }
    return content;
  }

  void _debugLogError(
    String context,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('[PlayerExchangeService] $context error: $error');
    debugPrint(stackTrace.toString());
  }
}
