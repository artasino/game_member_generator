import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/session.dart';
import '../../domain/repository/session_repository/session_history_repository.dart';
import 'database_helper.dart';

class SqliteSessionHistoryRepository implements SessionHistoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<List<Session>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('sessions', orderBy: 'id ASC');
    return maps.map((map) {
      return Session.fromJson(jsonDecode(map['content']));
    }).toList();
  }

  @override
  Future<void> add(Session session) async {
    final db = await _dbHelper.database;
    await db.insert(
      'sessions',
      {
        'id': session.index,
        'content': jsonEncode(session.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Session session) async {
    final db = await _dbHelper.database;
    await db.update(
      'sessions',
      {
        'content': jsonEncode(session.toJson()),
      },
      where: 'id = ?',
      whereArgs: [session.index],
    );
  }

  @override
  Future<void> clear() async {
    final db = await _dbHelper.database;
    await db.delete('sessions');
  }
}
