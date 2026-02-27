import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static void initFfi() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'game_member_generator.db');
    return await openDatabase(
      path,
      version: 2, // バージョンを上げてマイグレーション
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE players(
            id TEXT PRIMARY KEY,
            name TEXT,
            yomigana TEXT,
            gender INTEGER,
            isActive INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY,
            content TEXT
          )
        ''');
        // 設定用テーブル
        await db.execute('''
          CREATE TABLE settings(
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE settings(
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
          // 既存のsessionsテーブルに混じっている設定データを削除
          await db.delete('sessions', where: 'id = ?', whereArgs: [-1]);
        }
      },
    );
  }
}
