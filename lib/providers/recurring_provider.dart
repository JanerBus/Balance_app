import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import 'finance_provider.dart';

class RecurringProvider with ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final Uuid _uuid = const Uuid();

  List<RecurringModel> _recurring = [];
  bool _isLoading = false;

  List<RecurringModel> get recurring => _recurring;
  bool get isLoading => _isLoading;

  List<RecurringModel> get expenses =>
      _recurring.where((r) => r.type == TransactionType.expense).toList();

  List<RecurringModel> get incomes =>
      _recurring.where((r) => r.type == TransactionType.income).toList();

  List<RecurringModel> get activeExpenses =>
      expenses.where((r) => r.isActive).toList();

  List<RecurringModel> get activeIncomes =>
      incomes.where((r) => r.isActive).toList();

  /// Total estimado mensual en gastos fijos y suscripciones
  double get monthlyExpenseCommitment =>
      activeExpenses.fold(0.0, (s, r) => s + r.monthlyNormalizedAmount);

  /// Total estimado mensual en ingresos fijos
  double get monthlyIncomeExpected =>
      activeIncomes.fold(0.0, (s, r) => s + r.monthlyNormalizedAmount);

  /// Pagos que vencen en los próximos 7 días
  List<RecurringModel> get dueSoon => _recurring
      .where((r) => r.isActive && r.daysUntilNextDue >= 0 && r.daysUntilNextDue <= 7)
      .toList();

  /// Pagos listos para cobro o vencidos
  List<RecurringModel> get dueNow =>
      _recurring.where((r) => r.isActive && r.isDueNow).toList();

  Future<void> loadRecurring() async {
    _isLoading = true;
    notifyListeners();
    _recurring = await _db.getRecurringList();
    _isLoading = false;
    notifyListeners();
  }

  /// Revisa y aplica automáticamente los cobros que llegaron a su fecha
  Future<int> checkAndApplyDue(FinanceProvider financeProvider) async {
    _recurring = await _db.getRecurringList();
    int appliedCount = 0;

    for (final item in _recurring) {
      if (item.isActive && item.isDueNow && item.autoApply) {
        // 1. Insertar el movimiento en finanzas
        await financeProvider.addTransaction(
          title: item.title,
          amount: item.amount,
          type: item.type,
          category: item.category,
          date: item.nextDueDate,
          accountId: item.accountId,
          note: item.note != null
              ? '${item.note} · Débito recurrente ${item.frequencyLabel.toLowerCase()}'
              : 'Débito recurrente automático (${item.frequencyLabel.toLowerCase()})',
        );

        // 2. Avanzar fecha de próximo ciclo
        final updated = item.copyWith(nextDueDate: item.calculateNextCycleDate);
        await _db.updateRecurring(updated);
        appliedCount++;
      }
    }

    if (appliedCount > 0) {
      _recurring = await _db.getRecurringList();
      notifyListeners();
    }

    return appliedCount;
  }

  /// Ejecutar / registrar manualmente un pago en este momento
  Future<void> executeNow(RecurringModel item, FinanceProvider financeProvider) async {
    await financeProvider.addTransaction(
      title: item.title,
      amount: item.amount,
      type: item.type,
      category: item.category,
      date: DateTime.now(),
      accountId: item.accountId,
      note: 'Pago recurrente aplicado manualmente (${item.frequencyLabel.toLowerCase()})',
    );

    final updated = item.copyWith(nextDueDate: item.calculateNextCycleDate);
    await _db.updateRecurring(updated);
    _recurring = await _db.getRecurringList();
    notifyListeners();
  }

  /// Saltar el cobro actual sin registrar movimiento y pasar al siguiente ciclo
  Future<void> skipNext(RecurringModel item) async {
    final updated = item.copyWith(nextDueDate: item.calculateNextCycleDate);
    await _db.updateRecurring(updated);
    _recurring = await _db.getRecurringList();
    notifyListeners();
  }

  Future<void> addRecurring({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    required String accountId,
    required RecurringFrequency frequency,
    required DateTime startDate,
    required DateTime nextDueDate,
    bool autoApply = true,
    String? note,
  }) async {
    final item = RecurringModel(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      type: type,
      category: category,
      accountId: accountId,
      frequency: frequency,
      startDate: startDate,
      nextDueDate: nextDueDate,
      autoApply: autoApply,
      isActive: true,
      note: note,
    );
    await _db.insertRecurring(item);
    _recurring = await _db.getRecurringList();
    notifyListeners();
  }

  Future<void> updateRecurring(RecurringModel item) async {
    await _db.updateRecurring(item);
    _recurring = await _db.getRecurringList();
    notifyListeners();
  }

  Future<void> toggleActive(RecurringModel item) async {
    final updated = item.copyWith(isActive: !item.isActive);
    await _db.updateRecurring(updated);
    _recurring = await _db.getRecurringList();
    notifyListeners();
  }

  Future<void> deleteRecurring(String id) async {
    await _db.deleteRecurring(id);
    _recurring.removeWhere((r) => r.id == id);
    notifyListeners();
  }
}
