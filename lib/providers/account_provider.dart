import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/db_helper.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';

class AccountProvider with ChangeNotifier {
  final DBHelper _db = DBHelper.instance;
  final Uuid _uuid = const Uuid();

  List<AccountModel> _rawAccounts = [];
  List<AccountModel> _accounts = [];
  String? _selectedAccountId; // null significa "Todas las cuentas"
  bool _isLoading = false;

  List<AccountModel> get accounts => _accounts;
  String? get selectedAccountId => _selectedAccountId;
  bool get isLoading => _isLoading;

  AccountModel? get selectedAccount {
    if (_selectedAccountId == null) return null;
    return _accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => _accounts.first,
    );
  }

  /// Balance total consolidado de todas las cuentas marcadas para incluir en total
  double get totalBalance => _accounts
      .where((a) => a.includeInTotal)
      .fold(0.0, (sum, a) => sum + a.currentBalance);

  Future<void> loadAccounts([List<TransactionModel>? transactions]) async {
    _isLoading = true;
    notifyListeners();
    try {
      _rawAccounts = await _db.getAccounts();
      updateBalances(transactions ?? []);
    } catch (e) {
      debugPrint('Error loading accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateBalances(List<TransactionModel> transactions) {
    _accounts = _rawAccounts.map((account) {
      double balance = account.initialBalance;
      for (final t in transactions) {
        if (t.accountId == account.id) {
          if (t.type == TransactionType.income) {
            balance += t.amount;
          } else if (t.type == TransactionType.expense) {
            balance -= t.amount;
          } else if (t.type == TransactionType.transfer) {
            balance -= t.amount; // Sale de esta cuenta
          }
        }
        if (t.toAccountId == account.id && t.type == TransactionType.transfer) {
          balance += t.amount; // Entra a esta cuenta destino
        }
      }
      return account.copyWith(currentBalance: balance);
    }).toList();
    notifyListeners();
  }

  void selectAccount(String? accountId) {
    _selectedAccountId = accountId;
    notifyListeners();
  }

  Future<void> addAccount({
    required String name,
    required AccountType type,
    double initialBalance = 0.0,
    required int color,
    required String icon,
    bool includeInTotal = true,
    double? creditLimit,
    int? closingDay,
    int? dueDay,
  }) async {
    final account = AccountModel(
      id: _uuid.v4(),
      name: name,
      type: type,
      initialBalance: initialBalance,
      color: color,
      icon: icon,
      includeInTotal: includeInTotal,
      creditLimit: creditLimit,
      closingDay: closingDay,
      dueDay: dueDay,
    );
    await _db.insertAccount(account);
    _rawAccounts = await _db.getAccounts();
    notifyListeners();
  }

  Future<void> updateAccount(AccountModel account) async {
    await _db.updateAccount(account);
    _rawAccounts = await _db.getAccounts();
    notifyListeners();
  }

  Future<bool> deleteAccount(String id) async {
    if (_rawAccounts.length <= 1) {
      return false; // Al menos debe existir una cuenta
    }
    await _db.deleteAccount(id);
    if (_selectedAccountId == id) {
      _selectedAccountId = null;
    }
    _rawAccounts = await _db.getAccounts();
    notifyListeners();
    return true;
  }
}
