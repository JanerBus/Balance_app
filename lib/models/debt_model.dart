import 'debt_payment_model.dart';

enum DebtType { theyOweMe, iOwe }

class DebtModel {
  final String id;
  final String personName;
  final double amount;
  final DebtType type;
  final String? description;
  final DateTime createdDate;
  final DateTime? dueDate;
  final bool isPaid;
  final List<DebtPaymentModel> payments;

  const DebtModel({
    required this.id,
    required this.personName,
    required this.amount,
    required this.type,
    this.description,
    required this.createdDate,
    this.dueDate,
    this.isPaid = false,
    this.payments = const [],
  });

  /// Total abonado a la deuda
  double get totalPaid => payments.fold(0.0, (sum, p) => sum + p.amount);

  /// Saldo pendiente por pagar
  double get remainingAmount {
    if (isPaid) return 0.0;
    final remaining = amount - totalPaid;
    return remaining > 0 ? remaining : 0.0;
  }

  /// Porcentaje pagado (0.0 a 1.0)
  double get progress {
    if (amount <= 0) return 0.0;
    if (isPaid) return 1.0;
    return (totalPaid / amount).clamp(0.0, 1.0);
  }

  /// Si la deuda está completamente liquidada (marcada como pagada o saldo saldado)
  bool get isFullySettled => isPaid || (payments.isNotEmpty && totalPaid >= amount);

  /// Si la deuda está vencida
  bool get isOverdue {
    if (dueDate == null || isFullySettled) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  /// Días restantes hasta la fecha de vencimiento (negativo si está vencida)
  int? get daysUntilDue {
    if (dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.difference(today).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'type': type == DebtType.theyOweMe ? 'theyOweMe' : 'iOwe',
      'description': description,
      'createdDate': createdDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'isPaid': isPaid ? 1 : 0,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map, {List<DebtPaymentModel> payments = const []}) {
    return DebtModel(
      id: map['id'] as String,
      personName: map['personName'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'theyOweMe' ? DebtType.theyOweMe : DebtType.iOwe,
      description: map['description'] as String?,
      createdDate: DateTime.parse(map['createdDate'] as String),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      isPaid: (map['isPaid'] as int) == 1,
      payments: payments,
    );
  }

  DebtModel copyWith({
    String? id,
    String? personName,
    double? amount,
    DebtType? type,
    String? description,
    DateTime? createdDate,
    DateTime? dueDate,
    bool? isPaid,
    List<DebtPaymentModel>? payments,
  }) {
    return DebtModel(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      createdDate: createdDate ?? this.createdDate,
      dueDate: dueDate ?? this.dueDate,
      isPaid: isPaid ?? this.isPaid,
      payments: payments ?? this.payments,
    );
  }
}
