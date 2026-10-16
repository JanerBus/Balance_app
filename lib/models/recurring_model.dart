import 'transaction_model.dart';

enum RecurringFrequency { daily, weekly, biweekly, monthly, yearly }

class RecurringModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final String accountId;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextDueDate;
  final bool autoApply;
  final bool isActive;
  final String? note;

  const RecurringModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.accountId,
    required this.frequency,
    required this.startDate,
    required this.nextDueDate,
    this.autoApply = true,
    this.isActive = true,
    this.note,
  });

  String get frequencyLabel {
    switch (frequency) {
      case RecurringFrequency.daily:
        return 'Diario';
      case RecurringFrequency.weekly:
        return 'Semanal';
      case RecurringFrequency.biweekly:
        return 'Quincenal';
      case RecurringFrequency.monthly:
        return 'Mensual';
      case RecurringFrequency.yearly:
        return 'Anual';
    }
  }

  /// Costo normalizado mensual (para proyectar presupuesto mensual de suscripciones)
  double get monthlyNormalizedAmount {
    switch (frequency) {
      case RecurringFrequency.daily:
        return amount * 30;
      case RecurringFrequency.weekly:
        return amount * (52 / 12);
      case RecurringFrequency.biweekly:
        return amount * 2;
      case RecurringFrequency.monthly:
        return amount;
      case RecurringFrequency.yearly:
        return amount / 12;
    }
  }

  /// Días restantes hasta el próximo cobro/pago
  int get daysUntilNextDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.difference(today).inDays;
  }

  /// Si ya se cumplió o venció la fecha programada
  bool get isDueNow {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return due.isBefore(today) || due.isAtSameMomentAs(today);
  }

  /// Calcula la fecha subsiguiente según la frecuencia
  DateTime get calculateNextCycleDate {
    switch (frequency) {
      case RecurringFrequency.daily:
        return nextDueDate.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return nextDueDate.add(const Duration(days: 7));
      case RecurringFrequency.biweekly:
        return nextDueDate.add(const Duration(days: 14));
      case RecurringFrequency.monthly:
        // Manejar correctamente meses con diferente número de días
        var nextYear = nextDueDate.year;
        var nextMonth = nextDueDate.month + 1;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear += 1;
        }
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final targetDay = nextDueDate.day > daysInNextMonth ? daysInNextMonth : nextDueDate.day;
        return DateTime(nextYear, nextMonth, targetDay, nextDueDate.hour, nextDueDate.minute);
      case RecurringFrequency.yearly:
        return DateTime(nextDueDate.year + 1, nextDueDate.month, nextDueDate.day, nextDueDate.hour, nextDueDate.minute);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'accountId': accountId,
      'frequency': frequency.name,
      'startDate': startDate.toIso8601String(),
      'nextDueDate': nextDueDate.toIso8601String(),
      'autoApply': autoApply ? 1 : 0,
      'isActive': isActive ? 1 : 0,
      'note': note,
    };
  }

  factory RecurringModel.fromMap(Map<String, dynamic> map) {
    final freqStr = map['frequency'] as String? ?? 'monthly';
    final freq = RecurringFrequency.values.firstWhere(
      (e) => e.name == freqStr,
      orElse: () => RecurringFrequency.monthly,
    );

    final typeStr = map['type'] as String? ?? 'expense';
    final type = typeStr == 'income' ? TransactionType.income : TransactionType.expense;

    return RecurringModel(
      id: map['id'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: type,
      category: map['category'] as String? ?? 'Suscripciones',
      accountId: map['accountId'] as String? ?? 'default-cash',
      frequency: freq,
      startDate: DateTime.parse(map['startDate'] as String),
      nextDueDate: DateTime.parse(map['nextDueDate'] as String),
      autoApply: (map['autoApply'] as int? ?? 1) == 1,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      note: map['note'] as String?,
    );
  }

  RecurringModel copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    String? accountId,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? nextDueDate,
    bool? autoApply,
    bool? isActive,
    String? note,
  }) {
    return RecurringModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      autoApply: autoApply ?? this.autoApply,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
    );
  }
}
