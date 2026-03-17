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
      version: 4, // バージョンを 4 に上げました
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE players(
            id TEXT PRIMARY KEY,
            name TEXT,
            yomigana TEXT,
            gender INTEGER,
            isActive INTEGER,
            isMustRest INTEGER DEFAULT 0,
            excludedPartnerId TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY,
            content TEXT
          )
        ''');
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
          await db.delete('sessions', where: 'id = ?', whereArgs: [-1]);
        }
        if (oldVersion < 3) {
          // playersテーブルに isMustRest カラムを追加
          await db.execute(
              'ALTER TABLE players ADD COLUMN isMustRest INTEGER DEFAULT 0');
        }
        if (oldVersion < 4) {
          // playersテーブルに excludedPartnerId カラムを追加
          await db
              .execute('ALTER TABLE players ADD COLUMN excludedPartnerId TEXT');
        }
      },
    );
  }
}
