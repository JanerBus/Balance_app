import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio central para despachar y gestionar notificaciones locales en el dispositivo
class NotificationService {
  static const MethodChannel _channel = MethodChannel('com.example.personal_finance/notifications');

  // Canales oficiales definidos en el sistema
  static const String channelBankSync = 'channel_bank_sync';
  static const String channelBudgets = 'channel_budgets';
  static const String channelDebts = 'channel_debts';
  static const String channelRecurring = 'channel_recurring';
  static const String channelDaily = 'channel_daily_reminder';

  static Function(String payload)? _onNotificationClicked;
  static bool _initialized = false;

  /// Inicializa la escucha de clics en notificaciones
  static Future<void> initialize({Function(String payload)? onNotificationClicked}) async {
    if (_initialized) {
      if (onNotificationClicked != null) _onNotificationClicked = onNotificationClicked;
      return;
    }
    _onNotificationClicked = onNotificationClicked;

    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationClicked') {
          final payload = call.arguments as String?;
          if (payload != null && _onNotificationClicked != null) {
            _onNotificationClicked!(payload);
          }
        }
      });
    }

    _initialized = true;
  }

  /// Consulta si la app tiene permiso del sistema para emitir notificaciones
  static Future<bool> isPermissionGranted() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? granted = await _channel.invokeMethod('isPermissionGranted');
      return granted ?? false;
    } catch (e) {
      debugPrint('Error verificando permiso de notificaciones: $e');
      return false;
    }
  }

  /// Solicita el permiso POST_NOTIFICATIONS (Android 13+)
  static Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final bool? granted = await _channel.invokeMethod('requestPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('Error solicitando permiso de notificaciones: $e');
      return false;
    }
  }

  /// Muestra una notificación local en el dispositivo
  static Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Notificación simulada [$channelId] #$id: $title - $body');
      return true;
    }

    try {
      final bool? success = await _channel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'channelId': channelId,
        'payload': payload,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error emitiendo notificación: $e');
      return false;
    }
  }

  /// Cancela una notificación activa por su identificador
  static Future<void> cancelNotification(int id) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelNotification', {'id': id});
    } catch (e) {
      debugPrint('Error cancelando notificación: $e');
    }
  }

  /// Obtiene el payload inicial si la app fue abierta desde una notificación
  static Future<String?> getInitialPayload() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod('getInitialPayload');
    } catch (e) {
      return null;
    }
  }
}
