import 'transaction_model.dart';

class ParsedBankTransaction {
  final String id;
  final String bankId;
  final String bankName;
  final String packageName;
  final double amount;
  final TransactionType type;
  final String merchantOrPayee;
  final String category;
  final DateTime timestamp;
  final String rawTitle;
  final String rawText;
  final String? accountId;

  const ParsedBankTransaction({
    required this.id,
    required this.bankId,
    required this.bankName,
    required this.packageName,
    required this.amount,
    required this.type,
    required this.merchantOrPayee,
    required this.category,
    required this.timestamp,
    required this.rawTitle,
    required this.rawText,
    this.accountId,
  });

  ParsedBankTransaction copyWith({
    String? id,
    String? bankId,
    String? bankName,
    String? packageName,
    double? amount,
    TransactionType? type,
    String? merchantOrPayee,
    String? category,
    DateTime? timestamp,
    String? rawTitle,
    String? rawText,
    String? accountId,
  }) {
    return ParsedBankTransaction(
      id: id ?? this.id,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      packageName: packageName ?? this.packageName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchantOrPayee: merchantOrPayee ?? this.merchantOrPayee,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      rawTitle: rawTitle ?? this.rawTitle,
      rawText: rawText ?? this.rawText,
      accountId: accountId ?? this.accountId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bankId': bankId,
      'bankName': bankName,
      'packageName': packageName,
      'amount': amount,
      'type': type.name,
      'merchantOrPayee': merchantOrPayee,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'rawTitle': rawTitle,
      'rawText': rawText,
      if (accountId != null) 'accountId': accountId,
    };
  }

  factory ParsedBankTransaction.fromMap(Map<String, dynamic> map) {
    return ParsedBankTransaction(
      id: map['id'] as String,
      bankId: map['bankId'] as String,
      bankName: map['bankName'] as String,
      packageName: map['packageName'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'income'
          ? TransactionType.income
          : (map['type'] == 'transfer' ? TransactionType.transfer : TransactionType.expense),
      merchantOrPayee: map['merchantOrPayee'] as String,
      category: map['category'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      rawTitle: map['rawTitle'] as String? ?? '',
      rawText: map['rawText'] as String? ?? '',
      accountId: map['accountId'] as String?,
    );
  }
}
