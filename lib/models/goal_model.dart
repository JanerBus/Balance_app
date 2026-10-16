import 'package:flutter/material.dart';

class GoalModel {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final int color;
  final String icon;
  final String? note;
  final bool isCompleted;
  final DateTime createdAt;

  const GoalModel({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    required this.color,
    required this.icon,
    this.note,
    this.isCompleted = false,
    required this.createdAt,
  });

  Color get colorValue => Color(color);

  IconData get iconData {
    switch (icon) {
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'car':
        return Icons.directions_car_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'phone':
        return Icons.phone_iphone_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'beach':
        return Icons.beach_access_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'emergency':
        return Icons.health_and_safety_rounded;
      case 'savings':
      default:
        return Icons.savings_rounded;
    }
  }

  double get progress => targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  int get progressPercentage => (progress * 100).toInt();
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity);

  int? get daysRemaining {
    if (targetDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate!.year, targetDate!.month, targetDate!.day);
    return target.difference(today).inDays;
  }

  bool get isOverdue {
    final days = daysRemaining;
    return days != null && days < 0 && !isCompleted && currentAmount < targetAmount;
  }

  /// Proyección de ahorro mensual necesario para cumplir la meta a tiempo
  double? get suggestedMonthlySavings {
    final days = daysRemaining;
    if (days == null || days <= 0 || remainingAmount <= 0) return null;
    final months = days / 30.0;
    return remainingAmount / months;
  }

  /// Proyección de ahorro semanal necesario
  double? get suggestedWeeklySavings {
    final days = daysRemaining;
    if (days == null || days <= 0 || remainingAmount <= 0) return null;
    final weeks = days / 7.0;
    return remainingAmount / weeks;
  }

  GoalModel copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    bool clearTargetDate = false,
    int? color,
    String? icon,
    String? note,
    bool clearNote = false,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      color: color ?? this.color,
      icon: icon ?? this.icon,
      note: clearNote ? null : (note ?? this.note),
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate?.toIso8601String(),
      'color': color,
      'icon': icon,
      'note': note,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String,
      title: map['title'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['targetDate'] != null ? DateTime.parse(map['targetDate'] as String) : null,
      color: map['color'] as int,
      icon: map['icon'] as String,
      note: map['note'] as String?,
      isCompleted: (map['isCompleted'] as int?) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
