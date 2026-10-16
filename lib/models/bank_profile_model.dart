import 'package:flutter/material.dart';

class BankProfileModel {
  final String id;
  final String name;
  final String shortName;
  final List<String> packageNames;
  final Color primaryColor;
  final IconData icon;
  final String? defaultCategory;

  const BankProfileModel({
    required this.id,
    required this.name,
    required this.shortName,
    required this.packageNames,
    required this.primaryColor,
    required this.icon,
    this.defaultCategory,
  });

  static const List<BankProfileModel> supportedBanks = [
    BankProfileModel(
      id: 'nu',
      name: 'Nu (Nubank)',
      shortName: 'Nu',
      packageNames: [
        'com.nu.production',
        'com.nu.co',
        'com.nu.mx',
        'br.com.nubank',
        'com.nubank',
        'com.nu.app',
      ],
      primaryColor: Color(0xFF820AD1),
      icon: Icons.credit_card,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'nequi',
      name: 'Nequi Colombia',
      shortName: 'Nequi',
      packageNames: ['com.nequi.MobileApp', 'com.nequi.mobileapp'],
      primaryColor: Color(0xFF200020),
      icon: Icons.account_balance_wallet,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'bancolombia',
      name: 'Bancolombia',
      shortName: 'Bancolombia',
      packageNames: ['com.bancolombia.personas', 'com.bancolombia.alerta', 'com.bancolombia.app'],
      primaryColor: Color(0xFFFDDA24),
      icon: Icons.account_balance,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'daviplata',
      name: 'Daviplata / Davivienda',
      shortName: 'Daviplata',
      packageNames: ['com.davivienda.daviplata', 'com.davivienda.personas', 'com.davivienda.app'],
      primaryColor: Color(0xFFED1C24),
      icon: Icons.payments,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'bbva',
      name: 'BBVA',
      shortName: 'BBVA',
      packageNames: ['com.bbva.bbvacontigo', 'com.bbva.personas', 'com.bbva.app'],
      primaryColor: Color(0xFF004481),
      icon: Icons.account_balance,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'mercadopago',
      name: 'Mercado Pago',
      shortName: 'Mercado Pago',
      packageNames: ['com.mercadopago.wallet'],
      primaryColor: Color(0xFF009EE3),
      icon: Icons.wallet,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'rappipay',
      name: 'RappiPay / RappiCard',
      shortName: 'RappiPay',
      packageNames: ['com.grability.rappi', 'com.rappipay.app'],
      primaryColor: Color(0xFFFF441F),
      icon: Icons.shopping_bag,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'bancodebogota',
      name: 'Banco de Bogotá',
      shortName: 'B. Bogotá',
      packageNames: ['co.com.bancodebogota.app', 'co.com.bancodebogota.bancamovil', 'co.com.bancodebogota'],
      primaryColor: Color(0xFF003882),
      icon: Icons.account_balance,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'scotiabank',
      name: 'Scotiabank Colpatria',
      shortName: 'Colpatria',
      packageNames: ['com.colpatria.bancamovil', 'com.scotiabankcolpatria.app'],
      primaryColor: Color(0xFFED1C24),
      icon: Icons.account_balance,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'falabella',
      name: 'Banco Falabella',
      shortName: 'Falabella',
      packageNames: ['com.bancofalabella.colombia'],
      primaryColor: Color(0xFF00843D),
      icon: Icons.account_balance,
      defaultCategory: 'Otros',
    ),
    BankProfileModel(
      id: 'lulo',
      name: 'Lulo Bank',
      shortName: 'Lulo',
      packageNames: ['com.lulobank.app'],
      primaryColor: Color(0xFF00E575),
      icon: Icons.account_balance,
      defaultCategory: 'Otros',
    ),
  ];

  static BankProfileModel? findByPackage(String packageName) {
    final clean = packageName.trim().toLowerCase();
    for (final bank in supportedBanks) {
      for (final pkg in bank.packageNames) {
        if (clean == pkg.toLowerCase() ||
            clean.startsWith('${pkg.toLowerCase()}:') ||
            clean.contains(pkg.toLowerCase())) {
          return bank;
        }
      }
    }
    // Heurísticas de fallback si el package name de la APK difiere levemente
    if (clean.contains('nubank') || clean.contains('.nu.') || clean.endsWith('.nu') || clean.contains('com.nu')) {
      return findById('nu');
    }
    if (clean.contains('nequi')) {
      return findById('nequi');
    }
    if (clean.contains('bancolombia')) {
      return findById('bancolombia');
    }
    if (clean.contains('davivienda') || clean.contains('daviplata')) {
      return findById('daviplata');
    }
    if (clean.contains('bbva')) {
      return findById('bbva');
    }
    if (clean.contains('mercadopago')) {
      return findById('mercadopago');
    }
    if (clean.contains('rappi')) {
      return findById('rappipay');
    }
    if (clean.contains('bancodebogota')) {
      return findById('bancodebogota');
    }
    if (clean.contains('colpatria') || clean.contains('scotiabank')) {
      return findById('scotiabank');
    }
    if (clean.contains('falabella')) {
      return findById('falabella');
    }
    if (clean.contains('lulobank') || clean.contains('.lulo.')) {
      return findById('lulo');
    }
    return null;
  }

  /// Identifica el banco a partir del contenido del texto o título de la notificación
  /// (muy útil si la notificación llega por SMS de Google/Samsung o nombres de paquete variables).
  static BankProfileModel? findByText(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('nubank') ||
        lower.contains('cuenta nu') ||
        lower.contains('tarjeta nu') ||
        lower.contains('cajita nu') ||
        lower.contains('con tu llave') ||
        lower.contains('tu llave') ||
        lower.contains('llave nu') ||
        (RegExp(r'\bnu\b').hasMatch(lower) && (lower.contains('compra') || lower.contains('pago') || lower.contains('cuenta') || lower.contains('tarjeta') || lower.contains('recibiste')))) {
      return findById('nu');
    }
    if (lower.contains('nequi')) {
      return findById('nequi');
    }
    if (lower.contains('bancolombia')) {
      return findById('bancolombia');
    }
    if (lower.contains('daviplata') || lower.contains('davivienda')) {
      return findById('daviplata');
    }
    if (lower.contains('bbva')) {
      return findById('bbva');
    }
    if (lower.contains('mercadopago') || lower.contains('mercado pago')) {
      return findById('mercadopago');
    }
    if (lower.contains('rappipay') || lower.contains('rappicard')) {
      return findById('rappipay');
    }
    if (lower.contains('banco de bogota') || lower.contains('banco de bogotá')) {
      return findById('bancodebogota');
    }
    if (lower.contains('colpatria') || lower.contains('scotiabank')) {
      return findById('scotiabank');
    }
    if (lower.contains('falabella')) {
      return findById('falabella');
    }
    if (lower.contains('lulo bank') || lower.contains('lulobank')) {
      return findById('lulo');
    }
    return null;
  }

  static BankProfileModel? findById(String id) {
    for (final bank in supportedBanks) {
      if (bank.id == id) {
        return bank;
      }
    }
    return null;
  }
}
