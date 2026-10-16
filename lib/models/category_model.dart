import 'package:flutter/material.dart';
import 'transaction_model.dart';

class CategoryModel {
  final String name;
  final IconData icon;
  final Color color;
  final TransactionType type;

  const CategoryModel({
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });
}

class AppCategories {
  static const List<CategoryModel> expenseCategories = [
    CategoryModel(name: 'Alimentación', icon: Icons.restaurant, color: Color(0xFFEF6C00), type: TransactionType.expense),
    CategoryModel(name: 'Transporte', icon: Icons.directions_car, color: Color(0xFF1E88E5), type: TransactionType.expense),
    CategoryModel(name: 'Vivienda', icon: Icons.home, color: Color(0xFF6D4C41), type: TransactionType.expense),
    CategoryModel(name: 'Servicios', icon: Icons.bolt, color: Color(0xFFFBC02D), type: TransactionType.expense),
    CategoryModel(name: 'Salud', icon: Icons.medical_services, color: Color(0xFFE53935), type: TransactionType.expense),
    CategoryModel(name: 'Educación', icon: Icons.school, color: Color(0xFF3949AB), type: TransactionType.expense),
    CategoryModel(name: 'Entretenimiento', icon: Icons.movie, color: Color(0xFF8E24AA), type: TransactionType.expense),
    CategoryModel(name: 'Compras', icon: Icons.shopping_bag, color: Color(0xFFD81B60), type: TransactionType.expense),
    CategoryModel(name: 'Suscripciones', icon: Icons.subscriptions, color: Color(0xFF00897B), type: TransactionType.expense),
    CategoryModel(name: 'Otros', icon: Icons.more_horiz, color: Color(0xFF757575), type: TransactionType.expense),
  ];

  static const List<CategoryModel> incomeCategories = [
    CategoryModel(name: 'Salario', icon: Icons.payments, color: Color(0xFF2E7D32), type: TransactionType.income),
    CategoryModel(name: 'Freelance', icon: Icons.laptop_mac, color: Color(0xFF00897B), type: TransactionType.income),
    CategoryModel(name: 'Inversiones', icon: Icons.trending_up, color: Color(0xFF1565C0), type: TransactionType.income),
    CategoryModel(name: 'Regalo', icon: Icons.card_giftcard, color: Color(0xFFAD1457), type: TransactionType.income),
    CategoryModel(name: 'Ventas', icon: Icons.storefront, color: Color(0xFFF9A825), type: TransactionType.income),
    CategoryModel(name: 'Otros', icon: Icons.more_horiz, color: Color(0xFF757575), type: TransactionType.income),
  ];

  static List<CategoryModel> byType(TransactionType type) {
    return type == TransactionType.income ? incomeCategories : expenseCategories;
  }

  static CategoryModel findByName(String name, TransactionType type) {
    final list = byType(type);
    return list.firstWhere(
      (c) => c.name == name,
      orElse: () => list.last,
    );
  }
}
