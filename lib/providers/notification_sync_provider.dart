import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bank_profile_model.dart';
import '../models/parsed_bank_transaction.dart';
import '../models/transaction_model.dart';
import '../models/user_learned_rule.dart';
import '../services/notification_service.dart';
import '../utils/bank_notification_parser.dart';

class NotificationLogItem {
  final DateTime timestamp;
  final String packageName;
  final String title;
  final String text;
  final String status;
  final bool isSuccess;

  const NotificationLogItem({
    required this.timestamp,
    required this.packageName,
    required this.title,
    required this.text,
    required this.status,
    required this.isSuccess,
  });
}

class NotificationSyncProvider with ChangeNotifier {
  static const _methodChannel = MethodChannel('com.example.personal_finance/notification_sync');
  static const _eventChannel = EventChannel('com.example.personal_finance/notification_stream');

  static const _keyEnabled = 'notification_sync_enabled';
  static const _keyAutoSave = 'notification_sync_auto_save';
  static const _keyEnabledBanks = 'notification_sync_enabled_banks';
  static const _keyBankAccounts = 'notification_sync_bank_accounts';
  static const _keyPendingTransactions = 'notification_sync_pending';
  static const _keyLearnedRules = 'notification_sync_learned_rules';

  bool _isEnabled = false;
  bool _autoSave = false; // Por defecto confirmar antes de guardar
  bool _isPermissionGranted = false;
  Map<String, bool> _enabledBanks = {};
  Map<String, String> _bankAccountMapping = {}; // bankId -> accountId
  List<ParsedBankTransaction> _pendingTransactions = [];
  final List<NotificationLogItem> _notificationLogs = [];
  List<UserLearnedRule> _userRules = [];

  StreamSubscription? _eventSubscription;

  bool get isEnabled => _isEnabled;
  bool get autoSave => _autoSave;
  bool get isPermissionGranted => _isPermissionGranted;
  Map<String, bool> get enabledBanks => _enabledBanks;
  Map<String, String> get bankAccountMapping => _bankAccountMapping;
  List<ParsedBankTransaction> get pendingTransactions => _pendingTransactions;
  int get pendingCount => _pendingTransactions.length;
  List<NotificationLogItem> get notificationLogs => _notificationLogs;
  List<UserLearnedRule> get userRules => _userRules;

  void _addLog(NotificationLogItem item) {
    _notificationLogs.insert(0, item);
    if (_notificationLogs.length > 25) {
      _notificationLogs.removeLast();
    }
  }

  void clearLogs() {
    _notificationLogs.clear();
    notifyListeners();
  }

  NotificationSyncProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_keyEnabled) ?? false;
    _autoSave = prefs.getBool(_keyAutoSave) ?? false;

    // Bancos habilitados
    final banksJson = prefs.getString(_keyEnabledBanks);
    if (banksJson != null) {
      try {
        final decoded = jsonDecode(banksJson) as Map<String, dynamic>;
        _enabledBanks = decoded.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    } else {
      // Por defecto todos los bancos soportados están activos
      for (final bank in BankProfileModel.supportedBanks) {
        _enabledBanks[bank.id] = true;
      }
    }

    // Mapeo bancos a cuentas
    final accountsJson = prefs.getString(_keyBankAccounts);
    if (accountsJson != null) {
      try {
        final decoded = jsonDecode(accountsJson) as Map<String, dynamic>;
        _bankAccountMapping = decoded.map((k, v) => MapEntry(k, v as String));
      } catch (_) {}
    }

    // Reglas de aprendizaje personalizadas
    final rulesJson = prefs.getString(_keyLearnedRules);
    if (rulesJson != null && rulesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rulesJson) as List<dynamic>;
        _userRules = decoded
            .map((e) => UserLearnedRule.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error cargando reglas aprendidas: $e');
      }
    }

    // Transacciones pendientes no confirmadas
    final pendingJson = prefs.getString(_keyPendingTransactions);
    if (pendingJson != null) {
      try {
        final list = jsonDecode(pendingJson) as List<dynamic>;
        final loaded = list
            .map((item) => ParsedBankTransaction.fromMap(item as Map<String, dynamic>))
            .toList();

        // Filtro de saneamiento preventivo: descartar cualquier transacción residual que no pertenezca a contexto financiero
        _pendingTransactions = loaded.where((tx) {
          if (tx.bankId.startsWith('custom-')) return true;
          final matchedBank = BankProfileModel.findById(tx.bankId);
          return BankNotificationParser.isFinancialContext(
            packageName: tx.packageName,
            fullText: '${tx.rawTitle} ${tx.rawText}',
            matchedBank: matchedBank,
          );
        }).toList();

        if (_pendingTransactions.length != loaded.length) {
          await _savePending();
        }
      } catch (_) {}
    }

    await checkPermission();

    if (_isEnabled && _isPermissionGranted) {
      _startListening();
      await fetchQueuedNotifications();
    }

    notifyListeners();
  }

  /// Verifica si el usuario concedió permiso de acceso a notificaciones en Android
  Future<bool> checkPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool granted = await _methodChannel.invokeMethod('isPermissionGranted') ?? false;
        _isPermissionGranted = granted;
        notifyListeners();
        return granted;
      } catch (e) {
        debugPrint('Error comprobando permisos de notificación: $e');
      }
    }
    _isPermissionGranted = false;
    return false;
  }

  /// Abre la pantalla de Ajustes del sistema de Android para conceder acceso
  Future<void> requestPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('requestPermission');
      } catch (e) {
        debugPrint('Error solicitando permisos de notificación: $e');
      }
    }
  }

  /// Fuerza a Android a reconectar el listener service si quedó descolgado o inactivo
  Future<bool> rebindService() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final bool success = await _methodChannel.invokeMethod('rebindService') ?? false;
        await checkPermission();
        if (_isEnabled && _isPermissionGranted) {
          _startListening();
          await fetchQueuedNotifications();
        }
        return success;
      } catch (e) {
        debugPrint('Error reconectando servicio de notificaciones: $e');
      }
    }
    return false;
  }

  /// Activa o desactiva la sincronización general
  Future<void> toggleSync(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);

    if (value) {
      await checkPermission();
      if (_isPermissionGranted) {
        _startListening();
        await fetchQueuedNotifications();
      }
    } else {
      _stopListening();
    }

    notifyListeners();
  }

  /// Cambia el modo entre Auto-Guardar directo o Confirmación previa
  Future<void> toggleAutoSave(bool value) async {
    _autoSave = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSave, value);
    notifyListeners();
  }

  /// Activa o desactiva un banco individual
  Future<void> toggleBank(String bankId, bool enabled) async {
    _enabledBanks[bankId] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEnabledBanks, jsonEncode(_enabledBanks));
    notifyListeners();
  }

  bool isBankEnabled(String bankId) {
    return _enabledBanks[bankId] ?? true;
  }

  /// Asocia un banco con una cuenta específica de la app
  Future<void> setBankAccount(String bankId, String? accountId) async {
    if (accountId == null) {
      _bankAccountMapping.remove(bankId);
    } else {
      _bankAccountMapping[bankId] = accountId;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBankAccounts, jsonEncode(_bankAccountMapping));
    notifyListeners();
  }

  String? getBankAccountId(String bankId) {
    return _bankAccountMapping[bankId];
  }

  void _startListening() {
    _stopListening();
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            if (event is Map) {
              final map = Map<String, dynamic>.from(event);
              processIncomingRawNotification(map);
            }
          },
          onError: (dynamic error) {
            debugPrint('Error en stream de notificaciones: $error');
          },
        );
      } catch (e) {
        debugPrint('No se pudo iniciar listener de notificaciones: $e');
      }
    }
  }

  void _stopListening() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  /// Consulta notificaciones en cola que llegaron mientras la app estuvo cerrada
  Future<void> fetchQueuedNotifications() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final List<dynamic>? queued = await _methodChannel.invokeMethod('getQueuedNotifications');
        if (queued != null && queued.isNotEmpty) {
          for (final item in queued) {
            if (item is Map) {
              processIncomingRawNotification(Map<String, dynamic>.from(item));
            }
          }
          await _methodChannel.invokeMethod('clearQueuedNotifications');
        }
      } catch (e) {
        debugPrint('Error obteniendo notificaciones en cola: $e');
      }
    }
  }

  /// Procesa una notificación entrante
  ParsedBankTransaction? processIncomingRawNotification(Map<String, dynamic> raw) {
    final packageName = raw['packageName']?.toString() ?? '';
    final title = raw['title']?.toString() ?? '';
    final text = raw['text']?.toString() ?? '';
    final timestamp = raw['timestamp'] as int?;
    final date = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.now();

    if (!_isEnabled) {
      _addLog(NotificationLogItem(
        timestamp: date,
        packageName: packageName,
        title: title,
        text: text,
        status: 'Ignorado: Sincronización desactivada en la app',
        isSuccess: false,
      ));
      notifyListeners();
      return null;
    }

    final parsed = BankNotificationParser.parse(
      packageName: packageName,
      title: title,
      text: text,
      timestampMs: timestamp,
      userRules: _userRules,
    );

    if (parsed == null) {
      _addLog(NotificationLogItem(
        timestamp: date,
        packageName: packageName,
        title: title,
        text: text,
        status: 'No coincide: No contiene monto o patrón bancario reconocido',
        isSuccess: false,
      ));
      notifyListeners();
      return null;
    }

    // Verificar si el banco está habilitado por el usuario (las reglas de usuario tienen habilitación propia)
    if (!parsed.bankId.startsWith('custom-') && !isBankEnabled(parsed.bankId)) {
      _addLog(NotificationLogItem(
        timestamp: date,
        packageName: packageName,
        title: title,
        text: text,
        status: 'Ignorado: Banco ${parsed.bankName} desactivado en la lista',
        isSuccess: false,
      ));
      notifyListeners();
      return null;
    }

    // Asignar cuenta asociada si existe (o la cuenta predeterminada de la regla de usuario)
    final linkedAccount = parsed.accountId ?? _bankAccountMapping[parsed.bankId];
    final txWithAccount = parsed.copyWith(accountId: linkedAccount);

    // Evitar transacciones idénticas repetidas en los últimos 2 minutos
    final isDuplicate = _pendingTransactions.any(
      (p) =>
          p.bankId == txWithAccount.bankId &&
          p.amount == txWithAccount.amount &&
          p.merchantOrPayee == txWithAccount.merchantOrPayee &&
          txWithAccount.timestamp.difference(p.timestamp).inMinutes.abs() < 2,
    );

    if (isDuplicate) {
      _addLog(NotificationLogItem(
        timestamp: date,
        packageName: packageName,
        title: title,
        text: text,
        status: 'Ignorado: Transacción duplicada en los últimos 2 min',
        isSuccess: false,
      ));
      notifyListeners();
      return null;
    }

    _pendingTransactions.insert(0, txWithAccount);
    _savePending();
    _notifyIncomingTransaction(txWithAccount);
    _addLog(NotificationLogItem(
      timestamp: date,
      packageName: packageName,
      title: title,
      text: text,
      status: 'Detectado: ${parsed.merchantOrPayee} (${parsed.bankName}) por \$${parsed.amount.toStringAsFixed(0)}',
      isSuccess: true,
    ));
    notifyListeners();
    return txWithAccount;
  }

  Future<void> _notifyIncomingTransaction(ParsedBankTransaction tx) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifyEnabled = prefs.getBool('pref_notify_bank_transactions') ?? true;
      if (!notifyEnabled) return;

      final formattedAmount = '\$${tx.amount.toStringAsFixed(0)}';
      final actionType = tx.type == TransactionType.income ? 'Ingreso detectado' : 'Gasto detectado';
      await NotificationService.showNotification(
        id: (tx.id.hashCode % 10000) + 6000,
        title: '💳 $actionType (${tx.bankName})',
        body: '$actionType de $formattedAmount en ${tx.merchantOrPayee}. Toca para registrarlo en My Money.',
        channelId: NotificationService.channelBankSync,
        payload: jsonEncode({'action': 'open_bank_sync', 'txId': tx.id}),
      );
    } catch (e) {
      debugPrint('Error notificando transacción entrante: $e');
    }
  }

  /// Descarta una transacción pendiente
  void dismissPending(String id) {
    _pendingTransactions.removeWhere((t) => t.id == id);
    _savePending();
    notifyListeners();
  }

  /// Limpia todas las transacciones pendientes
  void clearAllPending() {
    _pendingTransactions.clear();
    _savePending();
    notifyListeners();
  }

  Future<void> _saveLearnedRules() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _userRules.map((r) => r.toMap()).toList();
    await prefs.setString(_keyLearnedRules, jsonEncode(list));
  }

  /// Añade una nueva regla aprendida por el usuario
  Future<void> addLearnedRule(UserLearnedRule rule) async {
    _userRules.insert(0, rule);
    await _saveLearnedRules();
    notifyListeners();
  }

  /// Actualiza una regla aprendida existente
  Future<void> updateLearnedRule(UserLearnedRule rule) async {
    final index = _userRules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _userRules[index] = rule;
      await _saveLearnedRules();
      notifyListeners();
    }
  }

  /// Elimina una regla aprendida
  Future<void> deleteLearnedRule(String id) async {
    _userRules.removeWhere((r) => r.id == id);
    await _saveLearnedRules();
    notifyListeners();
  }

  /// Activa o desactiva una regla aprendida
  Future<void> toggleLearnedRule(String id, bool enabled) async {
    final index = _userRules.indexWhere((r) => r.id == id);
    if (index != -1) {
      _userRules[index] = _userRules[index].copyWith(isEnabled: enabled);
      await _saveLearnedRules();
      notifyListeners();
    }
  }

  /// Reprocesa un registro de notificación capturado con las reglas actuales
  ParsedBankTransaction? reprocessLogItem(NotificationLogItem logItem) {
    return processIncomingRawNotification({
      'packageName': logItem.packageName,
      'title': logItem.title,
      'text': logItem.text,
      'timestamp': logItem.timestamp.millisecondsSinceEpoch,
    });
  }

  Future<void> _savePending() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _pendingTransactions.map((t) => t.toMap()).toList();
    await prefs.setString(_keyPendingTransactions, jsonEncode(list));
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }
}
