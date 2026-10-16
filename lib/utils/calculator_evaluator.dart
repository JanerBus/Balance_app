/// Motor seguro de evaluación de expresiones aritméticas para la calculadora financiera
class CalculatorEvaluator {
  /// Evalúa una expresión matemática con operadores +, -, *, /, ×, ÷
  /// Respetando la jerarquía de operaciones (multiplicación y división antes que suma y resta).
  static double? evaluate(String expression) {
    if (expression.trim().isEmpty) return null;
    try {
      // Normalizar operadores y caracteres
      String sanitized = expression
          .replaceAll('×', '*')
          .replaceAll('x', '*')
          .replaceAll('X', '*')
          .replaceAll('÷', '/')
          .replaceAll(' ', '')
          .replaceAll(',', '.');

      // Si termina con un operador (ej. "5000+"), quitamos el operador final para evaluación en vivo
      while (sanitized.isNotEmpty &&
          (sanitized.endsWith('+') ||
              sanitized.endsWith('-') ||
              sanitized.endsWith('*') ||
              sanitized.endsWith('/'))) {
        sanitized = sanitized.substring(0, sanitized.length - 1);
      }

      if (sanitized.isEmpty) return null;

      // Tokenizar en números y operadores
      final tokens = <dynamic>[];
      final numberBuffer = StringBuffer();

      for (int i = 0; i < sanitized.length; i++) {
        final char = sanitized[i];
        if ('0123456789.'.contains(char)) {
          numberBuffer.write(char);
        } else if ('+-*/'.contains(char)) {
          if (numberBuffer.isNotEmpty) {
            final parsed = double.tryParse(numberBuffer.toString());
            if (parsed == null) return null;
            tokens.add(parsed);
            numberBuffer.clear();
          } else if (char == '-' && (tokens.isEmpty || tokens.last is String)) {
            // Manejar número negativo
            numberBuffer.write(char);
            continue;
          }
          tokens.add(char);
        }
      }

      if (numberBuffer.isNotEmpty) {
        final parsed = double.tryParse(numberBuffer.toString());
        if (parsed == null) return null;
        tokens.add(parsed);
      }

      if (tokens.isEmpty) return null;
      if (tokens.length == 1 && tokens.first is double) return tokens.first as double;

      // Paso 1: Resolver multiplicación y división (* y /)
      final pass1 = <dynamic>[];
      int i = 0;
      while (i < tokens.length) {
        final token = tokens[i];
        if (token == '*' || token == '/') {
          if (pass1.isEmpty || i + 1 >= tokens.length || tokens[i + 1] is! double) {
            return null;
          }
          final prev = pass1.removeLast() as double;
          final next = tokens[i + 1] as double;
          if (token == '*') {
            pass1.add(prev * next);
          } else {
            if (next == 0) return null; // Prevenir división por cero
            pass1.add(prev / next);
          }
          i += 2;
        } else {
          pass1.add(token);
          i++;
        }
      }

      // Paso 2: Resolver suma y resta (+ y -)
      if (pass1.isEmpty || pass1.first is! double) return null;
      double result = pass1.first as double;
      int j = 1;
      while (j < pass1.length) {
        final op = pass1[j];
        if (j + 1 >= pass1.length || pass1[j + 1] is! double) return null;
        final next = pass1[j + 1] as double;
        if (op == '+') {
          result += next;
        } else if (op == '-') {
          result -= next;
        }
        j += 2;
      }

      // Prevenir NaN o Infinitos
      if (result.isNaN || result.isInfinite) return null;

      return result;
    } catch (_) {
      return null;
    }
  }

  /// Formatea el número resultante eliminando decimales sobrantes si es entero
  static String formatResult(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
}
