import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/goal_model.dart';
import '../models/goal_transaction_model.dart';
import '../models/transaction_model.dart';
import 'finance_provider.dart';

class GoalProvider with ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final Uuid _uuid = const Uuid();

  List<GoalModel> _goals = [];
  bool _isLoading = false;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _isLoading;

  List<GoalModel> get activeGoals =>
      _goals.where((g) => !g.isCompleted && g.currentAmount < g.targetAmount).toList();

  List<GoalModel> get completedGoals =>
      _goals.where((g) => g.isCompleted || g.currentAmount >= g.targetAmount).toList();

  double get totalTarget => _goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  double get totalSaved => _goals.fold(0.0, (sum, g) => sum + g.currentAmount);
  double get overallProgress =>
      totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
  int get completedCount => completedGoals.length;

  Future<void> loadGoals() async {
    _isLoading = true;
    notifyListeners();
    _goals = await _db.getGoals();
    _isLoading = false;
    notifyListeners();
  }

  Future<GoalModel> addGoal({
    required String title,
    required double targetAmount,
    double currentAmount = 0.0,
    DateTime? targetDate,
    required int color,
    required String icon,
    String? note,
  }) async {
    final goal = GoalModel(
      id: _uuid.v4(),
      title: title,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
      color: color,
      icon: icon,
      note: note,
      isCompleted: currentAmount >= targetAmount,
      createdAt: DateTime.now(),
    );

    await _db.insertGoal(goal);

    if (currentAmount > 0) {
      final initialTx = GoalTransactionModel(
        id: _uuid.v4(),
        goalId: goal.id,
        amount: currentAmount,
        type: GoalTransactionType.deposit,
        date: DateTime.now(),
        note: 'Aporte inicial al crear meta',
      );
      await _db.insertGoalTransaction(initialTx);
    }

    await loadGoals();
    return goal;
  }

  Future<void> updateGoal(GoalModel goal) async {
    final isCompleted = goal.currentAmount >= goal.targetAmount;
    final updated = goal.copyWith(isCompleted: isCompleted);
    await _db.updateGoal(updated);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    await _db.deleteGoal(id);
    await loadGoals();
  }

  /// Realiza un aporte a la meta y opcionalmente deduce el dinero de una cuenta
  Future<void> depositToGoal({
    required String goalId,
    required double amount,
    String? accountId,
    String? note,
    DateTime? date,
    bool syncToAccount = false,
    FinanceProvider? financeProvider,
  }) async {
    if (amount <= 0) return;

    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];
    final newAmount = goal.currentAmount + amount;
    final isCompleted = newAmount >= goal.targetAmount;

    final updated = goal.copyWith(
      currentAmount: newAmount,
      isCompleted: isCompleted,
    );

    await _db.updateGoal(updated);

    final txDate = date ?? DateTime.now();
    final tx = GoalTransactionModel(
      id: _uuid.v4(),
      goalId: goalId,
      amount: amount,
      type: GoalTransactionType.deposit,
      date: txDate,
      note: note,
      accountId: accountId,
    );
    await _db.insertGoalTransaction(tx);

    // Opcionalmente registrar como Gasto/Aporte en Balance General
    if (syncToAccount && financeProvider != null && accountId != null) {
      await financeProvider.addTransaction(
        title: 'Aporte: ${goal.title}',
        amount: amount,
        type: TransactionType.expense,
        category: 'Ahorro',
        date: txDate,
        note: 'Aporte a meta de ahorro: ${goal.title}${note != null ? " ($note)" : ""}',
        accountId: accountId,
      );
    }

    await loadGoals();
  }

  /// Retira dinero de la meta y opcionalmente abona el dinero de vuelta a una cuenta
  Future<void> withdrawFromGoal({
    required String goalId,
    required double amount,
    String? accountId,
    String? note,
    DateTime? date,
    bool syncToAccount = false,
    FinanceProvider? financeProvider,
  }) async {
    if (amount <= 0) return;

    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return;

    final goal = _goals[index];
    final newAmount = (goal.currentAmount - amount).clamp(0.0, double.infinity);
    final isCompleted = newAmount >= goal.targetAmount;

    final updated = goal.copyWith(
      currentAmount: newAmount,
      isCompleted: isCompleted,
    );

    await _db.updateGoal(updated);

    final txDate = date ?? DateTime.now();
    final tx = GoalTransactionModel(
      id: _uuid.v4(),
      goalId: goalId,
      amount: amount,
      type: GoalTransactionType.withdraw,
      date: txDate,
      note: note,
      accountId: accountId,
    );
    await _db.insertGoalTransaction(tx);

    // Opcionalmente registrar como Ingreso/Retiro en Balance General
    if (syncToAccount && financeProvider != null && accountId != null) {
      await financeProvider.addTransaction(
        title: 'Retiro: ${goal.title}',
        amount: amount,
        type: TransactionType.income,
        category: 'Ahorro',
        date: txDate,
        note: 'Retiro de meta de ahorro: ${goal.title}${note != null ? " ($note)" : ""}',
        accountId: accountId,
      );
    }

    await loadGoals();
  }

  Future<List<GoalTransactionModel>> getTransactions(String goalId) async {
    return await _db.getGoalTransactions(goalId);
  }
}
