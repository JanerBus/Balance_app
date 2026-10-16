class BudgetModel {
  final String id;
  final String category;
  final double amount;
  final int? month;
  final int? year;
  final bool notifyAt80;
  final bool notifyAt100;
  final double spent;

  const BudgetModel({
    required this.id,
    required this.category,
    required this.amount,
    this.month,
    this.year,
    this.notifyAt80 = true,
    this.notifyAt100 = true,
    this.spent = 0.0,
  });

  /// Saldo restante disponible dentro del presupuesto
  double get remaining {
    final diff = amount - spent;
    return diff > 0 ? diff : 0.0;
  }

  /// Monto excedido (sobregiro) si superó el límite
  double get overspent {
    final diff = spent - amount;
    return diff > 0 ? diff : 0.0;
  }

  /// Porcentaje consumido (0.0 a 1.0+)
  double get progress {
    if (amount <= 0) return 0.0;
    return spent / amount;
  }

  /// Progreso acotado para barras visuales (0.0 a 1.0)
  double get clampedProgress => progress.clamp(0.0, 1.0);

  /// Si se superó el límite de gasto
  bool get isOverbudget => spent > amount;

  /// Si está en zona de advertencia (80% o más pero sin sobregirar aún)
  bool get isNearLimit => progress >= 0.8 && !isOverbudget;

  /// Promedio diario sugerido para los días restantes del mes
  double dailyAllowance(DateTime forMonth) {
    if (remaining <= 0) return 0.0;

    final now = DateTime.now();
    final isCurrentMonth = now.year == forMonth.year && now.month == forMonth.month;

    int remainingDays;
    if (isCurrentMonth) {
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      remainingDays = (daysInMonth - now.day) + 1;
    } else {
      final daysInMonth = DateTime(forMonth.year, forMonth.month + 1, 0).day;
      remainingDays = daysInMonth;
    }

    if (remainingDays <= 0) remainingDays = 1;
    return remaining / remainingDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': amount,
      'month': month,
      'year': year,
      'notifyAt80': notifyAt80 ? 1 : 0,
      'notifyAt100': notifyAt100 ? 1 : 0,
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map, {double spent = 0.0}) {
    return BudgetModel(
      id: map['id'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      month: map['month'] as int?,
      year: map['year'] as int?,
      notifyAt80: (map['notifyAt80'] as int? ?? 1) == 1,
      notifyAt100: (map['notifyAt100'] as int? ?? 1) == 1,
      spent: spent,
    );
  }

  BudgetModel copyWith({
    String? id,
    String? category,
    double? amount,
    int? month,
    int? year,
    bool? notifyAt80,
    bool? notifyAt100,
    double? spent,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      year: year ?? this.year,
      notifyAt80: notifyAt80 ?? this.notifyAt80,
      notifyAt100: notifyAt100 ?? this.notifyAt100,
      spent: spent ?? this.spent,
    );
  }
}
