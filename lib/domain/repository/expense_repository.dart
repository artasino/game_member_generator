import '../entities/expense_item.dart';

abstract class ExpenseRepository {
  Future<ExpenseCalculationState?> get();

  Future<void> save(ExpenseCalculationState state);
}
