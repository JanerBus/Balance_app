import 'dart:convert';
import 'parsed_bank_transaction.dart';
import 'transaction_model.dart';
import '../utils/bank_notification_parser.dart';

/// Regla personalizada de aprendizaje creada por el usuario o aprendida dinámicamente
/// para reconocer formatos específicos de notificaciones bancarias.
class UserLearnedRule {
  final String id;
  final String name;
  final String? packageName;
  final String bankName;
  final List<String> triggerKeywords;
  final TransactionType type;
  final String? defaultAccountId;
  final String? defaultCategory;
  final String? fixedMerchant;
  final bool isEnabled;
  final DateTime createdAt;
  final String? sampleText;

  const UserLearnedRule({
    required this.id,
    required this.name,
    this.packageName,
    required this.bankName,
    required this.triggerKeywords,
    required this.type,
    this.defaultAccountId,
    this.defaultCategory,
    this.fixedMerchant,
    this.isEnabled = true,
    required this.createdAt,
    this.sampleText,
  });

  /// Evalúa si el texto de una notificación coincide con esta regla de aprendizaje
  bool matches({required String textToEvaluate, required String incomingPackage}) {
    if (!isEnabled) return false;

    // Si la regla especifica un paquete, debe coincidir (ignorando mayúsculas)
    if (packageName != null && packageName!.isNotEmpty) {
      if (incomingPackage.toLowerCase() != packageName!.toLowerCase()) {
        return false;
      }
    }

    final lower = textToEvaluate.toLowerCase();

    // Todas las palabras clave configuradas deben estar presentes en el texto
    for (final keyword in triggerKeywords) {
      final cleanKeyword = keyword.trim().toLowerCase();
      if (cleanKeyword.isNotEmpty && !lower.contains(cleanKeyword)) {
        return false;
      }
    }

    return triggerKeywords.isNotEmpty;
  }

  /// Procesa una notificación que coincidió con la regla y extrae la transacción
  ParsedBankTransaction? processNotification({
    required String title,
    required String text,
    required String incomingPackage,
    int? timestampMs,
  }) {
    final fullText = '$title $text'.trim();
    final amount = BankNotificationParser.parseAmount(fullText);
    if (amount == null || amount <= 0) return null;

    final date = timestampMs != null
        ? DateTime.fromMillisecondsSinceEpoch(timestampMs)
        : DateTime.now();

    // Determinar el comercio o remitente
    String merchant = fixedMerchant ?? '';
    if (merchant.isEmpty) {
      // Intentar extraer con limpiador inteligente de BankNotificationParser
      merchant = BankNotificationParser.cleanMerchantName(title.isNotEmpty ? title : bankName);
      if (merchant.isEmpty) {
        merchant = type == TransactionType.income ? 'Ingreso $bankName' : 'Gasto en $bankName';
      }
    }

    // Determinar la categoría
    final category = defaultCategory ??
        BankNotificationParser.suggestCategory(merchant, fullText, type);

    final txId = 'custom-rule-${id.substring(0, id.length > 8 ? 8 : id.length)}-${date.millisecondsSinceEpoch}';

    return ParsedBankTransaction(
      id: txId,
      bankId: 'custom-$id',
      bankName: bankName,
      packageName: incomingPackage,
      amount: amount,
      type: type,
      merchantOrPayee: merchant,
      category: category,
      timestamp: date,
      rawTitle: title,
      rawText: text,
      accountId: defaultAccountId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'packageName': packageName,
      'bankName': bankName,
      'triggerKeywords': triggerKeywords,
      'type': type.name,
      'defaultAccountId': defaultAccountId,
      'defaultCategory': defaultCategory,
      'fixedMerchant': fixedMerchant,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'sampleText': sampleText,
    };
  }

  factory UserLearnedRule.fromMap(Map<String, dynamic> map) {
    return UserLearnedRule(
      id: map['id'] as String,
      name: map['name'] as String,
      packageName: map['packageName'] as String?,
      bankName: map['bankName'] as String? ?? 'Banco',
      triggerKeywords: (map['triggerKeywords'] is List)
          ? (map['triggerKeywords'] as List).map((e) => e.toString()).toList()
          : (map['triggerKeywords'] as String?)?.split(',').map((e) => e.trim()).toList() ?? [],
      type: TransactionType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      defaultAccountId: map['defaultAccountId'] as String?,
      defaultCategory: map['defaultCategory'] as String?,
      fixedMerchant: map['fixedMerchant'] as String?,
      isEnabled: map['isEnabled'] == 1 || map['isEnabled'] == true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      sampleText: map['sampleText'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory UserLearnedRule.fromJson(String source) =>
      UserLearnedRule.fromMap(jsonDecode(source) as Map<String, dynamic>);

  UserLearnedRule copyWith({
    String? id,
    String? name,
    String? packageName,
    String? bankName,
    List<String>? triggerKeywords,
    TransactionType? type,
    String? defaultAccountId,
    String? defaultCategory,
    String? fixedMerchant,
    bool? isEnabled,
    DateTime? createdAt,
    String? sampleText,
  }) {
    return UserLearnedRule(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      bankName: bankName ?? this.bankName,
      triggerKeywords: triggerKeywords ?? this.triggerKeywords,
      type: type ?? this.type,
      defaultAccountId: defaultAccountId ?? this.defaultAccountId,
      defaultCategory: defaultCategory ?? this.defaultCategory,
      fixedMerchant: fixedMerchant ?? this.fixedMerchant,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      sampleText: sampleText ?? this.sampleText,
    );
  }
}
