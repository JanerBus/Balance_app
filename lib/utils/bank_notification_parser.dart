import '../models/bank_profile_model.dart';
import '../models/parsed_bank_transaction.dart';
import '../models/transaction_model.dart';
import '../models/user_learned_rule.dart';

/// Motor inteligente de extracción y procesamiento de notificaciones bancarias
class BankNotificationParser {
  /// Intenta parsear una notificación y transformarla en una transacción financiera estructurada.
  /// Retorna `null` si la notificación no corresponde a un movimiento monetario relevante.
  static ParsedBankTransaction? parse({
    required String packageName,
    required String title,
    required String text,
    int? timestampMs,
    List<UserLearnedRule>? userRules,
  }) {
    // Normalizar espacios especiales (non-breaking spaces comunes en notificaciones Android)
    final fullText = '$title $text'
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\uFEFF', ' ')
        .trim();
    if (fullText.isEmpty) return null;

    // 0. EVALUACIÓN PRIORITARIA DE REGLAS APRENDIDAS POR EL USUARIO:
    // Si el usuario entrenó una regla personalizada para este banco o patrón, tiene máxima precedencia.
    if (userRules != null && userRules.isNotEmpty) {
      for (final rule in userRules) {
        if (rule.matches(textToEvaluate: fullText, incomingPackage: packageName)) {
          final learnedTx = rule.processNotification(
            title: title,
            text: text,
            incomingPackage: packageName,
            timestampMs: timestampMs,
          );
          if (learnedTx != null) {
            return learnedTx;
          }
        }
      }
    }

    final date = timestampMs != null
        ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
        : DateTime.now();

    // 1. Identificar si coincide con un banco soportado (por paquete o por texto de notificación)
    final matchedBank = BankProfileModel.findByPackage(packageName) ??
        BankProfileModel.findByText(fullText);

    // 2. FILTRADO DE SEGURIDAD FINANCIERA ESTRICTO:
    // La notificación DEBE provenir de una aplicación bancaria oficial o de un SMS bancario legítimo.
    // Descarta de inmediato notificaciones de apps no bancarias (Moodle, WhatsApp, Gmail, Teams, etc.).
    if (!isFinancialContext(packageName: packageName, fullText: fullText, matchedBank: matchedBank)) {
      return null;
    }

    // 3. Extraer el monto de dinero
    final amount = parseAmount(fullText);
    if (amount == null || amount <= 0) return null;

    // 4. Procesar según el perfil del banco o motor heurístico
    final bankId = matchedBank?.id ?? 'generic';
    final bankName = matchedBank?.name ?? _guessBankName(packageName, fullText);

    TransactionType type = TransactionType.expense;
    String merchantOrPayee = '';

    if (bankId == 'nu') {
      final nuResult = _parseNu(fullText, title, text);
      type = nuResult.type;
      merchantOrPayee = nuResult.merchantOrPayee;
    } else if (bankId == 'nequi') {
      final nequiResult = _parseNequi(fullText, title, text);
      type = nequiResult.type;
      merchantOrPayee = nequiResult.merchantOrPayee;
    } else if (bankId == 'bancolombia') {
      final bcolResult = _parseBancolombia(fullText, title, text);
      type = bcolResult.type;
      merchantOrPayee = bcolResult.merchantOrPayee;
    } else if (bankId == 'daviplata') {
      final daviResult = _parseDaviplata(fullText, title, text);
      type = daviResult.type;
      merchantOrPayee = daviResult.merchantOrPayee;
    } else {
      // Fallback Heurístico Universal
      final genericResult = _parseGeneric(fullText, title, text, bankName);
      type = genericResult.type;
      merchantOrPayee = genericResult.merchantOrPayee;
    }

    if (merchantOrPayee.trim().isEmpty) {
      merchantOrPayee = type == TransactionType.income ? 'Ingreso $bankName' : 'Compra con $bankName';
    }

    final category = suggestCategory(merchantOrPayee, fullText, type);

    final id = 'notif-${date.millisecondsSinceEpoch}-${amount.toInt()}';

    return ParsedBankTransaction(
      id: id,
      bankId: bankId,
      bankName: bankName,
      packageName: packageName,
      amount: amount,
      type: type,
      merchantOrPayee: cleanMerchantName(merchantOrPayee),
      category: category,
      timestamp: date,
      rawTitle: title,
      rawText: text,
    );
  }

  // --- PARSERS ESPECÍFICOS POR BANCO ---

  static _ParsePartial _parseNu(String fullText, String title, String text) {
    final lower = fullText.toLowerCase();

    // Ingresos Nu
    if (lower.contains('recibiste') ||
        lower.contains('te transfirieron') ||
        lower.contains('te enviaron') ||
        lower.contains('te llegó dinero') ||
        lower.contains('te llego dinero') ||
        lower.contains('te llegó') ||
        lower.contains('te llego') ||
        lower.contains('tu llave') ||
        lower.contains('cajita creció') ||
        lower.contains('cajita crecio') ||
        lower.contains('rendimientos')) {
      final deMatch = RegExp(r'(?:de|desde)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
      final payee = deMatch?.group(1)?.trim() ??
          (lower.contains('cajita') ? 'Rendimientos Cajita Nu' : 'Transferencia Nu');
      return _ParsePartial(TransactionType.income, payee);
    }

    // Compras aprobadas Nu:
    // "Compra aprobada en Éxito por $45.000"
    // "Compra aprobada en Éxito de $45.000"
    final enPorMatch = RegExp(r'(?:compra|pago)(?:\s+aprobada|\s+exitoso)?\s+en\s+([^.,\n]+?)\s+(?:por|de)', caseSensitive: false).firstMatch(fullText);
    if (enPorMatch != null) {
      return _ParsePartial(TransactionType.expense, enPorMatch.group(1)!.trim());
    }

    // "Compra por $45.000 en Éxito" o "Compraste $45.000 en Éxito"
    final porEnMatch = RegExp(r'(?:compra|pago|compraste|pagaste)\s+(?:por|de)?\s*[\$0-9\.\,\s]+\s+en\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
    if (porEnMatch != null) {
      return _ParsePartial(TransactionType.expense, porEnMatch.group(1)!.trim());
    }

    // "Compra en Éxito por $45.000"
    final enMatch = RegExp(r'(?:compra|pago)\s+en\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
    if (enMatch != null) {
      return _ParsePartial(TransactionType.expense, enMatch.group(1)!.trim());
    }

    // Transferencias salientes
    final aMatch = RegExp(r'(?:transferiste|enviaste|pagaste)\s+(?:[\$0-9\.\,\s]+\s+)?(?:a|en)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
    if (aMatch != null) {
      return _ParsePartial(TransactionType.expense, aMatch.group(1)!.trim());
    }

    return _ParsePartial(TransactionType.expense, 'Tarjeta Nu');
  }

  static _ParsePartial _parseNequi(String fullText, String title, String text) {
    final lower = fullText.toLowerCase();

    // Ingresos
    if (lower.contains('te enviaron') || lower.contains('te consignaron') || lower.contains('recibiste')) {
      final deMatch = RegExp(r'(?:desde|de)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
      final payee = deMatch?.group(1)?.trim() ?? 'Transferencia Nequi';
      return _ParsePartial(TransactionType.income, payee);
    }

    // Pagos o envíos
    final aMatch = RegExp(r'(?:enviaste|pagaste)\s+(?:plata\s+)?(?:[\$0-9\.\,]+\s+)?(?:a|en)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
    if (aMatch != null) {
      return _ParsePartial(TransactionType.expense, aMatch.group(1)!.trim());
    }

    if (lower.contains('sacaste')) {
      return _ParsePartial(TransactionType.expense, 'Retiro en cajero Nequi');
    }

    return _ParsePartial(TransactionType.expense, 'Pago Nequi');
  }

  static _ParsePartial _parseBancolombia(String fullText, String title, String text) {
    final lower = fullText.toLowerCase();

    if (lower.contains('transferencia recibida') || lower.contains('consignacion') || lower.contains('abono')) {
      final deMatch = RegExp(r'(?:de|desde)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
      final payee = deMatch?.group(1)?.trim() ?? 'Transferencia Bancolombia';
      return _ParsePartial(TransactionType.income, payee);
    }

    final enMatch = RegExp(r'(?:compra|pago)\s+por\s+[\$0-9\.\,]+\s+(?:en|a)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
    if (enMatch != null) {
      return _ParsePartial(TransactionType.expense, enMatch.group(1)!.trim());
    }

    return _ParsePartial(TransactionType.expense, 'Bancolombia');
  }

  static _ParsePartial _parseDaviplata(String fullText, String title, String text) {
    final lower = fullText.toLowerCase();

    if (lower.contains('le pasaron') || lower.contains('recibio') || lower.contains('recibió')) {
      final deMatch = RegExp(r'(?:de|desde)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
      final payee = deMatch?.group(1)?.trim() ?? 'Transferencia Daviplata';
      return _ParsePartial(TransactionType.income, payee);
    }

    final aMatch = RegExp(r'(?:paso plata|compra)\s+(?:por\s+[\$0-9\.\,]+\s+)?(?:a|en)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
    if (aMatch != null) {
      return _ParsePartial(TransactionType.expense, aMatch.group(1)!.trim());
    }

    return _ParsePartial(TransactionType.expense, 'Daviplata');
  }

  static _ParsePartial _parseGeneric(String fullText, String title, String text, String bankName) {
    final lower = fullText.toLowerCase();

    final isIncome = lower.contains('recibiste') ||
        lower.contains('te enviaron') ||
        lower.contains('te consignaron') ||
        lower.contains('consignacion') ||
        lower.contains('abono') ||
        lower.contains('le pasaron') ||
        lower.contains('deposito') ||
        lower.contains('rendimiento') ||
        lower.contains('reembolso');

    if (isIncome) {
      final deMatch = RegExp(r'(?:de|desde)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
      return _ParsePartial(TransactionType.income, deMatch?.group(1)?.trim() ?? 'Ingreso $bankName');
    }

    // Gasto por defecto
    final enMatch = RegExp(r'(?:en|a)\s+([^.,\n]+)', caseSensitive: false).firstMatch(fullText);
    return _ParsePartial(TransactionType.expense, enMatch?.group(1)?.trim() ?? 'Compra $bankName');
  }

  // --- EXTRACCIÓN DE MONTO Y FORMATOS ---

  /// Extrae el valor numérico del monto de dinero desde un texto
  static double? parseAmount(String text) {
    // Normalizar espacios especiales (non-breaking spaces comunes en notificaciones Android)
    final clean = text
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u2007', ' ')
        .replaceAll('\uFEFF', ' ');

    // 1. Con símbolo o código de moneda explícito ($100.000, $ 100,00, COP 50.000, 50.000 COP, 100,00 pesos)
    final currencyPattern = RegExp(
      r'(?:[\$]|COP|USD|MXN|EUR|R\$)\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)'
      r'|'
      r'([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)\s*(?:COP|USD|MXN|EUR|pesos|dolares|dólares)',
      caseSensitive: false,
    );
    final m1 = currencyPattern.firstMatch(clean);
    if (m1 != null) {
      final s = m1.group(1) ?? m1.group(2);
      if (s != null) {
        final val = cleanNumberToDouble(s);
        if (val != null && val > 0) return val;
      }
    }

    // 2. Con verbos bancarios comunes de transacción:
    // "Recibiste 100,00 en tu cuenta", "Te transfirieron 50.000", "Enviaste 20.000", "Transferiste 100,00", etc.
    final verbPattern = RegExp(
      r'(?:recibiste|recibió|recibio|transfirieron|transfirio|transfirió|transferiste|enviaron|enviaste|envió|envio|llegaron|llegó|llego|consignaron|consignaste|pagaste|pagó|pago|compraste|compra|retiraste|retiró|retiro|abono|creció|crecio)\s+(?:de\s+|por\s+|una\s+transferencia\s+de\s+|dinero\s+por\s+|plata\s+por\s+)?[\$]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final m2 = verbPattern.firstMatch(clean);
    if (m2 != null) {
      final s = m2.group(1);
      if (s != null) {
        final val = cleanNumberToDouble(s);
        if (val != null && val > 0) return val;
      }
    }

    // 3. Con etiquetas monetarias explícitas: "valor: 50.000", "monto: 30.000", "total $45.000", "saldo: 100.000", "suma de 20.000"
    final labelPattern = RegExp(
      r'(?:valor(?:\s+de)?|monto(?:\s+de)?|total(?:\s+de)?|suma\s+de|cantidad\s+de|saldo(?:\s+de)?)\s*:?\s*[\$]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final m3 = labelPattern.firstMatch(clean);
    if (m3 != null) {
      final s = m3.group(1);
      if (s != null) {
        final val = cleanNumberToDouble(s);
        if (val != null && val > 0) return val;
      }
    }

    // 4. Con frases preposicionales explícitas de transacción: "compra por 45.000", "pago por 100,00", "abono de 50.000"
    final txPrepPattern = RegExp(
      r'(?:compra\s+por|compra\s+de|pago\s+por|pago\s+de|abono\s+de|transferencia\s+de|transferencia\s+por|retiro\s+de|consignaci[oó]n\s+de|transacci[oó]n\s+por)\s+[\$]?\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final m4 = txPrepPattern.firstMatch(clean);
    if (m4 != null) {
      final s = m4.group(1);
      if (s != null) {
        final val = cleanNumberToDouble(s);
        if (val != null && val > 0) return val;
      }
    }

    // 5. Preposiciones 'por' o 'de' acompañadas de símbolo de moneda o miles (ej: "por $45.000", "de 50.000", "por 100.000")
    final strictPrepPattern = RegExp(
      r'(?:por|de)\s+[\$]\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)'
      r'|'
      r'(?:por|de)\s+([0-9]{1,3}(?:[.,][0-9]{3})+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    final m5 = strictPrepPattern.firstMatch(clean);
    if (m5 != null) {
      final s = m5.group(1) ?? m5.group(2);
      if (s != null) {
        final val = cleanNumberToDouble(s);
        if (val != null && val > 0) return val;
      }
    }

    // 6. Con sufijo de destino: "100,00 en tu cuenta", "50.000 a tu cuenta"
    final accountPattern = RegExp(
      r'([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)\s*(?:en\s+tu\s+cuenta|a\s+tu\s+cuenta|en\s+la\s+cuenta|a\s+la\s+cuenta)',
      caseSensitive: false,
    );
    final m6 = accountPattern.firstMatch(clean);
    if (m6 != null) {
      final s = m6.group(1);
      if (s != null) {
        final val = cleanNumberToDouble(s);
        if (val != null && val > 0) return val;
      }
    }

    return null;
  }

  /// Limpia números en formato latinoamericano ($45.000 o 1.250,50) y anglosajón (1,250.50)
  static double? cleanNumberToDouble(String raw) {
    String s = raw.trim();
    if (s.isEmpty) return null;

    // Si tiene ambos '.' y ','
    if (s.contains('.') && s.contains(',')) {
      final lastDot = s.lastIndexOf('.');
      final lastComma = s.lastIndexOf(',');
      if (lastComma > lastDot) {
        // 1.250,50 -> punto es miles, coma es decimal
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // 1,250.50 -> coma es miles, punto es decimal
        s = s.replaceAll(',', '');
      }
      return double.tryParse(s);
    }

    // Si solo tiene '.'
    if (s.contains('.')) {
      final parts = s.split('.');
      if (parts.length > 2) {
        // Múltiples puntos: 1.500.000 -> miles
        s = s.replaceAll('.', '');
        return double.tryParse(s);
      }
      // Exactamente un punto: 45.000 (3 dígitos -> miles) o 45.50 (2 dígitos -> decimal)
      final afterDot = parts.last;
      if (afterDot.length == 3) {
        s = s.replaceAll('.', '');
      }
      return double.tryParse(s);
    }

    // Si solo tiene ','
    if (s.contains(',')) {
      final parts = s.split(',');
      if (parts.length > 2) {
        s = s.replaceAll(',', '');
        return double.tryParse(s);
      }
      final afterComma = parts.last;
      if (afterComma.length == 3) {
        s = s.replaceAll(',', '');
      } else {
        s = s.replaceAll(',', '.');
      }
      return double.tryParse(s);
    }

    return double.tryParse(s);
  }

  // --- MOTOR DE CATEGORIZACIÓN INTELIGENTE ---

  /// Sugiere automáticamente una categoría según palabras clave
  static String suggestCategory(String merchant, String fullText, TransactionType type) {
    if (type == TransactionType.income) {
      final lower = fullText.toLowerCase();
      if (lower.contains('nomina') || lower.contains('nómina') || lower.contains('sueldo')) {
        return 'Salario';
      }
      if (lower.contains('rendimiento') || lower.contains('interes') || lower.contains('cajita')) {
        return 'Inversiones';
      }
      return 'Otros';
    }

    final query = '$merchant $fullText'.toLowerCase();

    // Alimentación
    if (_matchesAny(query, ['éxito', 'exito', 'jumbo', 'carulla', 'd1', 'tiendas d1', 'ara', 'tiendas ara', 'oxxo', 'walmart', 'supermercado', 'mercado', 'panaderia', 'panadería', 'fruver', 'olimpica', 'olímpica'])) {
      return 'Alimentación';
    }

    // Restaurantes
    if (_matchesAny(query, ['restaurante', 'burger', 'hamburgues', 'pizza', 'mcdonald', 'kfc', 'subway', 'starbucks', 'juan valdez', 'crepes', 'rappi', 'didifood', 'didi food', 'uber eats', 'cafe', 'cafeteria', 'asadero', 'pollo'])) {
      return 'Restaurantes';
    }

    // Transporte
    if (_matchesAny(query, ['uber', 'didi', 'cabify', 'indrive', 'taxi', 'transmilenio', 'metro', 'terpel', 'texaco', 'primax', 'brio', 'gasolina', 'peaje', 'estacionamiento', 'parqueadero'])) {
      return 'Transporte';
    }

    // Suscripciones
    if (_matchesAny(query, ['netflix', 'spotify', 'youtube', 'amazon prime', 'prime video', 'hbo', 'max', 'disney', 'apple', 'icloud', 'playstation', 'xbox', 'steam', 'chatgpt', 'openai'])) {
      return 'Suscripciones';
    }

    // Salud
    if (_matchesAny(query, ['farmacia', 'drogueria', 'droguería', 'cruz verde', 'rebaja', 'pasteur', 'eps', 'sanitas', 'sura', 'colmedica', 'medico', 'médico', 'dental', 'odontolog'])) {
      return 'Salud';
    }

    // Entretenimiento
    if (_matchesAny(query, ['cine', 'cinecolombia', 'cinemark', 'procinal', 'cinepolis', 'boleta', 'teatro', 'concierto', 'parque', 'bolera', 'karaoke', 'bar', 'licor'])) {
      return 'Entretenimiento';
    }

    // Servicios
    if (_matchesAny(query, ['epm', 'enel', 'codensa', 'gas', 'acueducto', 'claro', 'tigo', 'movistar', 'etb', 'wom', 'electricidad', 'agua', 'internet'])) {
      return 'Servicios';
    }

    // Compras / Shopping
    if (_matchesAny(query, ['zara', 'falabella', 'h&m', 'bershka', 'stradivarius', 'koaj', 'tennis', 'arturo calle', 'amazon', 'mercadolibre', 'mercado libre', 'aliexpress', 'shein'])) {
      return 'Compras';
    }

    return 'Otros';
  }

  static bool _matchesAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (kw.length <= 3) {
        // En palabras cortas (ej: "ara", "d1"), exigir coincidencia de palabra completa
        // para no confundir apellidos o palabras comunes como "TOCORA", "para", "aclara"
        final regex = RegExp('\\b${RegExp.escape(kw)}\\b', caseSensitive: false);
        if (regex.hasMatch(text)) return true;
      } else {
        if (text.contains(kw)) return true;
      }
    }
    return false;
  }

  /// Valida rigurosamente si la notificación proviene de un origen bancario o financiero.
  /// Descarta de inmediato notificaciones académicas (Moodle, Canvas), mensajería personal
  /// (WhatsApp, Telegram), correos electrónicos y utilidades generales.
  static bool isFinancialContext({
    required String packageName,
    required String fullText,
    BankProfileModel? matchedBank,
  }) {
    final pkg = packageName.toLowerCase();
    final text = fullText.toLowerCase();

    // 1. Blacklist estricta de aplicaciones no bancarias
    const nonFinancialPackages = [
      'moodle', 'canvas', 'blackboard', 'classroom', 'coursera', 'edx', 'duolingo',
      'whatsapp', 'telegram', 'discord', 'slack', 'teams', 'skype', 'viber', 'messenger',
      'gmail', 'outlook', 'yahoo.mobile.client', 'mail',
      'instagram', 'facebook', 'twitter', 'tiktok', 'snapchat', 'reddit', 'pinterest', 'linkedin',
      'youtube', 'spotify', 'netflix', 'disney', 'hbomax', 'primevideo',
      'android.systemui', 'com.android.vending', 'com.google.android.gms',
    ];

    for (final blacklisted in nonFinancialPackages) {
      if (pkg.contains(blacklisted)) {
        return false;
      }
    }

    // 2. Si el paquete coincide explícitamente con un banco soportado registrado
    if (matchedBank != null && matchedBank.packageNames.any((p) => pkg.contains(p.toLowerCase()))) {
      return true;
    }

    // 3. Si el nombre del paquete contiene términos inequívocos de banca o finanzas
    final isFinancialPackage = pkg.contains('bank') ||
        pkg.contains('banco') ||
        pkg.contains('banca') ||
        pkg.contains('wallet') ||
        pkg.contains('fintech') ||
        pkg.contains('financier') ||
        pkg.contains('fiduciaria') ||
        pkg.contains('cooperativ') ||
        pkg.contains('coop') ||
        pkg.contains('credit') ||
        pkg.contains('ahorro') ||
        pkg.contains('davivienda') ||
        pkg.contains('bancolombia') ||
        pkg.contains('nequi') ||
        pkg.contains('daviplata') ||
        pkg.contains('nubank');

    if (isFinancialPackage) {
      return true;
    }

    // 4. Si proviene de una app de SMS (Mensajes de Google, Samsung Messages, etc.)
    final isSms = pkg.contains('messaging') ||
        pkg.contains('mms') ||
        pkg.contains('sms') ||
        pkg.contains('telephony');

    if (isSms) {
      if (matchedBank != null) return true;
      final hasBankKeyword = text.contains('banco') ||
          text.contains('bancolombia') ||
          text.contains('nequi') ||
          text.contains('davivienda') ||
          text.contains('daviplata') ||
          text.contains('bbva') ||
          text.contains('scotiabank') ||
          text.contains('falabella') ||
          text.contains('lulo') ||
          text.contains('tarjeta') ||
          text.contains('cuenta de ahorros') ||
          text.contains('cuenta corriente') ||
          text.contains('transfiya') ||
          text.contains('cajero');
      return hasBankKeyword;
    }

    // 5. Entidades bancarias no listadas pero con frases explícitas de transacción formal
    final hasStrongBankingPhrases = text.contains('cuenta de ahorros') ||
        text.contains('cuenta corriente') ||
        text.contains('tarjeta de crédito') ||
        text.contains('tarjeta de credito') ||
        text.contains('tarjeta crédito') ||
        text.contains('tarjeta credito') ||
        text.contains('tarjeta de débito') ||
        text.contains('tarjeta de debito') ||
        text.contains('tarjeta débito') ||
        text.contains('tarjeta debito') ||
        text.contains('alerta bancaria') ||
        text.contains('notificación bancaria') ||
        text.contains('notificacion bancaria') ||
        text.contains('notificación de débito') ||
        text.contains('notificacion de debito') ||
        text.contains('notificación de crédito') ||
        text.contains('notificacion de credito') ||
        text.contains('transferencia recibida') ||
        text.contains('retiro en cajero') ||
        text.contains('abono a tu cuenta') ||
        text.contains('consignación en tu cuenta') ||
        text.contains('consignacion en tu cuenta');

    return hasStrongBankingPhrases;
  }

  /// Infiere un nombre institucional seguro para la entidad bancaria sin tomar remitentes personales
  static String _guessBankName(String packageName, String fullText) {
    final lower = fullText.toLowerCase();
    if (lower.contains('bancolombia')) return 'Bancolombia';
    if (lower.contains('davivienda')) return 'Davivienda';
    if (lower.contains('daviplata')) return 'Daviplata';
    if (lower.contains('nequi')) return 'Nequi';
    if (lower.contains('bbva')) return 'BBVA';
    if (lower.contains('scotiabank') || lower.contains('colpatria')) return 'Scotiabank Colpatria';
    if (lower.contains('falabella')) return 'Banco Falabella';
    if (lower.contains('bogota') || lower.contains('bogotá')) return 'Banco de Bogotá';
    if (lower.contains('occidente')) return 'Banco de Occidente';
    if (lower.contains('av villas')) return 'AV Villas';
    if (lower.contains('caja social')) return 'Banco Caja Social';
    if (lower.contains('itau') || lower.contains('itaú')) return 'Itaú';
    if (lower.contains('lulo')) return 'Lulo Bank';
    if (lower.contains('nu') || lower.contains('nubank')) return 'Nu';

    final segments = packageName.split('.');
    for (final seg in segments.reversed) {
      final s = seg.toLowerCase();
      if (s != 'com' && s != 'co' && s != 'android' && s != 'app' && s != 'mobile' && s != 'apps' && s != 'client') {
        return s.substring(0, 1).toUpperCase() + s.substring(1);
      }
    }
    return 'Entidad Financiera';
  }

  static String cleanMerchantName(String name) {
    String cleaned = name
        .replaceAll(RegExp(r'\s+con\s+tu\s+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+con\s+llave.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+por\s+transfiya.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+terminada\s+en\s+.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+por\s+\$.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+en\s+tu\s+cuenta.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+a\s+tu\s+cuenta.*$', caseSensitive: false), '')
        .trim();
    if (cleaned.length > 35) {
      cleaned = cleaned.substring(0, 35).trim();
    }
    return cleaned;
  }
}

class _ParsePartial {
  final TransactionType type;
  final String merchantOrPayee;
  const _ParsePartial(this.type, this.merchantOrPayee);
}
