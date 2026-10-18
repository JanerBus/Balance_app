import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget_model.dart';
import '../models/currency_model.dart';
import '../models/debt_model.dart';
import '../models/recurring_model.dart';
import '../models/transaction_model.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  static const String _keyBank = 'pref_notify_bank_transactions';
  static const String _keyBudget = 'pref_notify_budget_alerts';
  static const String _keyDebt = 'pref_notify_debt_reminders';
  static const String _keyRecurring = 'pref_notify_recurring_reminders';
  static const String _keyDaily = 'pref_notify_daily_reminder';
  static const String _keyHour = 'pref_daily_reminder_hour';
  static const String _keyMinute = 'pref_daily_reminder_minute';
  static const String _keySentLog = 'pref_sent_notification_logs';

  bool _isSystemPermissionGranted = true;
  bool _notifyBankTransactions = true;
  bool _notifyBudgetAlerts = true;
  bool _notifyDebtReminders = true;
  bool _notifyRecurringReminders = true;
  bool _notifyDailyReminder = true;
  int _dailyReminderHour = 20; // 8:00 PM por defecto
  int _dailyReminderMinute = 0;

  Set<String> _sentAlertsLog = {};

  bool get isSystemPermissionGranted => _isSystemPermissionGranted;
  bool get notifyBankTransactions => _notifyBankTransactions;
  bool get notifyBudgetAlerts => _notifyBudgetAlerts;
  bool get notifyDebtReminders => _notifyDebtReminders;
  bool get notifyRecurringReminders => _notifyRecurringReminders;
  bool get notifyDailyReminder => _notifyDailyReminder;
  int get dailyReminderHour => _dailyReminderHour;
  int get dailyReminderMinute => _dailyReminderMinute;
  TimeOfDay get dailyReminderTime => TimeOfDay(hour: _dailyReminderHour, minute: _dailyReminderMinute);

  NotificationSettingsProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _notifyBankTransactions = prefs.getBool(_keyBank) ?? true;
    _notifyBudgetAlerts = prefs.getBool(_keyBudget) ?? true;
    _notifyDebtReminders = prefs.getBool(_keyDebt) ?? true;
    _notifyRecurringReminders = prefs.getBool(_keyRecurring) ?? true;
    _notifyDailyReminder = prefs.getBool(_keyDaily) ?? true;
    _dailyReminderHour = prefs.getInt(_keyHour) ?? 20;
    _dailyReminderMinute = prefs.getInt(_keyMinute) ?? 0;

    final sentLogList = prefs.getStringList(_keySentLog) ?? [];
    _sentAlertsLog = sentLogList.toSet();

    await checkPermission();
    notifyListeners();
  }

  Future<void> checkPermission() async {
    _isSystemPermissionGranted = await NotificationService.isPermissionGranted();
    notifyListeners();
  }

  /// Recarga preferencias de notificaciones desde SharedPreferences
  Future<void> reloadPreferences() async {
    await _loadPreferences();
  }

  Future<bool> requestPermission() async {
    final granted = await NotificationService.requestPermission();
    _isSystemPermissionGranted = granted;
    notifyListeners();
    return granted;
  }

  Future<void> setNotifyBankTransactions(bool val) async {
    _notifyBankTransactions = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBank, val);
    notifyListeners();
  }

  Future<void> setNotifyBudgetAlerts(bool val) async {
    _notifyBudgetAlerts = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBudget, val);
    notifyListeners();
  }

  Future<void> setNotifyDebtReminders(bool val) async {
    _notifyDebtReminders = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDebt, val);
    notifyListeners();
  }

  Future<void> setNotifyRecurringReminders(bool val) async {
    _notifyRecurringReminders = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRecurring, val);
    notifyListeners();
  }

  Future<void> setNotifyDailyReminder(bool val) async {
    _notifyDailyReminder = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDaily, val);
    notifyListeners();
  }

  Future<void> setDailyReminderTime(TimeOfDay time) async {
    _dailyReminderHour = time.hour;
    _dailyReminderMinute = time.minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, time.hour);
    await prefs.setInt(_keyMinute, time.minute);
    notifyListeners();
  }

  /// Envía una notificación de prueba instantánea
  Future<bool> sendTestNotification() async {
    return await NotificationService.showNotification(
      id: 9999,
      title: '🔔 My Money',
      body: '¡Tus notificaciones están perfectamente configuradas y activas!',
      channelId: NotificationService.channelBankSync,
      payload: jsonEncode({'action': 'test'}),
    );
  }

  /// Evalúa periódicamente o al abrir la app todas las alertas inteligentes necesarias
  Future<void> evaluateAndDispatchAlerts({
    required List<TransactionModel> transactions,
    required List<BudgetModel> budgets,
    required List<DebtModel> debts,
    required List<RecurringModel> recurring,
    required CurrencyModel currency,
  }) async {
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    bool changedLog = false;

    // 1. EVALUAR ALERTAS DE PRESUPUESTO (80% y 100%)
    if (_notifyBudgetAlerts) {
      // Calcular gastos del mes actual por categoría
      final currentMonthExpenses = transactions.where((t) =>
          t.type == TransactionType.expense &&
          t.date.year == now.year &&
          t.date.month == now.month);

      final Map<String, double> spendingByCategory = {};
      for (final t in currentMonthExpenses) {
        spendingByCategory[t.category] = (spendingByCategory[t.category] ?? 0.0) + t.amount;
      }

      for (final budget in budgets) {
        final spent = spendingByCategory[budget.category] ?? 0.0;
        if (budget.amount <= 0) continue;

        final percentage = (spent / budget.amount) * 100.0;

        // Caso A: Superó el 100%
        if (percentage >= 100.0) {
          final logId = 'budget_100_${budget.category}_$monthKey';
          if (!_sentAlertsLog.contains(logId)) {
            _sentAlertsLog.add(logId);
            changedLog = true;
            await NotificationService.showNotification(
              id: (budget.category.hashCode % 10000) + 1000,
              title: '🚨 Límite de Presupuesto Excedido',
              body: 'Has superado el 100% en ${budget.category} (${Formatters.currency(spent, currency, false)} de ${Formatters.currency(budget.amount, currency, false)}).',
              channelId: NotificationService.channelBudgets,
              payload: jsonEncode({'action': 'open_budgets'}),
            );
          }
        }
        // Caso B: Alcanzó o superó el 80% (y menor al 100%)
        else if (percentage >= 80.0) {
          final logId = 'budget_80_${budget.category}_$monthKey';
          if (!_sentAlertsLog.contains(logId)) {
            _sentAlertsLog.add(logId);
            changedLog = true;
            await NotificationService.showNotification(
              id: (budget.category.hashCode % 10000) + 2000,
              title: '⚠️ Alerta de Presupuesto (80%)',
              body: 'Has consumido el ${percentage.toInt()}% de tu presupuesto en ${budget.category}.',
              channelId: NotificationService.channelBudgets,
              payload: jsonEncode({'action': 'open_budgets'}),
            );
          }
        }
      }
    }

    // 2. EVALUAR RECORDATORIOS DE DEUDAS Y PRÉSTAMOS
    if (_notifyDebtReminders) {
      for (final debt in debts) {
        if (debt.isFullySettled || debt.dueDate == null) continue;

        final diff = debt.dueDate!.difference(DateTime(now.year, now.month, now.day)).inDays;

        // Vence hoy o mañana
        if (diff == 0 || diff == 1) {
          final logId = 'debt_${debt.id}_$todayKey';
          if (!_sentAlertsLog.contains(logId)) {
            _sentAlertsLog.add(logId);
            changedLog = true;

            final isDebt = debt.type == DebtType.iOwe;
            final title = isDebt
                ? '📅 Vencimiento de Deuda: ${debt.personName}'
                : '📅 Cobro Pendiente: ${debt.personName}';
            final when = diff == 0 ? 'vence hoy' : 'vence mañana';
            final body = isDebt
                ? 'Tu cuota pendiente por ${Formatters.currency(debt.remainingAmount, currency, false)} $when.'
                : 'El cobro a favor por ${Formatters.currency(debt.remainingAmount, currency, false)} $when.';

            await NotificationService.showNotification(
              id: (debt.id.hashCode % 10000) + 3000,
              title: title,
              body: body,
              channelId: NotificationService.channelDebts,
              payload: jsonEncode({'action': 'open_debts', 'id': debt.id}),
            );
          }
        }
      }
    }

    // 3. EVALUAR GASTOS RECURRENTES Y SUSCRIPCIONES
    if (_notifyRecurringReminders) {
      for (final item in recurring) {
        if (!item.isActive) continue;

        final nextDue = item.nextDueDate;
        final diff = nextDue.difference(DateTime(now.year, now.month, now.day)).inDays;

        if (diff >= 0 && diff <= 1) {
          final logId = 'recurring_${item.id}_${nextDue.year}-${nextDue.month}-${nextDue.day}';
          if (!_sentAlertsLog.contains(logId)) {
            _sentAlertsLog.add(logId);
            changedLog = true;

            final when = diff == 0 ? 'se cobra hoy' : 'se cobra mañana';
            await NotificationService.showNotification(
              id: (item.id.hashCode % 10000) + 4000,
              title: '🔔 Cargo Recurrente: ${item.title}',
              body: 'Tu suscripción de ${Formatters.currency(item.amount, currency, false)} $when (${item.frequencyLabel}).',
              channelId: NotificationService.channelRecurring,
              payload: jsonEncode({'action': 'open_recurring'}),
            );
          }
        }
      }
    }

    // 4. RECORDATORIO DIARIO DE BALANCE
    if (_notifyDailyReminder) {
      final nowMinutes = (now.hour * 60) + now.minute;
      final targetMinutes = (_dailyReminderHour * 60) + _dailyReminderMinute;

      // Si ya pasó la hora programada en el día de hoy
      if (nowMinutes >= targetMinutes) {
        final logId = 'daily_reminder_$todayKey';
        if (!_sentAlertsLog.contains(logId)) {
          _sentAlertsLog.add(logId);
          changedLog = true;

          // Comprobar si hubo gastos hoy
          final hadTransactionsToday = transactions.any((t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day);

          final body = hadTransactionsToday
              ? 'Tus finanzas del día van al corriente. Toca para ver tu balance actualizado.'
              : '¿Tuviste movimientos financieros hoy? Toca para registrarlos y mantener tu balance al día.';

          await NotificationService.showNotification(
            id: 5000,
            title: '✨ Balance Diario',
            body: body,
            channelId: NotificationService.channelDaily,
            payload: jsonEncode({'action': 'open_home'}),
          );
        }
      }
    }

    if (changedLog) {
      final prefs = await SharedPreferences.getInstance();
      // Guardar últimos 100 registros para evitar crecimiento infinito
      final listToSave = _sentAlertsLog.toList();
      if (listToSave.length > 100) {
        listToSave.removeRange(0, listToSave.length - 100);
      }
      await prefs.setStringList(_keySentLog, listToSave);
    }
  }
}
