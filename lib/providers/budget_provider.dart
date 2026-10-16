import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';

class BudgetProvider with ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final Uuid _uuid = const Uuid();

  List<BudgetModel> _rawBudgets = [];
  List<BudgetModel> _budgets = [];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = false;

  List<BudgetModel> get budgets => _budgets;
  DateTime get selectedMonth => _selectedMonth;
  bool get isLoading => _isLoading;

  double get totalBudget => _budgets.fold(0.0, (sum, b) => sum + b.amount);
  double get totalSpent => _budgets.fold(0.0, (sum, b) => sum + b.spent);
  double get totalRemaining => (totalBudget - totalSpent).clamp(0.0, totalBudget);
  double get totalOverspent => totalSpent > totalBudget ? (totalSpent - totalBudget) : 0.0;
  double get overallProgress => totalBudget > 0 ? (totalSpent / totalBudget) : 0.0;
  double get clampedOverallProgress => overallProgress.clamp(0.0, 1.0);

  int get overbudgetCount => _budgets.where((b) => b.isOverbudget).length;
  int get nearLimitCount => _budgets.where((b) => b.isNearLimit).length;

  Future<void> loadBudgets([List<TransactionModel>? transactions]) async {
    _isLoading = true;
    notifyListeners();
    try {
      _rawBudgets = await _db.getBudgets();
      updateSpending(transactions ?? []);
    } catch (e) {
      debugPrint('Error loading budgets: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setMonth(DateTime month, List<TransactionModel> transactions) {
    _selectedMonth = DateTime(month.year, month.month);
    updateSpending(transactions);
  }

  void updateSpending(List<TransactionModel> transactions) {
    // Gastos del mes seleccionado
    final monthExpenses = transactions.where((t) =>
        t.type == TransactionType.expense &&
        t.date.year == _selectedMonth.year &&
        t.date.month == _selectedMonth.month);

    final Map<String, double> spentByCategory = {};
    for (final t in monthExpenses) {
      spentByCategory[t.category] = (spentByCategory[t.category] ?? 0.0) + t.amount;
    }

    _budgets = _rawBudgets.map((b) {
      final spent = spentByCategory[b.category] ?? 0.0;
      return b.copyWith(spent: spent);
    }).toList();

    // Ordenar: primero los sobregirados, luego los cercanos al límite, luego por mayor porcentaje
    _budgets.sort((a, b) => b.progress.compareTo(a.progress));

    notifyListeners();
  }

  Future<void> addBudget({
    required String category,
    required double amount,
  }) async {
    // Si ya existe presupuesto para esta categoría, lo actualizamos
    final existingIndex = _rawBudgets.indexWhere((b) => b.category == category);
    if (existingIndex != -1) {
      final updated = _rawBudgets[existingIndex].copyWith(amount: amount);
      await _db.updateBudget(updated);
    } else {
      final budget = BudgetModel(
        id: _uuid.v4(),
        category: category,
        amount: amount,
      );
      await _db.insertBudget(budget);
    }
    _rawBudgets = await _db.getBudgets();
    notifyListeners();
  }

  Future<void> updateBudget(BudgetModel budget) async {
    await _db.updateBudget(budget);
    _rawBudgets = await _db.getBudgets();
    notifyListeners();
  }

  Future<void> deleteBudget(String id) async {
    await _db.deleteBudget(id);
    _rawBudgets = await _db.getBudgets();
    _budgets.removeWhere((b) => b.id == id);
    notifyListeners();
  }
}
