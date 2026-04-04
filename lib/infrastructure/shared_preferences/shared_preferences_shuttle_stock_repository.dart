import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/shuttle_stock.dart';
import '../../domain/repository/shuttle_stock_repository.dart';
import 'shared_preferences_key_migrator.dart';

class SharedPreferencesShuttleStockRepository
    implements ShuttleStockRepository {
  static const String _key = 'gmg.shuttle_stocks.v1';
  static const List<String> _legacyKeys = ['shuttle_stocks'];

  @override
  Future<void> save(ShuttleStock stock) async {
    final stocks = await getAll();
    if (stock.id != null) {
      final index = stocks.indexWhere((s) => s.id == stock.id);
      if (index != -1) {
        stocks[index] = stock;
      } else {
        stocks.add(stock);
      }
    } else {
      final newId = stocks.isEmpty
          ? 1
          : stocks.map((s) => s.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      stocks.add(stock.copyWith(id: newId));
    }
    await _saveAll(stocks);
  }

  @override
  Future<List<ShuttleStock>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = await SharedPreferencesKeyMigrator.readStringWithMigration(
      prefs,
      currentKey: _key,
      legacyKeys: _legacyKeys,
    );
    if (jsonString == null) return [];
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded
        .map((item) => ShuttleStock.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> delete(int id) async {
    final stocks = await getAll();
    stocks.removeWhere((s) => s.id == id);
    await _saveAll(stocks);
  }

  Future<void> _saveAll(List<ShuttleStock> stocks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(stocks.map((s) => s.toJson()).toList()));
  }
}
