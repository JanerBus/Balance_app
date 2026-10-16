import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../providers/security_provider.dart';

enum LockScreenMode {
  unlock, // Desbloquear la app bloqueada
  verify, // Verificar PIN antes de una acción sensible
  create, // Crear un nuevo PIN
}

class LockScreen extends StatefulWidget {
  final LockScreenMode mode;
  final VoidCallback? onSuccess;
  final String? title;

  const LockScreen({
    super.key,
    this.mode = LockScreenMode.unlock,
    this.onSuccess,
    this.title,
  });

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  String _firstStepPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    // Si estamos en modo desbloqueo o verificación y biometría está habilitada, disparar automáticamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mode == LockScreenMode.unlock || widget.mode == LockScreenMode.verify) {
        _tryBiometricAuth();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometricAuth() async {
    final security = context.read<SecurityProvider>();
    if (security.isBiometricsEnabled && security.canCheckBiometrics) {
      final success = await security.authenticateWithBiometrics();
      if (success && mounted) {
        widget.onSuccess?.call();
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      }
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();

    setState(() {
      _enteredPin += digit;
      _errorMessage = '';
    });

    if (_enteredPin.length == 4) {
      _processCompletePin();
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _errorMessage = '';
    });
  }

  Future<void> _processCompletePin() async {
    final security = context.read<SecurityProvider>();

    if (widget.mode == LockScreenMode.create) {
      if (!_isConfirming) {
        // Paso 1: guardamos el primer PIN y solicitamos confirmación
        setState(() {
          _firstStepPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        // Paso 2: comparar confirmación
        if (_enteredPin == _firstStepPin) {
          await security.setPin(_enteredPin);
          if (mounted) {
            HapticFeedback.mediumImpact();
            widget.onSuccess?.call();
            if (Navigator.canPop(context)) {
              Navigator.pop(context, true);
            }
          }
        } else {
          _triggerError('Los códigos no coinciden. Intenta de nuevo.');
          setState(() {
            _isConfirming = false;
            _firstStepPin = '';
            _enteredPin = '';
          });
        }
      }
    } else {
      // Modo Unlock o Verify
      final isValid = security.verifyPin(_enteredPin);
      if (isValid) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          widget.onSuccess?.call();
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        }
      } else {
        _triggerError('PIN incorrecto');
        setState(() {
          _enteredPin = '';
        });
      }
    }
  }

  void _triggerError(String msg) {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = msg;
    });
    _shakeController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final security = context.watch<SecurityProvider>();

    String headerTitle = widget.title ?? 'Seguridad';
    String instructionText = 'Ingresa tu PIN de 4 dígitos';

    if (widget.mode == LockScreenMode.create) {
      headerTitle = _isConfirming ? 'Confirma tu PIN' : 'Crear PIN de seguridad';
      instructionText = _isConfirming
          ? 'Ingresa nuevamente tu PIN para verificar'
          : 'Define un PIN de 4 dígitos para proteger tus finanzas';
    } else if (widget.mode == LockScreenMode.unlock) {
      headerTitle = 'Balance App';
      instructionText = 'Ingresa tu PIN para desbloquear';
    }

    final canCancel = widget.mode != LockScreenMode.unlock;

    return PopScope(
      canPop: canCancel,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: canCancel
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                ),
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Ícono de Escudo / Seguridad
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 38,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),

              // Título y Subtítulo
              Text(
                headerTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  instructionText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Indicadores de 4 círculos con animación de error (Shake)
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    final hasError = _errorMessage.isNotEmpty;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasError
                            ? colorScheme.error
                            : (isFilled ? colorScheme.primary : Colors.transparent),
                        border: Border.all(
                          color: hasError
                              ? colorScheme.error
                              : (isFilled ? colorScheme.primary : colorScheme.outline),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Mensaje de error
              SizedBox(
                height: 36,
                child: Center(
                  child: _errorMessage.isNotEmpty
                      ? Text(
                          _errorMessage,
                          style: TextStyle(
                            color: colorScheme.error,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),

              const Spacer(flex: 1),

              // Teclado numérico táctil
              _NumericKeypad(
                onDigit: _onDigitPressed,
                onBackspace: _onBackspacePressed,
                onBiometric: (widget.mode != LockScreenMode.create &&
                        security.isBiometricsEnabled &&
                        security.canCheckBiometrics)
                    ? _tryBiometricAuth
                    : null,
                biometricIcon: security.availableBiometrics.contains(BiometricType.face)
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final IconData biometricIcon;

  const _NumericKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    required this.biometricIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _KeypadButton(text: '1', onTap: () => onDigit('1')),
              _KeypadButton(text: '2', onTap: () => onDigit('2')),
              _KeypadButton(text: '3', onTap: () => onDigit('3')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _KeypadButton(text: '4', onTap: () => onDigit('4')),
              _KeypadButton(text: '5', onTap: () => onDigit('5')),
              _KeypadButton(text: '6', onTap: () => onDigit('6')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _KeypadButton(text: '7', onTap: () => onDigit('7')),
              _KeypadButton(text: '8', onTap: () => onDigit('8')),
              _KeypadButton(text: '9', onTap: () => onDigit('9')),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Botón Biométrico (si está disponible) o espacio vacío
              SizedBox(
                width: 72,
                height: 72,
                child: onBiometric != null
                    ? IconButton(
                        icon: Icon(biometricIcon, size: 32),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: onBiometric,
                      )
                    : const SizedBox.shrink(),
              ),
              _KeypadButton(text: '0', onTap: () => onDigit('0')),
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton(
                  icon: const Icon(Icons.backspace_outlined, size: 26),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  onPressed: onBackspace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _KeypadButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
