import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/budget_model.dart';
import '../models/debt_model.dart';
import '../models/currency_model.dart';
import '../utils/formatters.dart';

enum AiIntentType {
  addTransaction,
  queryBalance,
  queryExpenses,
  queryBudgets,
  queryDebts,
  advice,
  help,
  general,
}

class ParsedAiTransaction {
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String accountId;
  final String accountName;
  final DateTime date;
  final String? note;
  final double confidence;
  final String rawText;

  const ParsedAiTransaction({
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.accountId,
    required this.accountName,
    required this.date,
    this.note,
    this.confidence = 0.9,
    required this.rawText,
  });

  TransactionModel toTransactionModel({String? customId}) {
    return TransactionModel(
      id: customId ?? 'tx-ai-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: note ?? 'Registrado con Asistente IA',
      accountId: accountId,
    );
  }
}

class AiAssistantResponse {
  final AiIntentType intent;
  final String message;
  final ParsedAiTransaction? transaction;
  final String source; // 'local' or 'gemini'
  final List<String> suggestions;

  const AiAssistantResponse({
    required this.intent,
    required this.message,
    this.transaction,
    this.source = 'local',
    this.suggestions = const [],
  });
}

class AiFinancialContext {
  final double totalBalance;
  final double monthIncome;
  final double monthExpense;
  final List<AccountModel> accounts;
  final List<TransactionModel> recentTransactions;
  final List<BudgetModel> budgets;
  final List<DebtModel> debts;
  final CurrencyModel currency;

  const AiFinancialContext({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.accounts,
    required this.recentTransactions,
    required this.budgets,
    required this.debts,
    required this.currency,
  });
}

class AiAssistantService {
  static const String prefGeminiApiKey = 'gemini_api_key';
  static const String geminiModel = 'gemini-3.5-flash-lite';

  static Future<String?> getSavedApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(prefGeminiApiKey)?.trim();
    return (key != null && key.isNotEmpty) ? key : null;
  }

  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefGeminiApiKey, apiKey.trim());
  }

  static Future<void> removeApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefGeminiApiKey);
  }

  /// Procesa la entrada del usuario mediante Local NLP o Gemini AI si hay API key configurada.
  static Future<AiAssistantResponse> processUserInput({
    required String input,
    required AiFinancialContext context,
    http.Client? httpClient,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const AiAssistantResponse(
        intent: AiIntentType.help,
        message: '¡Hola! Escribe o dicta lo que quieras registrar o consultar.',
        suggestions: [
          'Ayer gasté 35 mil en pizza con Nequi',
          '¿Cuál es mi saldo total?',
          '¿Cómo van mis presupuestos?',
        ],
      );
    }

    final apiKey = await getSavedApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final geminiResponse = await _queryGemini(
          input: trimmed,
          context: context,
          apiKey: apiKey,
          client: httpClient,
        );
        if (geminiResponse != null) {
          return geminiResponse;
        }
      } catch (e) {
        debugPrint('Gemini fallback to local NLP: $e');
      }
    }

    // Motor Local Offline NLP
    return parseLocalNLP(input: trimmed, context: context);
  }

  /// Motor Local NLP: Extrae transacciones o responde preguntas de saldo/gastos/deudas
  static AiAssistantResponse parseLocalNLP({
    required String input,
    required AiFinancialContext context,
  }) {
    final lower = input.toLowerCase();

    // 1. Detectar si el usuario quiere registrar una transacción
    final parsedTx = _extractTransactionFromText(input, context);
    if (parsedTx != null) {
      final typeLabel = parsedTx.type == TransactionType.income ? 'Ingreso' : 'Gasto';
      final formattedAmount = Formatters.currency(
        parsedTx.amount,
        context.currency,
      );
      final dateLabel = _formatRelativeDateLabel(parsedTx.date);

      final message = 'Entendido. He preparado el registro de tu $typeLabel:\n'
          '• **Concepto:** ${parsedTx.title}\n'
          '• **Monto:** $formattedAmount\n'
          '• **Categoría:** ${parsedTx.category}\n'
          '• **Cuenta:** ${parsedTx.accountName}\n'
          '• **Fecha:** $dateLabel\n\n'
          '¿Deseas guardarlo en My Money? Toca el botón de abajo para confirmar.';

      return AiAssistantResponse(
        intent: AiIntentType.addTransaction,
        message: message,
        transaction: parsedTx,
        source: 'local',
        suggestions: [
          'Confirmar registro',
          '¿Cuál es mi saldo total?',
          '¿En qué gasté más este mes?',
        ],
      );
    }

    // 2. Consultas de Saldo / Cuentas
    if (_matchesAny(lower, ['saldo', 'cuanto tengo', 'cuánto tengo', 'mi dinero', 'balance total', 'mis cuentas'])) {
      return _generateBalanceInsight(context);
    }

    // 3. Consultas de Gastos / Egresos
    if (_matchesAny(lower, ['gaste', 'gasté', 'en que gaste', 'en qué gasté', 'cuanto he gastado', 'resumen de gastos', 'mis gastos'])) {
      return _generateExpenseInsight(context);
    }

    // 4. Consultas de Presupuestos
    if (_matchesAny(lower, ['presupuesto', 'presupuestos', 'me he pasado', 'como voy'])) {
      return _generateBudgetInsight(context);
    }

    // 5. Consultas de Deudas
    if (_matchesAny(lower, ['deuda', 'deudas', 'cuanto debo', 'cuánto debo', 'me deben', 'prestamo'])) {
      return _generateDebtInsight(context);
    }

    // 6. Consejos de Ahorro / Finanzas
    if (_matchesAny(lower, ['consejo', 'ahorrar', 'tips', 'recomiendas', 'recomendacion', 'ayuda para ahorrar'])) {
      return _generateSavingsAdvice(context);
    }

    // 7. Saludos / Ayuda general
    if (_matchesAny(lower, ['hola', 'buenas', 'hey', 'ayuda', 'que puedes hacer', 'qué puedes hacer'])) {
      return const AiAssistantResponse(
        intent: AiIntentType.help,
        message: '¡Hola! Soy tu **Asistente Financiero My Money** 🤖✨\n\n'
            'Puedo ayudarte a:\n'
            '1. **Registrar movimientos al instante:**\n'
            '   *"Ayer gasté 35 mil en pizza con Nequi"*\n'
            '   *"Pagué 12.000 de taxi en efectivo"*\n'
            '   *"Me pagaron 1.500.000 de sueldo hoy"*\n\n'
            '2. **Analizar tus finanzas:**\n'
            '   *"¿Cuál es mi saldo total?"*\n'
            '   *"¿En qué gasté más este mes?"*\n'
            '   *"¿Cómo van mis presupuestos?"*\n'
            '   *"Consejos para ahorrar dinero"*\n\n'
            '¿Qué deseas hacer hoy?',
        source: 'local',
        suggestions: [
          'Ayer gasté 35 mil en comida con Nequi',
          '¿Cuál es mi saldo total?',
          '¿En qué gasté más este mes?',
          '¿Cómo van mis presupuestos?',
        ],
      );
    }

    // Respuesta por defecto con orientación
    return AiAssistantResponse(
      intent: AiIntentType.general,
      message: 'No logré identificar un movimiento exacto o consulta en: *"$input"*.\n\n'
          '💡 **Ejemplos de lo que puedes decirme:**\n'
          '• *"Gasté 45 mil en gasolina con Bancolombia"*\n'
          '• *"Pagué 15.000 de almuerzo en efectivo hoy"*\n'
          '• *"¿Cuánto tengo disponible en mis cuentas?"*\n'
          '• *"¿Cómo van mis presupuestos este mes?"*',
      source: 'local',
      suggestions: [
        'Ayer gasté 35 mil en almuerzo con Nequi',
        '¿Cuál es mi saldo total?',
        'Consejos para ahorrar dinero',
      ],
    );
  }

  // ---------------------------------------------------------
  // EXTRACTOR LOCAL DE TRANSACCIONES
  // ---------------------------------------------------------

  static ParsedAiTransaction? _extractTransactionFromText(
    String input,
    AiFinancialContext context,
  ) {
    final lower = input.toLowerCase();

    // 1. Extraer Monto
    final amount = _extractAmount(lower);
    if (amount == null || amount <= 0) {
      return null;
    }

    // 2. Extraer Tipo (Gasto vs Ingreso)
    final type = _detectTransactionType(lower);

    // 3. Extraer Categoría
    final category = _detectCategory(lower, type);

    // 4. Extraer Cuenta
    final matchedAccount = _detectAccount(lower, context.accounts);
    final accountId = matchedAccount?.id ?? (context.accounts.isNotEmpty ? context.accounts.first.id : 'default-cash');
    final accountName = matchedAccount?.name ?? (context.accounts.isNotEmpty ? context.accounts.first.name : 'Efectivo');

    // 5. Extraer Fecha relativa
    final date = _detectDate(lower);

    // 6. Extraer Título limpio
    final title = _generateTitle(input, lower, category);

    return ParsedAiTransaction(
      title: title,
      amount: amount,
      type: type,
      category: category,
      accountId: accountId,
      accountName: accountName,
      date: date,
      note: 'Registrado con Asistente IA',
      rawText: input,
    );
  }

  /// Extrae montos como "35 mil", "1.5 millones", "12k", "$35.000", "50000"
  static double? _extractAmount(String text) {
    // 1. Caso: "X millones" o "X millón" (ej: 1.5 millones, 2 millones)
    final millionRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:millones|millón|millon|m\b)', caseSensitive: false);
    final millionMatch = millionRegex.firstMatch(text);
    if (millionMatch != null) {
      final valStr = millionMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(valStr);
      if (val != null) {
        return val * 1000000.0;
      }
    }

    // 2. Caso: "X mil" o "X k" (ej: 35 mil, 50k, 12 k)
    final milRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:mil|k\b)', caseSensitive: false);
    final milMatch = milRegex.firstMatch(text);
    if (milMatch != null) {
      final valStr = milMatch.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(valStr);
      if (val != null) {
        return val * 1000.0;
      }
    }

    // 3. Caso: Formatos con separadores de miles estándar (ej: $35.000, 35,000, 150.000)
    final standardRegex = RegExp(r'(?:\$|\b)(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{2})?)\b');
    final standardMatch = standardRegex.firstMatch(text);
    if (standardMatch != null) {
      String raw = standardMatch.group(1)!;
      // Si tiene punto como separador de miles: 35.000
      if (raw.contains('.') && !raw.contains(',')) {
        raw = raw.replaceAll('.', '');
      } else if (raw.contains(',') && !raw.contains('.')) {
        raw = raw.replaceAll(',', '');
      } else if (raw.contains('.') && raw.contains(',')) {
        // ej: 1.500,00 -> miles con punto, centavos con coma
        raw = raw.replaceAll('.', '').replaceAll(',', '.');
      }
      final val = double.tryParse(raw);
      if (val != null && val > 0) return val;
    }

    // 4. Caso: Números planos solos (ej: $ 35000, 12000)
    final plainRegex = RegExp(r'(?:\$|\b)(\d{3,9})\b');
    final plainMatch = plainRegex.firstMatch(text);
    if (plainMatch != null) {
      final val = double.tryParse(plainMatch.group(1)!);
      if (val != null && val > 0) return val;
    }

    return null;
  }

  static TransactionType _detectTransactionType(String lower) {
    const incomeVerbs = [
      'gané', 'gane', 'me pagaron', 'pagaron', 'recibí', 'recibi',
      'consignaron', 'salario', 'sueldo', 'ingreso', 'cobré', 'cobre',
      'vendí', 'vendi', 'abono', 'transferencia recibida', 'consignación',
    ];

    for (final verb in incomeVerbs) {
      if (lower.contains(verb)) {
        return TransactionType.income;
      }
    }
    return TransactionType.expense;
  }

  static String _detectCategory(String lower, TransactionType type) {
    if (type == TransactionType.income) {
      if (_containsAny(lower, ['sueldo', 'salario', 'nomina', 'nómina', 'quincena', 'pago mensual'])) {
        return 'Salario';
      }
      if (_containsAny(lower, ['freelance', 'proyecto', 'honorarios', 'cliente', 'trabajo extra'])) {
        return 'Freelance';
      }
      if (_containsAny(lower, ['inversion', 'inversión', 'dividendo', 'cripto', 'intereses', 'rendimientos'])) {
        return 'Inversiones';
      }
      if (_containsAny(lower, ['venta', 'vendí', 'vendi', 'comercio'])) {
        return 'Ventas';
      }
      if (_containsAny(lower, ['regalo', 'obsequio', 'cumpleaños', 'regalaron'])) {
        return 'Regalo';
      }
      return 'Otros';
    }

    // Gastos:
    if (_containsAny(lower, [
      'almuerzo', 'almorcé', 'almorce', 'comida', 'cena', 'cené', 'cene',
      'desayuno', 'desayuné', 'desayune', 'restaurante', 'pizza', 'hamburguesa',
      'café', 'cafe', 'mercado', 'supermercado', 'panadería', 'panaderia',
      'helado', 'postre', 'mercar', 'pollo', 'carne', 'snack', 'empanada',
    ])) {
      return 'Alimentación';
    }

    if (_containsAny(lower, [
      'taxi', 'uber', 'didi', 'indrive', 'gasolina', 'bus', 'pasaje',
      'metro', 'peaje', 'parqueadero', 'estacionamiento', 'transmilenio',
      'moto', 'taller', 'cambio de aceite',
    ])) {
      return 'Transporte';
    }

    if (_containsAny(lower, [
      'luz', 'agua', 'gas', 'internet', 'claro', 'tigo', 'movistar',
      'epm', 'enel', 'recarga', 'factura de servicios', 'electricidad',
    ])) {
      return 'Servicios';
    }

    if (_containsAny(lower, [
      'arriendo', 'alquiler', 'administración', 'administracion',
      'cuota apto', 'cuota de la casa', 'mantenimiento casa',
    ])) {
      return 'Vivienda';
    }

    if (_containsAny(lower, [
      'farmacia', 'droguería', 'drogueria', 'medicina', 'pastillas',
      'médico', 'medico', 'cita', 'odontólogo', 'odontologo', 'eps',
      'remedio', 'laboratorio', 'dentista',
    ])) {
      return 'Salud';
    }

    if (_containsAny(lower, [
      'curso', 'universidad', 'colegio', 'libro', 'matrícula', 'matricula',
      'pensión', 'pension', 'clases', 'capacitación',
    ])) {
      return 'Educación';
    }

    if (_containsAny(lower, [
      'cine', 'fiesta', 'cerveza', 'cervezas', 'bar', 'rumba', 'concierto',
      'juego', 'steam', 'playstation', 'xbox', 'cine colombia', 'bolera',
    ])) {
      return 'Entretenimiento';
    }

    if (_containsAny(lower, [
      'ropa', 'zapatos', 'camisa', 'pantalón', 'pantalon', 'compras',
      'tienda', 'centro comercial', 'amazon', 'mercadolibre', 'falabella',
      'zapatillas', 'reloj',
    ])) {
      return 'Compras';
    }

    if (_containsAny(lower, [
      'netflix', 'spotify', 'youtube', 'disney', 'prime', 'apple',
      'icloud', 'chatgpt', 'hbo', 'max', 'paramount', 'suscripción',
    ])) {
      return 'Suscripciones';
    }

    return 'Otros';
  }

  static AccountModel? _detectAccount(String lower, List<AccountModel> accounts) {
    if (accounts.isEmpty) return null;

    for (final acc in accounts) {
      final nameLower = acc.name.toLowerCase();
      // Verificación directa de nombre
      if (lower.contains(nameLower)) return acc;

      // Verificación de marcas/tipos populares
      if (nameLower.contains('nequi') && lower.contains('nequi')) return acc;
      if (nameLower.contains('bancolombia') && lower.contains('bancolombia')) return acc;
      if (nameLower.contains('daviplata') && (lower.contains('daviplata') || lower.contains('davivienda'))) return acc;
      if (nameLower.contains('nu') && (lower.contains('nu') || lower.contains('nubank'))) return acc;
      if (acc.type == AccountType.cash && (lower.contains('efectivo') || lower.contains('plata en mano'))) return acc;
      if (acc.type == AccountType.creditCard && (lower.contains('tarjeta de credito') || lower.contains('tarjeta de crédito') || lower.contains('tc'))) return acc;
    }

    // Fallback por palabras claves si no coincidió por nombre exacto
    if (lower.contains('nequi')) {
      return accounts.firstWhere((a) => a.name.toLowerCase().contains('nequi'), orElse: () => accounts.first);
    }
    if (lower.contains('bancolombia')) {
      return accounts.firstWhere((a) => a.name.toLowerCase().contains('bancolombia'), orElse: () => accounts.first);
    }
    if (lower.contains('efectivo')) {
      return accounts.firstWhere((a) => a.type == AccountType.cash, orElse: () => accounts.first);
    }

    return accounts.first;
  }

  static DateTime _detectDate(String lower) {
    final now = DateTime.now();
    if (lower.contains('antier') || lower.contains('anteayer')) {
      return now.subtract(const Duration(days: 2));
    }
    if (lower.contains('ayer')) {
      return now.subtract(const Duration(days: 1));
    }

    final daysAgoRegex = RegExp(r'hace\s+(\d+)\s+días?', caseSensitive: false);
    final match = daysAgoRegex.firstMatch(lower);
    if (match != null) {
      final days = int.tryParse(match.group(1)!) ?? 0;
      if (days > 0 && days < 30) {
        return now.subtract(Duration(days: days));
      }
    }

    return now;
  }

  static String _generateTitle(String original, String lower, String category) {
    // Buscar patrones específicos como "en [cosa]" o "de [cosa]"
    final inPattern = RegExp(r'(?:en|de|por)\s+([a-záéíóúñA-ZÁÉÍÓÚÑ0-9\s]{3,25}?)(?:\s+(?:con|por|el|la|en|ayer|hoy|antier|\$|\d)|$)', caseSensitive: false);
    final match = inPattern.firstMatch(original);
    if (match != null) {
      final candidate = match.group(1)!.trim();
      final candLower = candidate.toLowerCase();
      // Evitar que el título sea una cuenta o palabra irrelevante
      if (!candLower.contains('nequi') &&
          !candLower.contains('bancolombia') &&
          !candLower.contains('efectivo') &&
          !candLower.contains('ayer') &&
          !candLower.contains('hoy') &&
          candLower.length >= 3) {
        return _capitalize(candidate);
      }
    }

    // Si hay un concepto clave presente, usarlo
    final keywords = [
      'almuerzo', 'desayuno', 'cena', 'pizza', 'hamburguesa', 'taxi', 'uber',
      'gasolina', 'mercado', 'supermercado', 'cine', 'farmacia', 'medicina',
      'café', 'cafe', 'ropa', 'arriendo', 'servicios', 'luz', 'agua', 'internet',
      'sueldo', 'salario', 'freelance',
    ];
    for (final kw in keywords) {
      if (lower.contains(kw)) {
        return _capitalize(kw);
      }
    }

    return category;
  }

  // ---------------------------------------------------------
  // GENERADORES DE INSIGHTS FINANCIEROS (LOCAL)
  // ---------------------------------------------------------

  static AiAssistantResponse _generateBalanceInsight(AiFinancialContext context) {
    final formattedBalance = Formatters.currency(
      context.totalBalance,
      context.currency,
    );

    final sb = StringBuffer();
    sb.writeln('💰 **Tu Balance Total es:** $formattedBalance\n');

    if (context.accounts.isNotEmpty) {
      sb.writeln('🏦 **Desglose de tus cuentas principales:**');
      for (final acc in context.accounts.take(4)) {
        final accBalance = Formatters.currency(
          acc.currentBalance,
          context.currency,
        );
        sb.writeln('• **${acc.name}:** $accBalance');
      }
    }

    final totalDebt = context.debts
        .where((d) => !d.isPaid && d.type == DebtType.iOwe)
        .fold(0.0, (sum, d) => sum + d.remainingAmount);

    if (totalDebt > 0) {
      final formattedDebt = Formatters.currency(
        totalDebt,
        context.currency,
      );
      final netBalance = Formatters.currency(
        context.totalBalance - totalDebt,
        context.currency,
      );
      sb.writeln('\n⚠️ **Deudas por pagar:** $formattedDebt');
      sb.writeln('💎 **Patrimonio Neto real:** $netBalance');
    }

    return AiAssistantResponse(
      intent: AiIntentType.queryBalance,
      message: sb.toString().trim(),
      source: 'local',
      suggestions: [
        '¿En qué gasté más este mes?',
        '¿Cómo van mis presupuestos?',
        'Registrar un nuevo gasto',
      ],
    );
  }

  static AiAssistantResponse _generateExpenseInsight(AiFinancialContext context) {
    final now = DateTime.now();
    final monthTransactions = context.recentTransactions.where((t) {
      return t.type == TransactionType.expense &&
          t.date.year == now.year &&
          t.date.month == now.month;
    }).toList();

    final totalExpense = monthTransactions.fold(0.0, (s, t) => s + t.amount);
    final formattedTotal = Formatters.currency(
      totalExpense > 0 ? totalExpense : context.monthExpense,
      context.currency,
    );

    if (monthTransactions.isEmpty && context.monthExpense <= 0) {
      return AiAssistantResponse(
        intent: AiIntentType.queryExpenses,
        message: 'Aún no registras gastos durante este mes (${DateFormat.MMMM('es').format(now)}). '
            '¡Excelente oportunidad para comenzar a presupuestar!',
        source: 'local',
        suggestions: [
          'Ayer gasté 25 mil en almuerzo',
          '¿Cuál es mi saldo total?',
        ],
      );
    }

    // Agrupar por categoría
    final categoryTotals = <String, double>{};
    for (final tx in monthTransactions) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0.0) + tx.amount;
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sb = StringBuffer();
    sb.writeln('📊 **Gastos del mes (${DateFormat.MMMM('es').format(now)}):** $formattedTotal\n');

    if (sorted.isNotEmpty) {
      sb.writeln('🔥 **Tus principales categorías de consumo:**');
      for (final entry in sorted.take(4)) {
        final pct = totalExpense > 0 ? ((entry.value / totalExpense) * 100).toStringAsFixed(1) : '0';
        final val = Formatters.currency(
          entry.value,
          context.currency,
        );
        sb.writeln('• **${entry.key}:** $val ($pct%)');
      }

      final topCategory = sorted.first;
      sb.writeln('\n💡 Tu mayor gasto está concentrado en **${topCategory.key}**.');
    }

    return AiAssistantResponse(
      intent: AiIntentType.queryExpenses,
      message: sb.toString().trim(),
      source: 'local',
      suggestions: [
        '¿Cómo van mis presupuestos?',
        '¿Cuál es mi saldo total?',
        'Consejos para ahorrar dinero',
      ],
    );
  }

  static AiAssistantResponse _generateBudgetInsight(AiFinancialContext context) {
    if (context.budgets.isEmpty) {
      return const AiAssistantResponse(
        intent: AiIntentType.queryBudgets,
        message: 'No tienes presupuestos activos configurados en este momento.\n\n'
            'Configurar límites por categoría te ayudará a mantener bajo control tus finanzas.',
        source: 'local',
        suggestions: [
          '¿Cuál es mi saldo total?',
          '¿En qué gasté más este mes?',
        ],
      );
    }

    final now = DateTime.now();
    final activeBudgets = context.budgets.where((b) {
      return b.month == now.month && b.year == now.year;
    }).toList();

    final budgetsToList = activeBudgets.isNotEmpty ? activeBudgets : context.budgets;
    final sb = StringBuffer();
    sb.writeln('🎯 **Estado de tus Presupuestos:**\n');

    int exceededCount = 0;
    int warningCount = 0;

    for (final budget in budgetsToList) {
      // Calcular gasto en esta categoría este mes
      final spent = context.recentTransactions
          .where((t) =>
              t.type == TransactionType.expense &&
              t.category == budget.category &&
              t.date.month == now.month &&
              t.date.year == now.year)
          .fold(0.0, (s, t) => s + t.amount);

      final pct = budget.amount > 0 ? (spent / budget.amount) * 100 : 0.0;
      final limitStr = Formatters.currency(budget.amount, context.currency);
      final spentStr = Formatters.currency(spent, context.currency);

      if (spent > budget.amount) {
        exceededCount++;
        sb.writeln('🚨 **${budget.category}:** $spentStr / $limitStr (${pct.toStringAsFixed(0)}% - ¡Excedido!)');
      } else if (pct >= 80) {
        warningCount++;
        sb.writeln('⚠️ **${budget.category}:** $spentStr / $limitStr (${pct.toStringAsFixed(0)}% - ¡En alerta!)');
      } else {
        sb.writeln('✅ **${budget.category}:** $spentStr / $limitStr (${pct.toStringAsFixed(0)}%)');
      }
    }

    if (exceededCount > 0) {
      sb.writeln('\nTe has pasado en $exceededCount presupuesto(s). Te recomiendo recortar gastos no esenciales allí.');
    } else if (warningCount > 0) {
      sb.writeln('\nTienes $warningCount presupuesto(s) cerca del límite. ¡Mantén el control en estos días!');
    } else {
      sb.writeln('\n👏 ¡Excelente disciplina! Todos tus presupuestos están dentro de la meta.');
    }

    return AiAssistantResponse(
      intent: AiIntentType.queryBudgets,
      message: sb.toString().trim(),
      source: 'local',
      suggestions: [
        'Consejos para ahorrar dinero',
        '¿Cuál es mi saldo total?',
      ],
    );
  }

  static AiAssistantResponse _generateDebtInsight(AiFinancialContext context) {
    if (context.debts.isEmpty) {
      return const AiAssistantResponse(
        intent: AiIntentType.queryDebts,
        message: '🎉 ¡Enhorabuena! No tienes deudas ni préstamos pendientes registrados en My Money.',
        source: 'local',
        suggestions: [
          '¿Cuál es mi saldo total?',
          '¿En qué gasté más este mes?',
        ],
      );
    }

    final oweList = context.debts.where((d) => !d.isPaid && d.type == DebtType.iOwe).toList();
    final owedToMeList = context.debts.where((d) => !d.isPaid && d.type == DebtType.theyOweMe).toList();

    final totalOwe = oweList.fold(0.0, (s, d) => s + d.remainingAmount);
    final totalOwedToMe = owedToMeList.fold(0.0, (s, d) => s + d.remainingAmount);

    final sb = StringBuffer();
    sb.writeln('📑 **Resumen de Deudas y Cobros:**\n');

    final oweStr = Formatters.currency(totalOwe, context.currency);
    final owedToMeStr = Formatters.currency(totalOwedToMe, context.currency);

    sb.writeln('🔴 **Por Pagar (Debes):** $oweStr (${oweList.length} pendientes)');
    for (final d in oweList.take(3)) {
      final rem = Formatters.currency(d.remainingAmount, context.currency);
      sb.writeln('• ${d.personName}: $rem');
    }

    sb.writeln('\n🟢 **Por Cobrar (Te deben):** $owedToMeStr (${owedToMeList.length} pendientes)');
    for (final d in owedToMeList.take(3)) {
      final rem = Formatters.currency(d.remainingAmount, context.currency);
      sb.writeln('• ${d.personName}: $rem');
    }

    return AiAssistantResponse(
      intent: AiIntentType.queryDebts,
      message: sb.toString().trim(),
      source: 'local',
      suggestions: [
        '¿Cuál es mi saldo total?',
        'Consejos para ahorrar dinero',
      ],
    );
  }

  static AiAssistantResponse _generateSavingsAdvice(AiFinancialContext context) {
    final sb = StringBuffer();
    sb.writeln('💡 **Consejos Personalizados para Ahorrar en My Money:**\n');

    // Analizar comportamiento
    if (context.monthExpense > context.monthIncome && context.monthIncome > 0) {
      sb.writeln('⚠️ **Alerta:** En este período tus gastos superan tus ingresos. '
          'Prioriza eliminar gastos "hormiga" (cafés diarios, compras impulsivas) esta semana.');
    } else {
      sb.writeln('1. **Aplica la Regla 50-30-20:** Destina el 50% a necesidades básicas, '
          '30% a gustos o estilo de vida, y un 20% directo a tu ahorro o inversión.');
    }

    sb.writeln('2. **Revisa suscripciones inactivas:** Si no usas plataformas de streaming o apps '
        'al menos dos veces por semana, pausarlas te liberará flujo de caja inmediato.');

    sb.writeln('3. **Registra tus movimientos tan pronto ocurren:** Dictarle o escribirle al Asistente '
        'apenas gastas te da conciencia inmediata del dinero disponible.');

    return AiAssistantResponse(
      intent: AiIntentType.advice,
      message: sb.toString().trim(),
      source: 'local',
      suggestions: [
        '¿En qué gasté más este mes?',
        '¿Cómo van mis presupuestos?',
        '¿Cuál es mi saldo total?',
      ],
    );
  }

  // ---------------------------------------------------------
  // INTEGRACIÓN GEMINI AI REST API (gemini-3.5-flash-lite)
  // ---------------------------------------------------------

  static Future<AiAssistantResponse?> _queryGemini({
    required String input,
    required AiFinancialContext context,
    required String apiKey,
    http.Client? client,
  }) async {
    final clientToUse = client ?? http.Client();
    final shouldCloseClient = client == null;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent?key=$apiKey',
      );

      final accountsSummary = context.accounts.map((a) => '${a.name} (${a.type.name}): ${a.currentBalance}').join(', ');
      final currency = context.currency.code;

      final systemPrompt = '''
Eres "My Money AI", un asistente financiero empático, ágil, altamente inteligente y conciso integrado en la app My Money.
Tu misión es asistir al usuario en registrar transacciones o responder consultas sobre sus finanzas.

DATOS FINANCIEROS DEL USUARIO:
- Moneda: $currency (símbolo: ${context.currency.symbol})
- Saldo total disponible: ${context.totalBalance}
- Ingresos este mes: ${context.monthIncome}
- Gastos este mes: ${context.monthExpense}
- Cuentas registradas: $accountsSummary

INSTRUCCIONES CLAVE:
1. Si el usuario describe un gasto o ingreso que desea registrar (ej: "Ayer me gasté 35 mil en pizza con Nequi", "Pagué 12k de taxi en efectivo", "Me pagaron 1.500.000 de sueldo"):
   Debes extraer los datos exactos y responder OBLIGATORIAMENTE con un bloque JSON al final en el formato:
   ```json
   {
     "is_transaction": true,
     "title": "Concepto breve",
     "amount": 35000.0,
     "type": "expense" o "income",
     "category": "Alimentación" o categoría adecuada,
     "account": "Nombre o ID de cuenta más cercana",
     "date": "YYYY-MM-DD"
   }
   ```
   Acompaña el JSON de un mensaje amigable y conciso resumiendo el registro.

2. Si el usuario hace una pregunta sobre su saldo, presupuestos, gastos o consejos:
   Responde de forma concisa, útil y motivadora en español sin incluir el bloque json de transacción.

Sé breve, no des respuestas interminables.
''';

      final requestBody = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': systemPrompt},
              {'text': 'Usuario: $input'},
            ],
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'maxOutputTokens': 800,
        },
      });

      final response = await clientToUse
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('Gemini API Error (${response.statusCode}): ${response.body}');
        return null;
      }

      final jsonResp = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = jsonResp['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      final text = parts[0]['text'] as String? ?? '';
      return _parseGeminiTextResponse(text, context, input);
    } catch (e) {
      debugPrint('Gemini request failed: $e');
      return null;
    } finally {
      if (shouldCloseClient) {
        clientToUse.close();
      }
    }
  }

  static AiAssistantResponse _parseGeminiTextResponse(
    String text,
    AiFinancialContext context,
    String originalInput,
  ) {
    // Buscar si Gemini devolvió un bloque JSON de transacción
    final jsonRegex = RegExp(r'```json\s*(\{.*?\})\s*```', dotAll: true);
    final match = jsonRegex.firstMatch(text);

    if (match != null) {
      try {
        final jsonStr = match.group(1)!;
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        if (map['is_transaction'] == true) {
          final title = map['title'] as String? ?? 'Gasto';
          final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
          final typeStr = map['type'] as String? ?? 'expense';
          final type = typeStr == 'income' ? TransactionType.income : TransactionType.expense;
          final category = map['category'] as String? ?? (type == TransactionType.income ? 'Salario' : 'Alimentación');
          final accountRaw = map['account'] as String? ?? '';
          final matchedAcc = _detectAccount(accountRaw, context.accounts);
          final accountId = matchedAcc?.id ?? (context.accounts.isNotEmpty ? context.accounts.first.id : 'default-cash');
          final accountName = matchedAcc?.name ?? 'Efectivo';

          DateTime date = DateTime.now();
          if (map['date'] != null) {
            try {
              date = DateTime.parse(map['date'] as String);
            } catch (_) {}
          }

          final cleanMessage = text.replaceAll(match.group(0)!, '').trim();

          final parsedTx = ParsedAiTransaction(
            title: title,
            amount: amount,
            type: type,
            category: category,
            accountId: accountId,
            accountName: accountName,
            date: date,
            rawText: originalInput,
          );

          return AiAssistantResponse(
            intent: AiIntentType.addTransaction,
            message: cleanMessage.isNotEmpty ? cleanMessage : 'He detectado tu movimiento:',
            transaction: parsedTx,
            source: 'gemini',
            suggestions: [
              'Confirmar registro',
              '¿Cuál es mi saldo total?',
            ],
          );
        }
      } catch (e) {
        debugPrint('Error parsing Gemini JSON block: $e');
      }
    }

    return AiAssistantResponse(
      intent: AiIntentType.general,
      message: text.trim(),
      source: 'gemini',
      suggestions: [
        '¿Cuál es mi saldo total?',
        '¿En qué gasté más este mes?',
        'Consejos para ahorrar dinero',
      ],
    );
  }

  // ---------------------------------------------------------
  // UTILITARIOS PRIVADOS
  // ---------------------------------------------------------

  static bool _matchesAny(String text, List<String> triggers) {
    for (final trigger in triggers) {
      if (text.contains(trigger)) return true;
    }
    return false;
  }

  static bool _containsAny(String text, List<String> words) {
    for (final w in words) {
      if (w.length <= 4) {
        final pattern = RegExp(r'(?:^|[\s,.\-!¡?¿$])' + RegExp.escape(w) + r'(?:$|[\s,.\-!¡?¿$])');
        if (pattern.hasMatch(text)) return true;
      } else {
        if (text.contains(w)) return true;
      }
    }
    return false;
  }

  static String _formatRelativeDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hoy (${DateFormat('d MMM', 'es').format(date)})';
    if (diff == 1) return 'Ayer (${DateFormat('d MMM', 'es').format(date)})';
    if (diff == 2) return 'Antier (${DateFormat('d MMM', 'es').format(date)})';
    return DateFormat('EEE d MMMM', 'es').format(date);
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
