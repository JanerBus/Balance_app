import 'package:flutter/material.dart';

enum AccountType { cash, bank, creditCard, savings, investment, other }

class AccountModel {
  final String id;
  final String name;
  final AccountType type;
  final double initialBalance;
  final int color;
  final String icon;
  final bool includeInTotal;
  final double currentBalance;
  final double? creditLimit;
  final int? closingDay;
  final int? dueDay;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    this.initialBalance = 0.0,
    required this.color,
    required this.icon,
    this.includeInTotal = true,
    this.currentBalance = 0.0,
    this.creditLimit,
    this.closingDay,
    this.dueDay,
  });

  Color get colorValue => Color(color);

  bool get isCreditCard => type == AccountType.creditCard;

  /// Deuda consumida acumulada en la tarjeta.
  /// Si el balance es negativo (gastos > abonos), la deuda es su valor absoluto.
  double get currentDebt {
    if (!isCreditCard) return 0.0;
    return currentBalance < 0 ? currentBalance.abs() : 0.0;
  }

  /// Cupo disponible restante en la tarjeta.
  /// Límite total menos deuda acumulada (o suma saldo a favor si balance es positivo).
  double get availableCredit {
    if (!isCreditCard) return currentBalance;
    final limit = creditLimit ?? 0.0;
    return limit + currentBalance;
  }

  /// Ratio de utilización del cupo (de 0.0 a 1.0).
  double get creditUtilization {
    if (!isCreditCard || creditLimit == null || creditLimit! <= 0) return 0.0;
    return (currentDebt / creditLimit!).clamp(0.0, 1.0);
  }

  /// Porcentaje de utilización del cupo (de 0.0 a 100.0).
  double get creditUtilizationPercent => creditUtilization * 100.0;

  IconData get iconData {
    switch (icon) {
      case 'account_balance':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'savings':
        return Icons.savings;
      case 'trending_up':
        return Icons.trending_up;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'payments':
      default:
        return Icons.payments;
    }
  }

  String get typeLabel {
    switch (type) {
      case AccountType.cash:
        return 'Efectivo';
      case AccountType.bank:
        return 'Cuenta bancaria';
      case AccountType.creditCard:
        return 'Tarjeta de crédito';
      case AccountType.savings:
        return 'Ahorros';
      case AccountType.investment:
        return 'Inversión';
      case AccountType.other:
        return 'Otra';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'initialBalance': initialBalance,
      'color': color,
      'icon': icon,
      'includeInTotal': includeInTotal ? 1 : 0,
      'creditLimit': creditLimit,
      'closingDay': closingDay,
      'dueDay': dueDay,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map, {double currentBalance = 0.0}) {
    final typeName = map['type'] as String? ?? 'cash';
    final type = AccountType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => AccountType.cash,
    );

    return AccountModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: type,
      initialBalance: (map['initialBalance'] as num?)?.toDouble() ?? 0.0,
      color: map['color'] as int? ?? 0xFF00695C,
      icon: map['icon'] as String? ?? 'payments',
      includeInTotal: (map['includeInTotal'] as int? ?? 1) == 1,
      currentBalance: currentBalance,
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
      closingDay: map['closingDay'] as int?,
      dueDay: map['dueDay'] as int?,
    );
  }

  AccountModel copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? initialBalance,
    int? color,
    String? icon,
    bool? includeInTotal,
    double? currentBalance,
    double? creditLimit,
    int? closingDay,
    int? dueDay,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      initialBalance: initialBalance ?? this.initialBalance,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      currentBalance: currentBalance ?? this.currentBalance,
      creditLimit: creditLimit ?? this.creditLimit,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
    );
  }
}
