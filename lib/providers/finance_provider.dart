import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/transaction_model.dart';

class FinanceProvider with ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final Uuid _uuid = const Uuid();

  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  final List<void Function(List<TransactionModel>)> _listeners = [];

  List<TransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  void addTransactionsListener(void Function(List<TransactionModel>) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  void removeTransactionsListener(void Function(List<TransactionModel>) listener) {
    _listeners.remove(listener);
  }

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _transactions = await _db.getTransactions();
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    for (final listener in List.of(_listeners)) {
      try {
        listener(_transactions);
      } catch (e) {
        debugPrint('Error in transaction listener: $e');
      }
    }
  }

  Future<void> addTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String? note,
    String accountId = 'default-cash',
    String? toAccountId,
  }) async {
    final t = TransactionModel(
      id: _uuid.v4(),
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: note,
      accountId: accountId,
      toAccountId: toAccountId,
    );
    await _db.insertTransaction(t);
    await loadTransactions();
  }

  Future<void> addTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String? note,
    String fromAccountName = 'Cuenta',
    String toAccountName = 'Cuenta',
  }) async {
    final t = TransactionModel(
      id: _uuid.v4(),
      title: 'Transferencia: $fromAccountName ➔ $toAccountName',
      amount: amount,
      type: TransactionType.transfer,
      category: 'Transferencia',
      date: date,
      note: note,
      accountId: fromAccountId,
      toAccountId: toAccountId,
    );
    await _db.insertTransaction(t);
    await loadTransactions();
  }

  Future<void> updateTransaction(TransactionModel t) async {
    await _db.updateTransaction(t);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await _db.deleteTransaction(id);
    await loadTransactions();
  }

  List<TransactionModel> transactionsForMonth(DateTime month) {
    return _transactions
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .toList();
  }

  Map<String, double> expenseByCategory({DateTime? month, String? accountId}) {
    var source = month == null
        ? _transactions.where((t) => t.type == TransactionType.expense)
        : transactionsForMonth(month).where((t) => t.type == TransactionType.expense);

    if (accountId != null) {
      source = source.where((t) => t.accountId == accountId);
    }

    final Map<String, double> result = {};
    for (final t in source) {
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
    return result;
  }
}
