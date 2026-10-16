enum TransactionType { income, expense, transfer }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? note;
  final String accountId;
  final String? toAccountId;

  const TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note,
    this.accountId = 'default-cash',
    this.toAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'accountId': accountId,
      'toAccountId': toAccountId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'expense';
    TransactionType type;
    if (typeStr == 'income') {
      type = TransactionType.income;
    } else if (typeStr == 'transfer') {
      type = TransactionType.transfer;
    } else {
      type = TransactionType.expense;
    }

    return TransactionModel(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: type,
      category: map['category'] as String? ?? 'Otros',
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      accountId: map['accountId'] as String? ?? 'default-cash',
      toAccountId: map['toAccountId'] as String?,
    );
  }

  TransactionModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
    String? accountId,
    String? toAccountId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
    );
  }
}
