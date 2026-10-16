import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/formatters.dart';

class SecurityProvider with ChangeNotifier {
  static const _pinHashKey = 'sp_security_pin_hash';
  static const _biometricsKey = 'sp_biometrics_enabled';
  static const _autoLockKey = 'sp_autolock_enabled';
  static const _privacyModeKey = 'sp_privacy_mode_enabled';

  final LocalAuthentication _localAuth;

  SecurityProvider({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  bool _isInitialized = false;
  bool _isPinSet = false;
  String? _storedPinHash;
  bool _isBiometricsEnabled = false;
  bool _isAutoLockEnabled = true;
  bool _isPrivacyModeEnabled = false;
  bool _isAppLocked = false;
  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = [];

  bool get isInitialized => _isInitialized;
  bool get isPinSet => _isPinSet;
  bool get isBiometricsEnabled => _isBiometricsEnabled;
  bool get isAutoLockEnabled => _isAutoLockEnabled;
  bool get isPrivacyModeEnabled => _isPrivacyModeEnabled;
  bool get isAppLocked => _isAppLocked;
  bool get canCheckBiometrics => _canCheckBiometrics;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get isSecurityConfigured => _isPinSet || _isBiometricsEnabled;

  String get biometricsLabel {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID / Reconocimiento facial';
    }
    return 'Huella dactilar';
  }

  static const String _pinSalt = 'BalanceApp_Salt_2026_#9f!';

  /// Criptográficamente seguro con SHA-256 y salting para protección contra rainbow tables
  static String hashPin(String pin) {
    final bytes = utf8.encode('$_pinSalt$pin$_pinSalt');
    return sha256.convert(bytes).toString();
  }

  /// Hash sin salt utilizado en versiones anteriores (para retrocompatibilidad)
  static String hashLegacyPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  /// Inicializa y carga la configuración de seguridad desde el almacenamiento local
  Future<void> loadSecuritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    _storedPinHash = prefs.getString(_pinHashKey);
    _isPinSet = _storedPinHash != null && _storedPinHash!.isNotEmpty;
    _isBiometricsEnabled = prefs.getBool(_biometricsKey) ?? false;
    _isAutoLockEnabled = prefs.getBool(_autoLockKey) ?? true;
    _isPrivacyModeEnabled = prefs.getBool(_privacyModeKey) ?? false;

    // Sincronizar el estado del formateador de privacidad
    Formatters.isPrivacyMode = _isPrivacyModeEnabled;

    // Verificar soporte de hardware para biometría
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      _canCheckBiometrics = isSupported && canCheck;
      if (_canCheckBiometrics) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }
    } catch (e) {
      debugPrint('Error verificando hardware biométrico: $e');
      _canCheckBiometrics = false;
      _availableBiometrics = [];
    }

    // Si tiene seguridad configurada y el bloqueo automático está activo, bloquear al iniciar
    if (isSecurityConfigured && _isAutoLockEnabled) {
      _isAppLocked = true;
    } else {
      _isAppLocked = false;
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Configura o actualiza el PIN de 4 dígitos
  Future<bool> setPin(String newPin) async {
    if (newPin.length != 4) return false;
    final hash = hashPin(newPin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHashKey, hash);
    _storedPinHash = hash;
    _isPinSet = true;
    _isAppLocked = false;
    notifyListeners();
    return true;
  }

  /// Valida el PIN ingresado por el usuario con soporte y migración para hashes heredados
  bool verifyPin(String inputPin) {
    if (_storedPinHash == null) return false;

    // 1. Verificación estándar con salting
    final match = hashPin(inputPin) == _storedPinHash;
    if (match) {
      _isAppLocked = false;
      notifyListeners();
      return true;
    }

    // 2. Retrocompatibilidad: verificar si coincide con el hash legacy sin salt
    final legacyMatch = hashLegacyPin(inputPin) == _storedPinHash;
    if (legacyMatch) {
      final newHash = hashPin(inputPin);
      _storedPinHash = newHash;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString(_pinHashKey, newHash);
      });
      _isAppLocked = false;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Elimina el PIN y desactiva la biometría
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.setBool(_biometricsKey, false);
    _storedPinHash = null;
    _isPinSet = false;
    _isBiometricsEnabled = false;
    _isAppLocked = false;
    notifyListeners();
  }

  /// Habilita o deshabilita la autenticación biométrica
  Future<void> toggleBiometrics(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _isBiometricsEnabled = enabled;
    await prefs.setBool(_biometricsKey, enabled);
    notifyListeners();
  }

  /// Habilita o deshabilita el bloqueo automático al salir
  Future<void> toggleAutoLock(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _isAutoLockEnabled = enabled;
    await prefs.setBool(_autoLockKey, enabled);
    notifyListeners();
  }

  /// Alterna el modo de privacidad (oculta cifras en pantallas principales)
  Future<void> togglePrivacyMode() async {
    _isPrivacyModeEnabled = !_isPrivacyModeEnabled;
    Formatters.isPrivacyMode = _isPrivacyModeEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyModeKey, _isPrivacyModeEnabled);
    notifyListeners();
  }

  /// Bloquea la app inmediatamente (si hay PIN o biometría)
  void lockApp() {
    if (isSecurityConfigured && !_isAppLocked) {
      _isAppLocked = true;
      notifyListeners();
    }
  }

  /// Desbloquea la app
  void unlockApp() {
    if (_isAppLocked) {
      _isAppLocked = false;
      notifyListeners();
    }
  }

  /// Ejecuta el prompt de autenticación biométrica nativo del sistema operativo
  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricsEnabled || !_canCheckBiometrics) return false;

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Autentícate para acceder a tu información financiera',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        _isAppLocked = false;
        notifyListeners();
      }
      return authenticated;
    } catch (e) {
      debugPrint('Error en autenticación biométrica: $e');
      return false;
    }
  }
}
