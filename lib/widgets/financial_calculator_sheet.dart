import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../utils/calculator_evaluator.dart';
import '../utils/formatters.dart';

class FinancialCalculatorSheet extends StatefulWidget {
  final double? initialValue;
  final String? title;

  const FinancialCalculatorSheet({
    super.key,
    this.initialValue,
    this.title,
  });

  /// Abre la calculadora en un modal BottomSheet y retorna el valor resultante
  static Future<double?> show(
    BuildContext context, {
    double? initialValue,
    String? title,
  }) async {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FinancialCalculatorSheet(
        initialValue: initialValue,
        title: title,
      ),
    );
  }

  @override
  State<FinancialCalculatorSheet> createState() => _FinancialCalculatorSheetState();
}

class _FinancialCalculatorSheetState extends State<FinancialCalculatorSheet> {
  String _expression = '';
  double? _liveResult;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null && widget.initialValue! > 0) {
      _expression = CalculatorEvaluator.formatResult(widget.initialValue!);
      _liveResult = widget.initialValue;
    }
  }

  void _onDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      _expression += digit;
      _updateLiveResult();
    });
  }

  void _onOperator(String op) {
    HapticFeedback.selectionClick();
    if (_expression.isEmpty) return;

    final lastChar = _expression[_expression.length - 1];
    if ('+-×÷'.contains(lastChar)) {
      // Reemplazar operador previo
      setState(() {
        _expression = _expression.substring(0, _expression.length - 1) + op;
      });
      return;
    }

    setState(() {
      _expression += ' $op ';
      _updateLiveResult();
    });
  }

  void _onDecimal() {
    HapticFeedback.lightImpact();
    // Obtener el último número ingresado
    final parts = _expression.split(' ');
    final lastPart = parts.isNotEmpty ? parts.last : '';
    if (lastPart.contains('.')) return;

    setState(() {
      if (_expression.isEmpty || _expression.endsWith(' ')) {
        _expression += '0.';
      } else {
        _expression += '.';
      }
      _updateLiveResult();
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    if (_expression.isEmpty) return;

    setState(() {
      if (_expression.endsWith(' ')) {
        // Quitar operador y espacios (ej. " + ")
        _expression = _expression.trimRight();
        _expression = _expression.substring(0, _expression.length - 1).trimRight();
      } else {
        _expression = _expression.substring(0, _expression.length - 1);
      }
      _updateLiveResult();
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _expression = '';
      _liveResult = null;
    });
  }

  void _onEquals() {
    HapticFeedback.mediumImpact();
    final result = CalculatorEvaluator.evaluate(_expression);
    if (result != null) {
      setState(() {
        _expression = CalculatorEvaluator.formatResult(result);
        _liveResult = result;
      });
    }
  }

  void _onConfirm() {
    HapticFeedback.mediumImpact();
    final result = CalculatorEvaluator.evaluate(_expression) ?? _liveResult ?? 0.0;
    Navigator.pop(context, result > 0 ? result : null);
  }

  void _updateLiveResult() {
    _liveResult = CalculatorEvaluator.evaluate(_expression);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currency = context.watch<CurrencyProvider>().currency;

    final displayExpression = _expression.isEmpty ? '0' : _expression;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre superior
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Cabecera con título y botón de cerrar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calculate_rounded,
                          size: 18,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title ?? 'Calculadora Financiera',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Pantalla de la Calculadora (Fórmula y Resultado en Vivo)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151C2C) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Expresión escrita
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        displayExpression,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Resultado en vivo con moneda
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currency.code,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        Text(
                          _liveResult != null
                              ? '= ${Formatters.currency(_liveResult!, currency)}'
                              : '= ${currency.symbol} 0',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Teclado Matemático Táctil
              _buildKeypad(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(BuildContext context) {
    return Column(
      children: [
        // Fila 1: C, ÷, ×, ⌫
        Row(
          children: [
            _KeypadButton(
              text: 'C',
              color: const Color(0xFFF43F5E),
              isAccent: true,
              onTap: _onClear,
            ),
            _KeypadButton(
              text: '÷',
              color: const Color(0xFF6366F1),
              isAccent: true,
              onTap: () => _onOperator('÷'),
            ),
            _KeypadButton(
              text: '×',
              color: const Color(0xFF6366F1),
              isAccent: true,
              onTap: () => _onOperator('×'),
            ),
            _KeypadButton(
              icon: Icons.backspace_outlined,
              isAccent: true,
              onTap: _onBackspace,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fila 2: 7, 8, 9, -
        Row(
          children: [
            _KeypadButton(text: '7', onTap: () => _onDigit('7')),
            _KeypadButton(text: '8', onTap: () => _onDigit('8')),
            _KeypadButton(text: '9', onTap: () => _onDigit('9')),
            _KeypadButton(
              text: '-',
              color: const Color(0xFF6366F1),
              isAccent: true,
              onTap: () => _onOperator('-'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fila 3: 4, 5, 6, +
        Row(
          children: [
            _KeypadButton(text: '4', onTap: () => _onDigit('4')),
            _KeypadButton(text: '5', onTap: () => _onDigit('5')),
            _KeypadButton(text: '6', onTap: () => _onDigit('6')),
            _KeypadButton(
              text: '+',
              color: const Color(0xFF6366F1),
              isAccent: true,
              onTap: () => _onOperator('+'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fila 4: 1, 2, 3, =
        Row(
          children: [
            _KeypadButton(text: '1', onTap: () => _onDigit('1')),
            _KeypadButton(text: '2', onTap: () => _onDigit('2')),
            _KeypadButton(text: '3', onTap: () => _onDigit('3')),
            _KeypadButton(
              text: '=',
              color: const Color(0xFF06B6D4),
              isAccent: true,
              onTap: _onEquals,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Fila 5: 0, 00, ., ✓ Listo
        Row(
          children: [
            _KeypadButton(text: '0', onTap: () => _onDigit('0')),
            _KeypadButton(text: '00', onTap: () => _onDigit('00')),
            _KeypadButton(text: '.', onTap: _onDecimal),
            _KeypadButton(
              text: '✓ Listo',
              isConfirm: true,
              onTap: _onConfirm,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;
  final bool isAccent;
  final bool isConfirm;

  const _KeypadButton({
    this.text,
    this.icon,
    required this.onTap,
    this.color,
    this.isAccent = false,
    this.isConfirm = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    Color textColor;

    if (isConfirm) {
      bgColor = const Color(0xFF4F46E5);
      textColor = Colors.white;
    } else if (isAccent) {
      bgColor = isDark
          ? (color ?? const Color(0xFF6366F1)).withValues(alpha: 0.18)
          : (color ?? const Color(0xFF6366F1)).withValues(alpha: 0.12);
      textColor = color ?? const Color(0xFF4F46E5);
    } else {
      bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
      textColor = theme.colorScheme.onSurface;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isConfirm
                    ? Colors.transparent
                    : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
              ),
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, color: textColor, size: 20)
                : Text(
                    text ?? '',
                    style: TextStyle(
                      fontSize: isConfirm ? 14 : 20,
                      fontWeight: isConfirm ? FontWeight.bold : FontWeight.w700,
                      color: textColor,
                      letterSpacing: isConfirm ? -0.2 : 0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
