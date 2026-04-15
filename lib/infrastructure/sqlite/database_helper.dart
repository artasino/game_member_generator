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
      version: 7, // バージョンを 7 に上げました (在庫の単位対応)
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
        await db.execute('''
          CREATE TABLE shuttle_usage(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            total_shuttles INTEGER,
            match_counts TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE shuttle_stocks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            unit_price REAL,
            is_per_dozen INTEGER DEFAULT 1,
            payer_id TEXT,
            purchase_date TEXT,
            price_per_dozens REAL -- 互換性のため残す
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
          await db.execute(
              'ALTER TABLE players ADD COLUMN isMustRest INTEGER DEFAULT 0');
        }
        if (oldVersion < 4) {
          await db
              .execute('ALTER TABLE players ADD COLUMN excludedPartnerId TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE shuttle_usage(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT,
              total_shuttles INTEGER,
              match_counts TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE shuttle_stocks(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              price_per_dozens REAL,
              payer_id TEXT,
              purchase_date TEXT
            )
          ''');
        }
        if (oldVersion < 7) {
          try {
            await db.execute(
                'ALTER TABLE shuttle_stocks ADD COLUMN unit_price REAL');
            await db.execute(
                'ALTER TABLE shuttle_stocks ADD COLUMN is_per_dozen INTEGER DEFAULT 1');
            // 既存のデータを移行
            await db.execute(
                'UPDATE shuttle_stocks SET unit_price = price_per_dozens');
          } catch (e) {
            // カラムが既に存在する場合などのエラーを無視
          }
        }
      },
    );
  }
}
