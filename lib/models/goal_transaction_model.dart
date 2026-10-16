enum GoalTransactionType { deposit, withdraw }

class GoalTransactionModel {
  final String id;
  final String goalId;
  final double amount;
  final GoalTransactionType type;
  final DateTime date;
  final String? note;
  final String? accountId;

  const GoalTransactionModel({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.type,
    required this.date,
    this.note,
    this.accountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'amount': amount,
      'type': type.name,
      'date': date.toIso8601String(),
      'note': note,
      'accountId': accountId,
    };
  }

  factory GoalTransactionModel.fromMap(Map<String, dynamic> map) {
    return GoalTransactionModel(
      id: map['id'] as String,
      goalId: map['goalId'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'withdraw' ? GoalTransactionType.withdraw : GoalTransactionType.deposit,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      accountId: map['accountId'] as String?,
    );
  }
}
