import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/debt_model.dart';
import '../models/debt_payment_model.dart';

class DebtProvider with ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final Uuid _uuid = const Uuid();

  List<DebtModel> _debts = [];
  bool _isLoading = false;

  List<DebtModel> get debts => _debts;
  bool get isLoading => _isLoading;

  /// Deudas pendientes que me deben (no liquidadas completamente)
  List<DebtModel> get theyOweMe =>
      _debts.where((d) => d.type == DebtType.theyOweMe && !d.isFullySettled).toList();

  /// Deudas pendientes que yo debo (no liquidadas completamente)
  List<DebtModel> get iOwe =>
      _debts.where((d) => d.type == DebtType.iOwe && !d.isFullySettled).toList();

  /// Deudas completamente pagadas o liquidadas
  List<DebtModel> get paidDebts => _debts.where((d) => d.isFullySettled).toList();

  /// Total pendiente que me deben (saldo restante real)
  double get totalTheyOweMe => theyOweMe.fold(0.0, (sum, d) => sum + d.remainingAmount);

  /// Total pendiente que yo debo (saldo restante real)
  double get totalIOwe => iOwe.fold(0.0, (sum, d) => sum + d.remainingAmount);

  Future<void> loadDebts() async {
    _isLoading = true;
    notifyListeners();
    _debts = await _db.getDebts();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addDebt({
    required String personName,
    required double amount,
    required DebtType type,
    String? description,
    DateTime? dueDate,
  }) async {
    final d = DebtModel(
      id: _uuid.v4(),
      personName: personName,
      amount: amount,
      type: type,
      description: description,
      createdDate: DateTime.now(),
      dueDate: dueDate,
    );
    await _db.insertDebt(d);
    await loadDebts();
  }

  Future<void> updateDebt(DebtModel d) async {
    await _db.updateDebt(d);
    await loadDebts();
  }

  Future<void> markAsPaid(DebtModel d) async {
    await _db.updateDebt(d.copyWith(isPaid: true));
    await loadDebts();
  }

  Future<void> markAsUnpaid(DebtModel d) async {
    await _db.updateDebt(d.copyWith(isPaid: false));
    await loadDebts();
  }

  Future<void> deleteDebt(String id) async {
    await _db.deleteDebt(id);
    await loadDebts();
  }

  /// Registrar un abono / pago parcial a una deuda
  Future<void> addPayment({
    required String debtId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final payment = DebtPaymentModel(
      id: _uuid.v4(),
      debtId: debtId,
      amount: amount,
      date: date,
      note: note,
    );
    await _db.insertDebtPayment(payment);

    // Si con este abono se salda la deuda en su totalidad, la marcamos como pagada
    final debt = _debts.firstWhere((d) => d.id == debtId, orElse: () => _debts.first);
    final newTotalPaid = debt.totalPaid + amount;
    if (newTotalPaid >= debt.amount && !debt.isPaid) {
      await _db.updateDebt(debt.copyWith(isPaid: true));
    }

    await loadDebts();
  }

  /// Eliminar un abono
  Future<void> deletePayment({
    required String paymentId,
    required String debtId,
  }) async {
    await _db.deleteDebtPayment(paymentId);

    // Si la deuda estaba marcada como pagada pero al retirar el abono el saldo queda pendiente, desmarcamos isPaid
    final debtIndex = _debts.indexWhere((d) => d.id == debtId);
    if (debtIndex != -1) {
      final debt = _debts[debtIndex];
      final payment = debt.payments.firstWhere((p) => p.id == paymentId, orElse: () => debt.payments.first);
      final newTotalPaid = debt.totalPaid - payment.amount;
      if (newTotalPaid < debt.amount && debt.isPaid) {
        await _db.updateDebt(debt.copyWith(isPaid: false));
      }
    }

    await loadDebts();
  }

  /// Agrupa una lista de deudas por nombre de persona
  Map<String, List<DebtModel>> groupByPerson(List<DebtModel> list) {
    final Map<String, List<DebtModel>> grouped = {};
    for (final d in list) {
      grouped.putIfAbsent(d.personName, () => []).add(d);
    }
    return grouped;
  }

  /// Marca como pagadas todas las deudas pendientes de una persona
  Future<void> markAllAsPaidForPerson(String personName, DebtType type) async {
    final toMark = _debts.where(
      (d) => d.personName == personName && d.type == type && !d.isFullySettled,
    );
    for (final d in toMark) {
      await _db.updateDebt(d.copyWith(isPaid: true));
    }
    await loadDebts();
  }
}
