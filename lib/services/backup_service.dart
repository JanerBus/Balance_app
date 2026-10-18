import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../database/db_helper.dart';
import '../providers/finance_provider.dart';
import '../providers/account_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/notification_sync_provider.dart';
import '../providers/notification_settings_provider.dart';

/// Modo de importación de la copia de seguridad
enum ImportMode {
  /// Elimina los datos actuales y restaura con precisión los de la copia
  replace,

  /// Agrega los datos de la copia conservando los registros actuales
  merge,
}

/// Resumen estadístico del contenido de una copia de seguridad
class BackupSummary {
  final String app;
  final int schemaVersion;
  final DateTime? exportedAt;
  final int accountsCount;
  final int transactionsCount;
  final int debtsCount;
  final int debtPaymentsCount;
  final int budgetsCount;
  final int recurringCount;
  final int goalsCount;
  final int goalTransactionsCount;
  final int learnedRulesCount;

  const BackupSummary({
    this.app = 'My Money',
    this.schemaVersion = 1,
    this.exportedAt,
    required this.accountsCount,
    required this.transactionsCount,
    required this.debtsCount,
    required this.debtPaymentsCount,
    required this.budgetsCount,
    required this.recurringCount,
    required this.goalsCount,
    required this.goalTransactionsCount,
    required this.learnedRulesCount,
  });

  int get totalRecords =>
      accountsCount +
      transactionsCount +
      debtsCount +
      debtPaymentsCount +
      budgetsCount +
      recurringCount +
      goalsCount +
      goalTransactionsCount +
      learnedRulesCount;
}

/// Resultado de la validación de un archivo JSON
class BackupValidationResult {
  final bool isValid;
  final String? errorMessage;
  final BackupSummary? summary;
  final Map<String, dynamic>? parsedData;

  const BackupValidationResult({
    required this.isValid,
    this.errorMessage,
    this.summary,
    this.parsedData,
  });
}

/// Resultado de la operación de restauración
class ImportResult {
  final bool success;
  final String message;
  final int importedCount;
  final BackupSummary? summary;

  const ImportResult({
    required this.success,
    required this.message,
    this.importedCount = 0,
    this.summary,
  });
}

/// Servicio integral para exportación e importación de la información del usuario
class BackupService {
  static const int currentSchemaVersion = 1;
  static const String appIdentifier = 'My Money';

  /// Genera la estructura completa de copia de seguridad en formato JSON
  static Future<String> generateBackupJson() async {
    final tables = await DBHelper.instance.getAllTableData();
    final prefs = await SharedPreferences.getInstance();

    // Preferencias y reglas de usuario
    final preferences = <String, dynamic>{
      'selected_currency': prefs.getString('selected_currency') ?? 'COP',
      'theme_mode': prefs.getString('theme_mode') ?? 'system',
      'privacy_mode': prefs.getBool('privacy_mode') ?? false,
      'smart_alerts_enabled': prefs.getBool('smart_alerts_enabled') ?? true,
      'debt_reminders_enabled': prefs.getBool('debt_reminders_enabled') ?? true,
      'recurring_reminders_enabled': prefs.getBool('recurring_reminders_enabled') ?? true,
      'budget_warnings_enabled': prefs.getBool('budget_warnings_enabled') ?? true,
      'daily_reminder_enabled': prefs.getBool('daily_reminder_enabled') ?? true,
      'daily_reminder_hour': prefs.getInt('daily_reminder_hour') ?? 20,
      'daily_reminder_minute': prefs.getInt('daily_reminder_minute') ?? 0,
    };

    // Reglas aprendidas de notificaciones bancarias
    final rulesRaw = prefs.getString('notification_sync_learned_rules');
    List<dynamic> learnedRules = [];
    if (rulesRaw != null && rulesRaw.isNotEmpty) {
      try {
        learnedRules = jsonDecode(rulesRaw) as List<dynamic>;
      } catch (_) {}
    }

    final exportedAt = DateTime.now();

    final payload = {
      'app': appIdentifier,
      'schemaVersion': currentSchemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'summary': {
        'accountsCount': tables['accounts']?.length ?? 0,
        'transactionsCount': tables['transactions']?.length ?? 0,
        'debtsCount': tables['debts']?.length ?? 0,
        'debtPaymentsCount': tables['debt_payments']?.length ?? 0,
        'budgetsCount': tables['budgets']?.length ?? 0,
        'recurringCount': tables['recurring_transactions']?.length ?? 0,
        'goalsCount': tables['savings_goals']?.length ?? 0,
        'goalTransactionsCount': tables['goal_transactions']?.length ?? 0,
        'learnedRulesCount': learnedRules.length,
      },
      'tables': tables,
      'preferences': preferences,
      'userLearnedRules': learnedRules,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Guarda el contenido del respaldo en un archivo temporal y retorna el [File]
  static Future<File> saveBackupTempFile({String? jsonContent}) async {
    final content = jsonContent ?? await generateBackupJson();
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'mymoney_backup_$timestamp.json';
    final file = File('${tempDir.path}/$fileName');
    return await file.writeAsString(content, encoding: utf8);
  }

  /// Exporta la copia de seguridad y abre el menú nativo de compartir
  static Future<void> shareBackup({String? jsonContent}) async {
    final file = await saveBackupTempFile(jsonContent: jsonContent);
    final fileName = file.uri.pathSegments.last;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        subject: 'Copia de Seguridad - My Money',
      ),
    );
  }

  /// Copia el JSON de respaldo al portapapeles
  static Future<void> copyBackupToClipboard({String? jsonContent}) async {
    final content = jsonContent ?? await generateBackupJson();
    await Clipboard.setData(ClipboardData(text: content));
  }

  /// Permite al usuario seleccionar un archivo de copia de seguridad (.json)
  static Future<String?> pickBackupFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'mymoney'],
    );

    if (files.isEmpty) {
      return null;
    }

    final file = files.first;
    final bytes = await file.readAsBytes();
    return utf8.decode(bytes);
  }

  /// Valida la estructura y el contenido de un JSON de respaldo
  static BackupValidationResult validateAndSummarizeJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'El archivo no contiene un objeto JSON válido.',
        );
      }

      final tables = decoded['tables'];
      if (tables is! Map<String, dynamic>) {
        return const BackupValidationResult(
          isValid: false,
          errorMessage: 'El archivo de respaldo no contiene la estructura de tablas necesaria.',
        );
      }

      DateTime? exportedAt;
      if (decoded['exportedAt'] != null) {
        try {
          exportedAt = DateTime.parse(decoded['exportedAt'].toString());
        } catch (_) {}
      }

      final accounts = (tables['accounts'] as List<dynamic>?) ?? [];
      final transactions = (tables['transactions'] as List<dynamic>?) ?? [];
      final debts = (tables['debts'] as List<dynamic>?) ?? [];
      final debtPayments = (tables['debt_payments'] as List<dynamic>?) ?? [];
      final budgets = (tables['budgets'] as List<dynamic>?) ?? [];
      final recurring = (tables['recurring_transactions'] as List<dynamic>?) ?? [];
      final goals = (tables['savings_goals'] as List<dynamic>?) ?? [];
      final goalTransactions = (tables['goal_transactions'] as List<dynamic>?) ?? [];
      final rules = (decoded['userLearnedRules'] as List<dynamic>?) ?? [];

      final summary = BackupSummary(
        app: decoded['app']?.toString() ?? appIdentifier,
        schemaVersion: (decoded['schemaVersion'] as num?)?.toInt() ?? 1,
        exportedAt: exportedAt,
        accountsCount: accounts.length,
        transactionsCount: transactions.length,
        debtsCount: debts.length,
        debtPaymentsCount: debtPayments.length,
        budgetsCount: budgets.length,
        recurringCount: recurring.length,
        goalsCount: goals.length,
        goalTransactionsCount: goalTransactions.length,
        learnedRulesCount: rules.length,
      );

      return BackupValidationResult(
        isValid: true,
        summary: summary,
        parsedData: decoded,
      );
    } catch (e) {
      return BackupValidationResult(
        isValid: false,
        errorMessage: 'Error al interpretar el archivo JSON: $e',
      );
    }
  }

  /// Restaura los datos del respaldo aplicando el modo seleccionado ([ImportMode])
  /// y recarga los providers de la aplicación.
  static Future<ImportResult> restoreBackup({
    required Map<String, dynamic> backupData,
    required ImportMode mode,
    BuildContext? context,
  }) async {
    try {
      final tables = backupData['tables'] as Map<String, dynamic>?;
      if (tables == null) {
        return const ImportResult(
          success: false,
          message: 'Estructura de tablas ausente en los datos del respaldo.',
        );
      }

      final isReplace = mode == ImportMode.replace;

      // 1. Restaurar en base de datos SQLite en transacción
      final insertedRecords = await DBHelper.instance.restoreAllTableData(
        tables,
        isReplaceMode: isReplace,
      );

      // 2. Restaurar SharedPreferences (preferencias y reglas)
      final prefs = await SharedPreferences.getInstance();

      final preferences = backupData['preferences'] as Map<String, dynamic>?;
      if (preferences != null) {
        if (preferences.containsKey('selected_currency')) {
          await prefs.setString('selected_currency', preferences['selected_currency'].toString());
        }
        if (isReplace) {
          if (preferences.containsKey('theme_mode')) {
            await prefs.setString('theme_mode', preferences['theme_mode'].toString());
          }
          if (preferences.containsKey('privacy_mode')) {
            await prefs.setBool('privacy_mode', preferences['privacy_mode'] == true);
          }
          if (preferences.containsKey('smart_alerts_enabled')) {
            await prefs.setBool('smart_alerts_enabled', preferences['smart_alerts_enabled'] == true);
          }
          if (preferences.containsKey('debt_reminders_enabled')) {
            await prefs.setBool('debt_reminders_enabled', preferences['debt_reminders_enabled'] == true);
          }
          if (preferences.containsKey('recurring_reminders_enabled')) {
            await prefs.setBool('recurring_reminders_enabled', preferences['recurring_reminders_enabled'] == true);
          }
          if (preferences.containsKey('budget_warnings_enabled')) {
            await prefs.setBool('budget_warnings_enabled', preferences['budget_warnings_enabled'] == true);
          }
          if (preferences.containsKey('daily_reminder_enabled')) {
            await prefs.setBool('daily_reminder_enabled', preferences['daily_reminder_enabled'] == true);
          }
        }
      }

      // Reglas aprendidas
      final learnedRules = backupData['userLearnedRules'] as List<dynamic>?;
      if (learnedRules != null) {
        if (isReplace) {
          await prefs.setString('notification_sync_learned_rules', jsonEncode(learnedRules));
        } else {
          // Merge: agregar las reglas que no existan por id
          final existingRaw = prefs.getString('notification_sync_learned_rules');
          List<dynamic> currentList = [];
          if (existingRaw != null && existingRaw.isNotEmpty) {
            try {
              currentList = jsonDecode(existingRaw) as List<dynamic>;
            } catch (_) {}
          }
          final existingIds = currentList
              .map((r) => (r as Map<String, dynamic>)['id']?.toString())
              .whereType<String>()
              .toSet();

          for (final rule in learnedRules) {
            if (rule is Map<String, dynamic>) {
              final id = rule['id']?.toString();
              if (id != null && !existingIds.contains(id)) {
                currentList.add(rule);
              }
            }
          }
          await prefs.setString('notification_sync_learned_rules', jsonEncode(currentList));
        }
      }

      // 3. Recargar todos los Providers activos en memoria
      if (context != null && context.mounted) {
        final financeProvider = context.read<FinanceProvider>();
        final accountProvider = context.read<AccountProvider>();
        final budgetProvider = context.read<BudgetProvider>();
        final debtProvider = context.read<DebtProvider>();
        final recurringProvider = context.read<RecurringProvider>();
        final goalProvider = context.read<GoalProvider>();
        final currencyProvider = context.read<CurrencyProvider>();
        final syncProvider = context.read<NotificationSyncProvider>();
        final notifSettings = context.read<NotificationSettingsProvider>();

        await financeProvider.loadTransactions();
        await accountProvider.loadAccounts(financeProvider.transactions);
        await budgetProvider.loadBudgets();
        budgetProvider.updateSpending(financeProvider.transactions);
        await debtProvider.loadDebts();
        await recurringProvider.loadRecurring();
        await goalProvider.loadGoals();
        await currencyProvider.loadCurrency();
        await syncProvider.reloadSettings();
        await notifSettings.reloadPreferences();
      }

      final validation = validateAndSummarizeJson(jsonEncode(backupData));

      return ImportResult(
        success: true,
        message: isReplace
            ? 'Copia restaurada exitosamente. Se restablecieron $insertedRecords registros.'
            : 'Datos combinados exitosamente. Se integraron nuevos registros sin alterar los existentes.',
        importedCount: insertedRecords,
        summary: validation.summary,
      );
    } catch (e) {
      debugPrint('Error restaurando copia de seguridad: $e');
      return ImportResult(
        success: false,
        message: 'Ocurrió un error durante la restauración: $e',
      );
    }
  }
}
