import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/debt_model.dart';
import '../models/debt_payment_model.dart';
import '../models/account_model.dart';
import '../models/budget_model.dart';
import '../models/recurring_model.dart';
import '../models/goal_model.dart';
import '../models/goal_transaction_model.dart';

class DBHelper {
  DBHelper._privateConstructor();
  static final DBHelper instance = DBHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'personal_finance.db');
    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        initialBalance REAL NOT NULL DEFAULT 0.0,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        includeInTotal INTEGER NOT NULL DEFAULT 1,
        creditLimit REAL,
        closingDay INTEGER,
        dueDay INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        accountId TEXT NOT NULL DEFAULT 'default-cash',
        toAccountId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        personName TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        createdDate TEXT NOT NULL,
        dueDate TEXT,
        isPaid INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE debt_payments (
        id TEXT PRIMARY KEY,
        debtId TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (debtId) REFERENCES debts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        month INTEGER,
        year INTEGER,
        notifyAt80 INTEGER NOT NULL DEFAULT 1,
        notifyAt100 INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_transactions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        accountId TEXT NOT NULL,
        frequency TEXT NOT NULL,
        startDate TEXT NOT NULL,
        nextDueDate TEXT NOT NULL,
        autoApply INTEGER NOT NULL DEFAULT 1,
        isActive INTEGER NOT NULL DEFAULT 1,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE savings_goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        targetAmount REAL NOT NULL,
        currentAmount REAL NOT NULL DEFAULT 0.0,
        targetDate TEXT,
        color INTEGER NOT NULL,
        icon TEXT NOT NULL,
        note TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE goal_transactions (
        id TEXT PRIMARY KEY,
        goalId TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        accountId TEXT,
        FOREIGN KEY (goalId) REFERENCES savings_goals (id) ON DELETE CASCADE
      )
    ''');

    // Seed default accounts
    await _seedDefaultAccounts(db);

    // Índices de alto rendimiento para consultas recurrentes y llaves foráneas
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(accountId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_debt_payments_debtId ON debt_payments(debtId);');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS debt_payments (
          id TEXT PRIMARY KEY,
          debtId TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          FOREIGN KEY (debtId) REFERENCES debts (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS accounts (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          initialBalance REAL NOT NULL DEFAULT 0.0,
          color INTEGER NOT NULL,
          icon TEXT NOT NULL,
          includeInTotal INTEGER NOT NULL DEFAULT 1
        )
      ''');

      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN accountId TEXT NOT NULL DEFAULT 'default-cash';");
      } catch (_) {}

      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN toAccountId TEXT;");
      } catch (_) {}

      await _seedDefaultAccounts(db);

      await db.execute("UPDATE transactions SET accountId = 'default-cash' WHERE accountId IS NULL OR accountId = ''");
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS budgets (
          id TEXT PRIMARY KEY,
          category TEXT NOT NULL,
          amount REAL NOT NULL,
          month INTEGER,
          year INTEGER,
          notifyAt80 INTEGER NOT NULL DEFAULT 1,
          notifyAt100 INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_transactions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          accountId TEXT NOT NULL,
          frequency TEXT NOT NULL,
          startDate TEXT NOT NULL,
          nextDueDate TEXT NOT NULL,
          autoApply INTEGER NOT NULL DEFAULT 1,
          isActive INTEGER NOT NULL DEFAULT 1,
          note TEXT
        )
      ''');
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS savings_goals (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          targetAmount REAL NOT NULL,
          currentAmount REAL NOT NULL DEFAULT 0.0,
          targetDate TEXT,
          color INTEGER NOT NULL,
          icon TEXT NOT NULL,
          note TEXT,
          isCompleted INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS goal_transactions (
          id TEXT PRIMARY KEY,
          goalId TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          accountId TEXT,
          FOREIGN KEY (goalId) REFERENCES savings_goals (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN creditLimit REAL;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN closingDay INTEGER;');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE accounts ADD COLUMN dueDay INTEGER;');
      } catch (_) {}
    }

    if (oldVersion < 8) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(accountId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_debt_payments_debtId ON debt_payments(debtId);');
    }
  }

  Future<void> _seedDefaultAccounts(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM accounts')) ?? 0;
    if (count == 0) {
      await db.insert('accounts', {
        'id': 'default-cash',
        'name': 'Efectivo',
        'type': 'cash',
        'initialBalance': 0.0,
        'color': 0xFF2E7D32,
        'icon': 'payments',
        'includeInTotal': 1,
      });

      await db.insert('accounts', {
        'id': 'default-bank',
        'name': 'Cuenta Bancaria',
        'type': 'bank',
        'initialBalance': 0.0,
        'color': 0xFF1976D2,
        'icon': 'account_balance',
        'includeInTotal': 1,
      });
    }
  }

  // --- Accounts CRUD ---

  Future<void> insertAccount(AccountModel a) async {
    final db = await database;
    await db.insert('accounts', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAccount(AccountModel a) async {
    final db = await database;
    await db.update('accounts', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  Future<void> deleteAccount(String id) async {
    final db = await database;
    await db.execute(
      "UPDATE transactions SET accountId = 'default-cash' WHERE accountId = ?",
      [id],
    );
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AccountModel>> getAccounts() async {
    final db = await database;
    final maps = await db.query('accounts');
    return maps.map((m) => AccountModel.fromMap(m)).toList();
  }

  // --- Transactions CRUD ---

  Future<void> insertTransaction(TransactionModel t) async {
    final db = await database;
    await db.insert('transactions', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateTransaction(TransactionModel t) async {
    final db = await database;
    await db.update('transactions', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TransactionModel>> getTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  // --- Debts CRUD ---

  Future<void> insertDebt(DebtModel d) async {
    final db = await database;
    await db.insert('debts', d.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateDebt(DebtModel d) async {
    final db = await database;
    await db.update('debts', d.toMap(), where: 'id = ?', whereArgs: [d.id]);
  }

  Future<void> deleteDebt(String id) async {
    final db = await database;
    await db.delete('debt_payments', where: 'debtId = ?', whereArgs: [id]);
    await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DebtModel>> getDebts() async {
    final db = await database;
    final debtMaps = await db.query('debts', orderBy: 'createdDate DESC');
    final paymentMaps = await db.query('debt_payments', orderBy: 'date DESC');

    final Map<String, List<DebtPaymentModel>> paymentsByDebt = {};
    for (final pMap in paymentMaps) {
      final payment = DebtPaymentModel.fromMap(pMap);
      paymentsByDebt.putIfAbsent(payment.debtId, () => []).add(payment);
    }

    return debtMaps.map((m) {
      final id = m['id'] as String;
      final payments = paymentsByDebt[id] ?? [];
      return DebtModel.fromMap(m, payments: payments);
    }).toList();
  }

  // --- Debt Payments CRUD ---

  Future<void> insertDebtPayment(DebtPaymentModel payment) async {
    final db = await database;
    await db.insert('debt_payments', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteDebtPayment(String paymentId) async {
    final db = await database;
    await db.delete('debt_payments', where: 'id = ?', whereArgs: [paymentId]);
  }

  Future<List<DebtPaymentModel>> getPaymentsForDebt(String debtId) async {
    final db = await database;
    final maps = await db.query(
      'debt_payments',
      where: 'debtId = ?',
      whereArgs: [debtId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => DebtPaymentModel.fromMap(m)).toList();
  }

  // --- Budgets CRUD ---

  Future<void> insertBudget(BudgetModel b) async {
    final db = await database;
    await db.insert('budgets', b.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateBudget(BudgetModel b) async {
    final db = await database;
    await db.update('budgets', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
  }

  Future<void> deleteBudget(String id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<BudgetModel>> getBudgets() async {
    final db = await database;
    final maps = await db.query('budgets');
    return maps.map((m) => BudgetModel.fromMap(m)).toList();
  }

  // --- Recurring Transactions CRUD ---

  Future<void> insertRecurring(RecurringModel r) async {
    final db = await database;
    await db.insert('recurring_transactions', r.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRecurring(RecurringModel r) async {
    final db = await database;
    await db.update('recurring_transactions', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  Future<void> deleteRecurring(String id) async {
    final db = await database;
    await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RecurringModel>> getRecurringList() async {
    final db = await database;
    final maps = await db.query('recurring_transactions', orderBy: 'nextDueDate ASC');
    return maps.map((m) => RecurringModel.fromMap(m)).toList();
  }

  // --- Savings Goals & Piggy Banks CRUD ---

  Future<void> insertGoal(GoalModel goal) async {
    final db = await database;
    await db.insert('savings_goals', goal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGoal(GoalModel goal) async {
    final db = await database;
    await db.update('savings_goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
  }

  Future<void> deleteGoal(String id) async {
    final db = await database;
    await db.delete('savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GoalModel>> getGoals() async {
    final db = await database;
    final maps = await db.query('savings_goals', orderBy: 'createdAt DESC');
    return maps.map((m) => GoalModel.fromMap(m)).toList();
  }

  Future<void> insertGoalTransaction(GoalTransactionModel t) async {
    final db = await database;
    await db.insert('goal_transactions', t.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteGoalTransaction(String id) async {
    final db = await database;
    await db.delete('goal_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GoalTransactionModel>> getGoalTransactions(String goalId) async {
    final db = await database;
    final maps = await db.query(
      'goal_transactions',
      where: 'goalId = ?',
      whereArgs: [goalId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => GoalTransactionModel.fromMap(m)).toList();
  }

  // --- Backup & Restore ---

  /// Obtiene un snapshot de todas las tablas en SQLite para exportación
  Future<Map<String, List<Map<String, dynamic>>>> getAllTableData() async {
    final db = await database;
    return {
      'accounts': await db.query('accounts'),
      'transactions': await db.query('transactions'),
      'debts': await db.query('debts'),
      'debt_payments': await db.query('debt_payments'),
      'budgets': await db.query('budgets'),
      'recurring_transactions': await db.query('recurring_transactions'),
      'savings_goals': await db.query('savings_goals'),
      'goal_transactions': await db.query('goal_transactions'),
    };
  }

  /// Restaura los datos en SQLite en una sola transacción atómica segura.
  /// Si [isReplaceMode] es true, borra las tablas previamente.
  /// Si es false (merge mode), inserta ignorando conflictos de clave primaria.
  Future<int> restoreAllTableData(
    Map<String, dynamic> tables, {
    required bool isReplaceMode,
  }) async {
    final db = await database;
    int totalInserted = 0;

    await db.transaction((txn) async {
      if (isReplaceMode) {
        // Eliminar en orden estricto de dependencias foráneas
        await txn.delete('goal_transactions');
        await txn.delete('savings_goals');
        await txn.delete('debt_payments');
        await txn.delete('debts');
        await txn.delete('transactions');
        await txn.delete('recurring_transactions');
        await txn.delete('budgets');
        await txn.delete('accounts');
      }

      final conflict = isReplaceMode
          ? ConflictAlgorithm.replace
          : ConflictAlgorithm.ignore;

      // Inserción en orden de integridad referencial:
      // 1. Cuentas
      final accounts = tables['accounts'] as List<dynamic>? ?? [];
      for (final raw in accounts) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('accounts', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }

      // 2. Deudas
      final debts = tables['debts'] as List<dynamic>? ?? [];
      for (final raw in debts) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('debts', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }

      // 3. Pagos de Deudas
      final debtPayments = tables['debt_payments'] as List<dynamic>? ?? [];
      for (final raw in debtPayments) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('debt_payments', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }

      // 4. Presupuestos
      final budgets = tables['budgets'] as List<dynamic>? ?? [];
      for (final raw in budgets) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('budgets', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }

      // 5. Transacciones Recurrentes
      final recurring = tables['recurring_transactions'] as List<dynamic>? ?? [];
      for (final raw in recurring) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('recurring_transactions', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }

      // 6. Metas de Ahorro
      final goals = tables['savings_goals'] as List<dynamic>? ?? [];
      for (final raw in goals) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('savings_goals', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }

      // 7. Aportes a Metas de Ahorro
      final goalTransactions = tables['goal_transactions'] as List<dynamic>? ?? [];
      for (final raw in goalTransactions) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('goal_transactions', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }

      // 8. Transacciones
      final transactions = tables['transactions'] as List<dynamic>? ?? [];
      for (final raw in transactions) {
        if (raw is Map<String, dynamic>) {
          await txn.insert('transactions', raw, conflictAlgorithm: conflict);
          totalInserted++;
        }
      }
    });

    return totalInserted;
  }
}
