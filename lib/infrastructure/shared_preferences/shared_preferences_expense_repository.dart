import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/expense_item.dart';
import '../../domain/repository/expense_repository.dart';

class SharedPreferencesExpenseRepository implements ExpenseRepository {
  static const String _key = 'expense_calculation_state';

  @override
  Future<ExpenseCalculationState?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null) return null;

    try {
      final dynamic decoded = jsonDecode(jsonString);
      return ExpenseCalculationState.fromJson(decoded as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> save(ExpenseCalculationState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }
}
