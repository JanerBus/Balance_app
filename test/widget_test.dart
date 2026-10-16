import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_finance/models/transaction_model.dart';
import 'package:personal_finance/models/debt_model.dart';
import 'package:personal_finance/models/debt_payment_model.dart';
import 'package:personal_finance/models/account_model.dart';
import 'package:personal_finance/models/currency_model.dart';
import 'package:personal_finance/models/budget_model.dart';
import 'package:personal_finance/models/recurring_model.dart';
import 'package:personal_finance/models/goal_model.dart';
import 'package:personal_finance/models/goal_transaction_model.dart';
import 'package:personal_finance/providers/security_provider.dart';
import 'package:personal_finance/utils/formatters.dart';
import 'package:personal_finance/utils/calculator_evaluator.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:personal_finance/utils/bank_notification_parser.dart';
import 'package:flutter/material.dart';
import 'package:personal_finance/widgets/account_card_carousel.dart';
import 'package:personal_finance/widgets/quick_action_sheet.dart';
import 'package:personal_finance/widgets/learned_rule_bottom_sheet.dart';
import 'package:personal_finance/widgets/app_walkthrough_sheet.dart';
import 'package:personal_finance/widgets/concept_glossary_sheet.dart';
import 'package:personal_finance/providers/notification_sync_provider.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance/services/csv_export_service.dart';
import 'package:personal_finance/services/report_generator_service.dart';
import 'package:personal_finance/screens/debts/add_debt_screen.dart';
import 'package:personal_finance/screens/transactions/add_transaction_screen.dart';
import 'package:personal_finance/screens/transactions/transactions_screen.dart';
import 'package:personal_finance/screens/settings/bank_sync_screen.dart';
import 'package:personal_finance/screens/settings/notification_settings_screen.dart';
import 'package:personal_finance/providers/notification_settings_provider.dart';
import 'package:personal_finance/providers/debt_provider.dart';
import 'package:personal_finance/providers/currency_provider.dart';
import 'package:personal_finance/providers/finance_provider.dart';
import 'package:personal_finance/providers/account_provider.dart';
import 'package:personal_finance/providers/goal_provider.dart';
import 'package:personal_finance/screens/goals/goals_screen.dart';
import 'package:personal_finance/models/user_learned_rule.dart';
import 'package:personal_finance/screens/splash/splash_screen.dart';
import 'package:personal_finance/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('es');
  });

  group('Unit Tests - Models and Formatters', () {
    test('TransactionModel serialization and deserialization with account fields', () {
      final now = DateTime.now();
      final transaction = TransactionModel(
        id: 'test-1',
        title: 'Supermercado',
        amount: 50000.0,
        type: TransactionType.expense,
        category: 'Alimentación',
        date: now,
        note: 'Compra semanal',
        accountId: 'acc-cash',
      );

      final map = transaction.toMap();
      final fromMap = TransactionModel.fromMap(map);

      expect(fromMap.id, 'test-1');
      expect(fromMap.title, 'Supermercado');
      expect(fromMap.amount, 50000.0);
      expect(fromMap.type, TransactionType.expense);
      expect(fromMap.category, 'Alimentación');
      expect(fromMap.note, 'Compra semanal');
      expect(fromMap.accountId, 'acc-cash');
    });

    test('Transfer TransactionModel serialization with origin and destination accounts', () {
      final now = DateTime.now();
      final transfer = TransactionModel(
        id: 'trans-1',
        title: 'Retiro de cajero',
        amount: 200000.0,
        type: TransactionType.transfer,
        category: 'Transferencia',
        date: now,
        accountId: 'acc-bank',
        toAccountId: 'acc-cash',
      );

      final map = transfer.toMap();
      final fromMap = TransactionModel.fromMap(map);

      expect(fromMap.type, TransactionType.transfer);
      expect(fromMap.accountId, 'acc-bank');
      expect(fromMap.toAccountId, 'acc-cash');
      expect(fromMap.amount, 200000.0);
    });

    test('AccountModel serialization and copyWith', () {
      const account = AccountModel(
        id: 'acc-1',
        name: 'Bancolombia Ahorros',
        type: AccountType.savings,
        initialBalance: 500000.0,
        color: 0xFF1976D2,
        icon: 'account_balance',
        includeInTotal: true,
      );

      final map = account.toMap();
      final fromMap = AccountModel.fromMap(map);

      expect(fromMap.id, 'acc-1');
      expect(fromMap.name, 'Bancolombia Ahorros');
      expect(fromMap.type, AccountType.savings);
      expect(fromMap.initialBalance, 500000.0);
      expect(fromMap.includeInTotal, isTrue);

      final updated = account.copyWith(currentBalance: 750000.0);
      expect(updated.currentBalance, 750000.0);
    });

    test('CurrencyModel and Formatters dynamic currency conversion', () {
      final cop = CurrencyModel.findByCode('COP');
      expect(cop.symbol, '\$');
      expect(cop.decimalDigits, 0);

      final usd = CurrencyModel.findByCode('USD');
      expect(usd.symbol, '\$');
      expect(usd.decimalDigits, 2);

      final formattedCop = Formatters.currency(50000, cop);
      expect(formattedCop.contains('50'), isTrue);

      final formattedUsd = Formatters.currency(1250.50, usd);
      expect(formattedUsd.contains('1'), isTrue);
      expect(formattedUsd.contains('50'), isTrue);
    });

    test('DebtModel with partial payments calculations', () {
      final now = DateTime.now();
      final p1 = DebtPaymentModel(
        id: 'pay-1',
        debtId: 'debt-1',
        amount: 30000.0,
        date: now,
        note: 'Primera cuota',
      );
      final p2 = DebtPaymentModel(
        id: 'pay-2',
        debtId: 'debt-1',
        amount: 20000.0,
        date: now,
        note: 'Segunda cuota',
      );

      final debt = DebtModel(
        id: 'debt-1',
        personName: 'Carlos Pérez',
        amount: 100000.0,
        type: DebtType.theyOweMe,
        createdDate: now,
        dueDate: now.add(const Duration(days: 10)),
        isPaid: false,
        payments: [p1, p2],
      );

      expect(debt.totalPaid, 50000.0);
      expect(debt.remainingAmount, 50000.0);
      expect(debt.progress, 0.5);
      expect(debt.isFullySettled, isFalse);
      expect(debt.isOverdue, isFalse);
      expect(debt.daysUntilDue, greaterThanOrEqualTo(9));

      final settledDebt = debt.copyWith(isPaid: true);
      expect(settledDebt.isFullySettled, isTrue);
      expect(settledDebt.remainingAmount, 0.0);
      expect(settledDebt.progress, 1.0);
    });

    test('DebtPaymentModel serialization and deserialization', () {
      final now = DateTime.now();
      final payment = DebtPaymentModel(
        id: 'pay-100',
        debtId: 'debt-99',
        amount: 75000.0,
        date: now,
        note: 'Pago por transferencia',
      );

      final map = payment.toMap();
      final fromMap = DebtPaymentModel.fromMap(map);

      expect(fromMap.id, 'pay-100');
      expect(fromMap.debtId, 'debt-99');
      expect(fromMap.amount, 75000.0);
      expect(fromMap.note, 'Pago por transferencia');
    });

    test('BudgetModel serialization, remaining and overbudget calculations', () {
      const budget = BudgetModel(
        id: 'b-1',
        category: 'Alimentación',
        amount: 500000.0,
        spent: 350000.0,
      );

      expect(budget.remaining, 150000.0);
      expect(budget.overspent, 0.0);
      expect(budget.progress, 0.7);
      expect(budget.isOverbudget, isFalse);
      expect(budget.isNearLimit, isFalse);

      final nearLimitBudget = budget.copyWith(spent: 420000.0);
      expect(nearLimitBudget.isNearLimit, isTrue);
      expect(nearLimitBudget.isOverbudget, isFalse);

      final overspentBudget = budget.copyWith(spent: 550000.0);
      expect(overspentBudget.isOverbudget, isTrue);
      expect(overspentBudget.overspent, 50000.0);
      expect(overspentBudget.remaining, 0.0);

      final map = budget.toMap();
      final fromMap = BudgetModel.fromMap(map, spent: 350000.0);
      expect(fromMap.id, 'b-1');
      expect(fromMap.category, 'Alimentación');
      expect(fromMap.amount, 500000.0);
      expect(fromMap.spent, 350000.0);
    });

    test('RecurringModel normalized monthly amount and next cycle calculation', () {
      final now = DateTime(2026, 10, 15);
      final netflix = RecurringModel(
        id: 'rec-1',
        title: 'Netflix',
        amount: 44900.0,
        type: TransactionType.expense,
        category: 'Suscripciones',
        accountId: 'acc-card',
        frequency: RecurringFrequency.monthly,
        startDate: now,
        nextDueDate: now,
      );

      expect(netflix.monthlyNormalizedAmount, 44900.0);
      expect(netflix.frequencyLabel, 'Mensual');

      // Next month cycle
      final nextDate = netflix.calculateNextCycleDate;
      expect(nextDate.year, 2026);
      expect(nextDate.month, 11);
      expect(nextDate.day, 15);

      // Yearly normalization
      final amazonYearly = netflix.copyWith(
        amount: 120000.0,
        frequency: RecurringFrequency.yearly,
      );
      expect(amazonYearly.monthlyNormalizedAmount, 10000.0);

      // Biweekly normalization
      final quincena = netflix.copyWith(
        amount: 500000.0,
        frequency: RecurringFrequency.biweekly,
      );
      expect(quincena.monthlyNormalizedAmount, 1000000.0);
    });

    test('Formatters Privacy Mode masks currency values properly', () {
      final cop = CurrencyModel.findByCode('COP');
      Formatters.setCurrency(cop);

      Formatters.isPrivacyMode = false;
      final visible = Formatters.currency(50000);
      expect(visible.contains('50'), isTrue);

      Formatters.isPrivacyMode = true;
      final masked = Formatters.currency(50000);
      expect(masked, '\$ ••••••');

      // Force privacy override
      Formatters.isPrivacyMode = false;
      final forceMasked = Formatters.currency(50000, null, true);
      expect(forceMasked, '\$ ••••••');
    });

    test('SecurityProvider SHA-256 PIN hashing and verification', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final security = SecurityProvider();

      expect(SecurityProvider.hashPin('1234'), SecurityProvider.hashPin('1234'));
      expect(SecurityProvider.hashPin('1234'), isNot(equals(SecurityProvider.hashPin('0000'))));
      // Salt ensures different output from unsalted SHA-256
      expect(SecurityProvider.hashPin('1234'), isNot(equals(SecurityProvider.hashLegacyPin('1234'))));

      // Set pin
      final didSet = await security.setPin('4321');
      expect(didSet, isTrue);
      expect(security.isPinSet, isTrue);

      // Verify pin
      expect(security.verifyPin('4321'), isTrue);
      expect(security.verifyPin('9999'), isFalse);

      // Lock and unlock
      security.lockApp();
      expect(security.isAppLocked, isTrue);

      // Correct pin unlocks
      expect(security.verifyPin('4321'), isTrue);
      expect(security.isAppLocked, isFalse);

      // Remove pin
      await security.removePin();
      expect(security.isPinSet, isFalse);
      expect(security.isSecurityConfigured, isFalse);
    });

    test('SecurityProvider backwards compatibility automatically migrates legacy hashes', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final legacyHash = SecurityProvider.hashLegacyPin('5678');
      SharedPreferences.setMockInitialValues({
        'sp_security_pin_hash': legacyHash,
      });

      final security = SecurityProvider();
      await security.loadSecuritySettings();
      expect(security.isPinSet, isTrue);
      expect(security.isAppLocked, isTrue);

      // Verify with legacy PIN: must authenticate and seamlessly migrate to salted hash
      final isValid = security.verifyPin('5678');
      expect(isValid, isTrue);
      expect(security.isAppLocked, isFalse);

      // Subsequent verifications use salted hash directly
      expect(security.verifyPin('5678'), isTrue);
      expect(security.verifyPin('0000'), isFalse);
    });

    test('CalculatorEvaluator arithmetic operations, precedence and edge cases', () {
      // Basic operations
      expect(CalculatorEvaluator.evaluate('5000 + 2500'), 7500.0);
      expect(CalculatorEvaluator.evaluate('10000 - 3500'), 6500.0);
      expect(CalculatorEvaluator.evaluate('250 * 4'), 1000.0);
      expect(CalculatorEvaluator.evaluate('1000 / 4'), 250.0);

      // Symbol variations (× and ÷)
      expect(CalculatorEvaluator.evaluate('150 × 3'), 450.0);
      expect(CalculatorEvaluator.evaluate('900 ÷ 3'), 300.0);

      // Operator precedence (multiplication & division before addition & subtraction)
      expect(CalculatorEvaluator.evaluate('10 + 5 * 2'), 20.0);
      expect(CalculatorEvaluator.evaluate('50 - 20 / 2'), 40.0);
      expect(CalculatorEvaluator.evaluate('100 + 50 × 2 - 20 ÷ 4'), 195.0);

      // Decimal and comma support
      expect(CalculatorEvaluator.evaluate('12.5 + 7.5'), 20.0);
      expect(CalculatorEvaluator.evaluate('10,5 + 2,5'), 13.0);

      // Live typing trailing operator handling
      expect(CalculatorEvaluator.evaluate('5000 +'), 5000.0);
      expect(CalculatorEvaluator.evaluate('100 *'), 100.0);

      // Division by zero protection
      expect(CalculatorEvaluator.evaluate('100 / 0'), isNull);
      expect(CalculatorEvaluator.evaluate('50 ÷ 0'), isNull);

      // Negative number handling
      expect(CalculatorEvaluator.evaluate('-50 + 100'), 50.0);

      // Empty or invalid input
      expect(CalculatorEvaluator.evaluate(''), isNull);
      expect(CalculatorEvaluator.evaluate('   '), isNull);
      expect(CalculatorEvaluator.evaluate('abc'), isNull);

      // formatResult helper
      expect(CalculatorEvaluator.formatResult(5000.0), '5000');
      expect(CalculatorEvaluator.formatResult(12.50), '12.50');
      expect(CalculatorEvaluator.formatResult(99.99), '99.99');
    });

    test('BankNotificationParser parses Nu, Nequi, Bancolombia and Generic notifications', () {
      // 1. Nu Compra Aprobada con tarjeta
      final nuPurchase = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Compra aprobada',
        text: 'Compra aprobada en Éxito por \$45.000 con tu tarjeta de crédito.',
      );
      expect(nuPurchase, isNotNull);
      expect(nuPurchase!.bankId, 'nu');
      expect(nuPurchase.amount, 45000.0);
      expect(nuPurchase.type, TransactionType.expense);
      expect(nuPurchase.merchantOrPayee, 'Éxito');
      expect(nuPurchase.category, 'Alimentación');

      // 2. Nu Rendimiento Cajita
      final nuCajita = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Nu Cajita',
        text: 'Tu dinero en la Cajita creció \$1.450 hoy.',
      );
      expect(nuCajita, isNotNull);
      expect(nuCajita!.bankId, 'nu');
      expect(nuCajita.amount, 1450.0);
      expect(nuCajita.type, TransactionType.income);
      expect(nuCajita.category, 'Inversiones');

      // 3. Nu Transferencia Recibida
      final nuTransfer = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Transferencia recibida',
        text: 'Recibiste \$120.000 de Pedro Sánchez',
      );
      expect(nuTransfer, isNotNull);
      expect(nuTransfer!.type, TransactionType.income);
      expect(nuTransfer.amount, 120000.0);
      expect(nuTransfer.merchantOrPayee, 'Pedro Sánchez');

      // 4. Nequi Pago en Droguería
      final nequiPay = BankNotificationParser.parse(
        packageName: 'com.nequi.MobileApp',
        title: 'Nequi',
        text: 'Pagaste \$25.000 en Droguería La Rebaja',
      );
      expect(nequiPay, isNotNull);
      expect(nequiPay!.bankId, 'nequi');
      expect(nequiPay.amount, 25000.0);
      expect(nequiPay.type, TransactionType.expense);
      expect(nequiPay.category, 'Salud');

      // 5. Bancolombia Compra
      final bcolPurchase = BankNotificationParser.parse(
        packageName: 'com.bancolombia.personas',
        title: 'Alerta Bancolombia',
        text: 'Bancolombia le informa compra por \$60.000 en Carulla con tarjeta debito',
      );
      expect(bcolPurchase, isNotNull);
      expect(bcolPurchase!.bankId, 'bancolombia');
      expect(bcolPurchase.amount, 60000.0);
      expect(bcolPurchase.type, TransactionType.expense);
      expect(bcolPurchase.category, 'Alimentación');

      // 6. Daviplata Envío
      final daviTransfer = BankNotificationParser.parse(
        packageName: 'com.davivienda.daviplata',
        title: 'Daviplata',
        text: 'Pasó plata por \$20.000 a Andrea Gómez',
      );
      expect(daviTransfer, isNotNull);
      expect(daviTransfer!.bankId, 'daviplata');
      expect(daviTransfer.amount, 20000.0);
      expect(daviTransfer.type, TransactionType.expense);

      // 7. Fallback Heurístico Universal (Banco no listado)
      final genericBank = BankNotificationParser.parse(
        packageName: 'com.coopfinanciera.app',
        title: 'Notificación de Débito',
        text: 'Compra por \$85.000 en Uber con tarjeta débito',
      );
      expect(genericBank, isNotNull);
      expect(genericBank!.bankId, 'generic');
      expect(genericBank.amount, 85000.0);
      expect(genericBank.type, TransactionType.expense);
      expect(genericBank.category, 'Transporte');

      // 8. Notificación no monetaria irrelevante
      final promoNotif = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Promoción especial',
        text: 'Conoce los nuevos beneficios de tu tarjeta Nu este fin de semana.',
      );
      expect(promoNotif, isNull);

      // 9. Nu con espacios no divisibles (non-breaking spaces: \u00A0 y \u202F)
      final nuNbsp = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Compra aprobada',
        text: 'Compra aprobada en D1 por \$\u00A027.800 con tu tarjeta de débito.',
      );
      expect(nuNbsp, isNotNull);
      expect(nuNbsp!.amount, 27800.0);
      expect(nuNbsp.merchantOrPayee, 'D1');

      final nuCompraste = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Nu',
        text: 'Compraste \$\u202F18.500 en Starbucks',
      );
      expect(nuCompraste, isNotNull);
      expect(nuCompraste!.amount, 18500.0);
      expect(nuCompraste.merchantOrPayee, 'Starbucks');

      // 10. Detección vía SMS (aplicación de mensajería externa mencionando a Nu o Bancolombia)
      final smsNu = BankNotificationParser.parse(
        packageName: 'com.google.android.apps.messaging',
        title: 'Nu Colombia',
        text: 'Nu: Compra aprobada en Netflix por \$38.900.',
      );
      expect(smsNu, isNotNull);
      expect(smsNu!.bankId, 'nu');
      expect(smsNu.amount, 38900.0);
      expect(smsNu.merchantOrPayee, 'Netflix');

      final smsBancolombia = BankNotificationParser.parse(
        packageName: 'com.samsung.android.messaging',
        title: 'Mensajes',
        text: 'Bancolombia le informa compra por \$50.000 en Homecenter.',
      );
      expect(smsBancolombia, isNotNull);
      expect(smsBancolombia!.bankId, 'bancolombia');
      expect(smsBancolombia.amount, 50000.0);

      // 11. Ingreso Nu vía llave / Transfiya ("Recibiste 100,00 en tu cuenta")
      final nuIncomeTransfiya = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Recibiste 100,00 en tu cuenta',
        text: 'Te llegó dinero de JANER ANDRES BUSTILLO RUIDIAZ con tu llave.',
      );
      expect(nuIncomeTransfiya, isNotNull);
      expect(nuIncomeTransfiya!.bankId, 'nu');
      expect(nuIncomeTransfiya.type, TransactionType.income);
      expect(nuIncomeTransfiya.amount, 100.0);
      expect(nuIncomeTransfiya.merchantOrPayee, 'JANER ANDRES BUSTILLO RUIDIAZ');

      // 12. Ingreso Nu con decimales y mención de llave
      final nuIncomeDecimal = BankNotificationParser.parse(
        packageName: 'br.com.nubank',
        title: 'Recibiste 50.000,00 en tu cuenta',
        text: 'Te llegó dinero con tu llave.',
      );
      expect(nuIncomeDecimal, isNotNull);
      expect(nuIncomeDecimal!.bankId, 'nu');
      expect(nuIncomeDecimal.type, TransactionType.income);
      expect(nuIncomeDecimal.amount, 50000.0);

      // 13. Notificaciones académicas y no financieras (Moodle, Aula Extendida, Teams, WhatsApp) son rechazadas
      final moodleNotif = BankNotificationParser.parse(
        packageName: 'com.moodle.moodlemobile',
        title: 'NICOL SOFIA LOPEZ TOCORA',
        text: '(vía Aula Extendida...) Tarea de 202 entregada',
      );
      expect(moodleNotif, isNull);

      final whatsappMsg = BankNotificationParser.parse(
        packageName: 'com.whatsapp',
        title: 'Carlos Pérez',
        text: 'Nos vemos a las 5, trae 200 pesos',
      );
      expect(whatsappMsg, isNull);

      // 14. Verificación de coincidencia exacta de palabras en categorización:
      // "TOCORA" no debe catalogarse como "Alimentación" por la palabra "ara"
      final categoryCheck = BankNotificationParser.suggestCategory('LOPEZ TOCORA', 'Tarea de clase', TransactionType.expense);
      expect(categoryCheck, isNot('Alimentación'));
      expect(categoryCheck, 'Otros');

      // "Tiendas Ara" o "Ara" aislada sí debe ser "Alimentación"
      final araCategory = BankNotificationParser.suggestCategory('Tiendas Ara', 'Compra en Ara por 35000', TransactionType.expense);
      expect(araCategory, 'Alimentación');

      // 15. Nuevos perfiles de bancos colombianos (Banco Falabella, Banco de Bogotá, Scotiabank Colpatria, Lulo Bank)
      final falabellaNotif = BankNotificationParser.parse(
        packageName: 'com.bancofalabella.colombia',
        title: 'Banco Falabella',
        text: 'Compra aprobada por \$120.000 en Homecenter con tu tarjeta CMR',
      );
      expect(falabellaNotif, isNotNull);
      expect(falabellaNotif!.bankId, 'falabella');
      expect(falabellaNotif.amount, 120000.0);

      final bogotaNotif = BankNotificationParser.parse(
        packageName: 'com.bancodebogota.bancamovil',
        title: 'Banco de Bogotá',
        text: 'Transferencia por \$45.000 a cuenta de ahorros',
      );
      expect(bogotaNotif, isNotNull);
      expect(bogotaNotif!.bankId, 'bancodebogota');
      expect(bogotaNotif.amount, 45000.0);
    });

    test('UserLearnedRule correctly matches and extracts custom transactions', () {
      final rule = UserLearnedRule(
        id: 'rule-test-1',
        name: 'Lulo Bank Nómina',
        packageName: 'com.lulobank.mobile',
        bankName: 'Lulo Bank',
        triggerKeywords: ['nómina', 'recibiste'],
        type: TransactionType.income,
        defaultCategory: 'Salario',
        fixedMerchant: 'Empresa Empleadora',
        createdAt: DateTime.now(),
      );

      // Matches when package and keywords are present
      expect(
        rule.matches(
          textToEvaluate: '¡Recibiste \$ 3.500.000 de nómina en tu cuenta Lulo!',
          incomingPackage: 'com.lulobank.mobile',
        ),
        isTrue,
      );

      // Does not match when keyword is missing
      expect(
        rule.matches(
          textToEvaluate: 'Compra aprobada por \$50.000',
          incomingPackage: 'com.lulobank.mobile',
        ),
        isFalse,
      );

      // Process notification
      final tx = rule.processNotification(
        title: 'Lulo Bank',
        text: '¡Recibiste \$ 3.500.000 de nómina en tu cuenta Lulo!',
        incomingPackage: 'com.lulobank.mobile',
      );

      expect(tx, isNotNull);
      expect(tx!.amount, 3500000.0);
      expect(tx.type, TransactionType.income);
      expect(tx.category, 'Salario');
      expect(tx.merchantOrPayee, 'Empresa Empleadora');
      expect(tx.bankName, 'Lulo Bank');
    });

    test('BankNotificationParser prioritizes user learned rules over default profiles', () {
      final customNuRule = UserLearnedRule(
        id: 'custom-nu-override',
        name: 'Nu Reembolso',
        packageName: 'com.nu.production',
        bankName: 'Nu Colombia',
        triggerKeywords: ['reembolso'],
        type: TransactionType.income,
        defaultCategory: 'Otros Ingresos',
        fixedMerchant: 'Reembolso Nu',
        createdAt: DateTime.now(),
      );

      final parsed = BankNotificationParser.parse(
        packageName: 'com.nu.production',
        title: 'Reembolso procesado',
        text: 'Se aplicó un reembolso por \$80.000 en tu cuenta.',
        userRules: [customNuRule],
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 80000.0);
      expect(parsed.type, TransactionType.income);
      expect(parsed.merchantOrPayee, 'Reembolso Nu');
      expect(parsed.category, 'Otros Ingresos');
    });

    test('GoalModel and GoalTransactionModel calculations, projections and serialization', () {
      final now = DateTime.now();
      final targetDate = now.add(const Duration(days: 60)); // ~2 months

      final goal = GoalModel(
        id: 'goal-1',
        title: 'Viaje a San Andrés',
        targetAmount: 2000000.0,
        currentAmount: 500000.0,
        targetDate: targetDate,
        color: 0xFF4F46E5,
        icon: 'flight',
        note: 'Vuelos y hotel',
        createdAt: now,
      );

      // Calculations
      expect(goal.progress, 0.25);
      expect(goal.progressPercentage, 25);
      expect(goal.remainingAmount, 1500000.0);
      expect(goal.isCompleted, isFalse);
      expect(goal.isOverdue, isFalse);
      expect(goal.daysRemaining, greaterThanOrEqualTo(59));

      // Projections (~1.5M remaining in 2 months -> ~750k/month, ~175k/week)
      expect(goal.suggestedMonthlySavings, isNotNull);
      expect(goal.suggestedMonthlySavings!, greaterThan(700000.0));
      expect(goal.suggestedMonthlySavings!, lessThan(800000.0));

      expect(goal.suggestedWeeklySavings, isNotNull);
      expect(goal.suggestedWeeklySavings!, greaterThan(150000.0));
      expect(goal.suggestedWeeklySavings!, lessThan(190000.0));

      // Serialization
      final map = goal.toMap();
      final fromMap = GoalModel.fromMap(map);
      expect(fromMap.id, 'goal-1');
      expect(fromMap.title, 'Viaje a San Andrés');
      expect(fromMap.targetAmount, 2000000.0);
      expect(fromMap.currentAmount, 500000.0);
      expect(fromMap.color, 0xFF4F46E5);
      expect(fromMap.icon, 'flight');
      expect(fromMap.note, 'Vuelos y hotel');

      // Goal Transactions
      final deposit = GoalTransactionModel(
        id: 'gtx-1',
        goalId: 'goal-1',
        amount: 250000.0,
        type: GoalTransactionType.deposit,
        date: now,
        note: 'Aporte de quincena',
        accountId: 'acc-savings',
      );
      final tMap = deposit.toMap();
      final tFromMap = GoalTransactionModel.fromMap(tMap);
      expect(tFromMap.id, 'gtx-1');
      expect(tFromMap.amount, 250000.0);
      expect(tFromMap.type, GoalTransactionType.deposit);
      expect(tFromMap.accountId, 'acc-savings');
    });

    test('CsvExportService generates RFC-4180 CSV with UTF-8 BOM, headers, and escaped fields', () {
      final now = DateTime(2026, 10, 14, 15, 30);
      final transactions = [
        TransactionModel(
          id: 'tx-1',
          title: 'Cena con amigos, "La Terraza"',
          amount: 120000.0,
          type: TransactionType.expense,
          category: 'Restaurantes',
          date: now,
          note: 'Incluye propina del 10%',
          accountId: 'acc-1',
        ),
        TransactionModel(
          id: 'tx-2',
          title: 'Salario quincenal',
          amount: 2500000.0,
          type: TransactionType.income,
          category: 'Salario',
          date: now,
          accountId: 'acc-2',
        ),
      ];

      final accounts = [
        const AccountModel(
          id: 'acc-1',
          name: 'Bancolombia Ahorros',
          type: AccountType.bank,
          color: 0xFF2563EB,
          icon: 'account_balance',
        ),
        const AccountModel(
          id: 'acc-2',
          name: 'Nequi',
          type: AccountType.savings,
          color: 0xFF9333EA,
          icon: 'savings',
        ),
      ];

      final csv = CsvExportService.generateCsv(
        transactions: transactions,
        accounts: accounts,
        currency: CurrencyModel.defaultCurrency,
      );

      // Check UTF-8 BOM
      expect(csv.startsWith('\uFEFF'), isTrue);
      // Check headers
      expect(csv.contains('ID,Fecha,Hora,Tipo,Concepto,Categoría,Monto,Moneda,Cuenta Origen,Cuenta Destino,Nota'), isTrue);
      // Check quotes escaping
      expect(csv.contains('"Cena con amigos, ""La Terraza"""'), isTrue);
      expect(csv.contains('Bancolombia Ahorros'), isTrue);
      expect(csv.contains('Salario quincenal'), isTrue);
      expect(csv.contains('Nequi'), isTrue);
    });

    test('CsvExportService neutralizes formula injection triggers (=, +, -, @)', () {
      final now = DateTime(2026, 10, 14, 12, 0);
      final transactions = [
        TransactionModel(
          id: 'tx-injection-1',
          title: '=cmd|\'/C calc\'!A0',
          amount: 100.0,
          type: TransactionType.expense,
          category: '@SUM(A1:A10)',
          date: now,
          note: '+1234567890-formula',
          accountId: 'acc-1',
        ),
      ];
      final accounts = [
        const AccountModel(
          id: 'acc-1',
          name: '-CuentaInsegura',
          type: AccountType.cash,
          color: 0xFF2E7D32,
          icon: 'payments',
        ),
      ];

      final csv = CsvExportService.generateCsv(
        transactions: transactions,
        accounts: accounts,
        currency: CurrencyModel.defaultCurrency,
      );

      // Verify formula characters are safely escaped with single quote prefix
      expect(csv.contains("'=cmd|"), isTrue);
      expect(csv.contains("'@SUM(A1:A10)"), isTrue);
      expect(csv.contains("'+1234567890-formula"), isTrue);
      expect(csv.contains("'-CuentaInsegura"), isTrue);
      // Legitimate numeric amounts are not quote-prefixed
      expect(csv.contains("'100"), isFalse);
    });

    test('FinanceProvider adds and removes transaction listeners properly', () {
      final provider = FinanceProvider();
      void listener(List<TransactionModel> _) {}

      provider.addTransactionsListener(listener);
      // Adding duplicate should not crash or duplicate
      provider.addTransactionsListener(listener);

      provider.removeTransactionsListener(listener);
      // Removing non-existent should be a safe no-op
      provider.removeTransactionsListener(listener);
    });

    test('ReportGeneratorService generates valid PDF bytes with summary metrics and tables', () async {
      final now = DateTime(2026, 10, 14);
      final transactions = [
        TransactionModel(
          id: 'tx-1',
          title: 'Supermercado',
          amount: 150000.0,
          type: TransactionType.expense,
          category: 'Alimentación',
          date: now,
          accountId: 'acc-1',
        ),
        TransactionModel(
          id: 'tx-2',
          title: 'Proyecto Freelance',
          amount: 800000.0,
          type: TransactionType.income,
          category: 'Servicios',
          date: now,
          accountId: 'acc-1',
        ),
      ];

      final accounts = [
        const AccountModel(
          id: 'acc-1',
          name: 'Cuenta Principal',
          type: AccountType.bank,
          color: 0xFF2563EB,
          icon: 'account_balance',
          currentBalance: 650000.0,
        ),
      ];

      final goals = [
        GoalModel(
          id: 'goal-1',
          title: 'Fondo de Emergencia',
          targetAmount: 5000000.0,
          currentAmount: 1500000.0,
          color: 0xFF10B981,
          icon: 'savings',
          createdAt: now,
        ),
      ];

      final pdfBytes = await ReportGeneratorService.generateMonthlyReportPdf(
        month: DateTime(2026, 10),
        transactions: transactions,
        accounts: accounts,
        goals: goals,
        currency: CurrencyModel.defaultCurrency,
        totalIncome: 800000.0,
        totalExpense: 150000.0,
      );

      expect(pdfBytes, isNotEmpty);
      // PDF documents start with %PDF
      final header = String.fromCharCodes(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });

    testWidgets('AccountCardCarousel renders Global card and individual accounts correctly on 360x800 without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final accounts = [
        const AccountModel(
          id: 'acc-nu',
          name: 'Nu Cuenta',
          type: AccountType.bank,
          color: 0xFF820AD1,
          icon: 'credit_card',
          currentBalance: 1250000.0,
        ),
        const AccountModel(
          id: 'acc-cash',
          name: 'Efectivo',
          type: AccountType.cash,
          color: 0xFF10B981,
          icon: 'payments',
          currentBalance: 450000.0,
        ),
      ];

      String? selectedId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountCardCarousel(
              accounts: accounts,
              totalBalance: 1700000.0,
              selectedAccountId: selectedId,
              onAccountSelected: (id) => selectedId = id,
            ),
          ),
        ),
      );

      // Verify global card exists
      expect(find.text('TARJETA CONSOLIDADA'), findsOneWidget);
      expect(find.text('2 Cuentas'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Swipe to first account (Nu)
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('NU CUENTA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('QuickActionSheet renders action options correctly on 360x800 viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final syncProvider = NotificationSyncProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: syncProvider,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuickActionSheet(),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Acciones Rápidas'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('Transferencia'), findsOneWidget);
      expect(find.text('Calculadora'), findsOneWidget);
      expect(find.text('Nueva Meta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AddDebtScreen renders on 360x800 viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final debtProvider = DebtProvider();
      final currencyProvider = CurrencyProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: debtProvider),
            ChangeNotifierProvider.value(value: currencyProvider),
          ],
          child: const MaterialApp(
            home: AddDebtScreen(),
          ),
        ),
      );

      expect(find.text('Nueva Deuda'), findsOneWidget);
      expect(find.text('Me deben'), findsOneWidget);
      expect(find.text('Yo debo'), findsOneWidget);
      expect(find.text('Calculadora'), findsOneWidget);
      final err = tester.takeException();
      if (err is FlutterError) {
        // ignore: avoid_print
        print(err.toStringDeep());
      }
      expect(err, isNull);
    });

    testWidgets('AddTransactionScreen renders on 360x800 viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final financeProvider = FinanceProvider();
      final accountProvider = AccountProvider();
      final currencyProvider = CurrencyProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: financeProvider),
            ChangeNotifierProvider.value(value: accountProvider),
            ChangeNotifierProvider.value(value: currencyProvider),
          ],
          child: const MaterialApp(
            home: AddTransactionScreen(),
          ),
        ),
      );

      expect(find.text('Nuevo movimiento'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('Transfer.'), findsOneWidget);
      expect(find.text('Calculadora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('AccountModel credit card getters and serialization', () {
      const creditAccount = AccountModel(
        id: 'acc-credit-1',
        name: 'Nu Tarjeta',
        type: AccountType.creditCard,
        initialBalance: 0,
        currentBalance: -500000.0,
        color: 0xFF820AD1,
        icon: 'credit_card',
        creditLimit: 2500000.0,
        closingDay: 5,
        dueDay: 15,
      );

      expect(creditAccount.isCreditCard, isTrue);
      expect(creditAccount.currentDebt, 500000.0);
      expect(creditAccount.availableCredit, 2000000.0);
      expect(creditAccount.creditUtilization, 0.2);
      expect(creditAccount.creditUtilizationPercent, 20.0);

      // Verify serialization
      final map = creditAccount.toMap();
      expect(map['creditLimit'], 2500000.0);
      expect(map['closingDay'], 5);
      expect(map['dueDay'], 15);

      final fromMap = AccountModel.fromMap(map, currentBalance: -500000.0);
      expect(fromMap.isCreditCard, isTrue);
      expect(fromMap.creditLimit, 2500000.0);
      expect(fromMap.closingDay, 5);
      expect(fromMap.dueDay, 15);
      expect(fromMap.currentDebt, 500000.0);
      expect(fromMap.availableCredit, 2000000.0);
      expect(fromMap.creditUtilization, 0.2);
      expect(fromMap.creditUtilizationPercent, 20.0);
    });

    testWidgets('AccountCardCarousel renders credit card on 360x800 viewport without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final accounts = [
        const AccountModel(
          id: 'acc-credit-nu',
          name: 'Nu Tarjeta de Crédito',
          type: AccountType.creditCard,
          initialBalance: 0,
          currentBalance: -850000.0,
          color: 0xFF820AD1,
          icon: 'credit_card',
          creditLimit: 3000000.0,
          closingDay: 7,
          dueDay: 20,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountCardCarousel(
              accounts: accounts,
              totalBalance: -850000.0,
              selectedAccountId: 'acc-credit-nu',
              onAccountSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEUDA ACTUAL'), findsOneWidget);
      expect(find.text('DISPONIBLE'), findsOneWidget);
      expect(find.text('Pagar Tarjeta'), findsOneWidget);
      expect(find.text('Paga: día 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BankSyncScreen with diagnostic logs renders on 360x800 viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final syncProvider = NotificationSyncProvider();
      final accountProvider = AccountProvider();

      // Enable sync to process notifications
      await syncProvider.toggleSync(true);

      // Process the Nu transfer notification (now supported!)
      syncProvider.processIncomingRawNotification({
        'packageName': 'com.nu.production',
        'title': 'Recibiste 100,00 en tu cuenta',
        'text': 'Te llegó dinero de JANER ANDRES BUSTILLO RUIDIAZ con tu llave.',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Also process a non-bank notification to test the long status pill layout
      syncProvider.processIncomingRawNotification({
        'packageName': 'com.touchtype.swiftkey',
        'title': 'Seleccionar modo de ingreso',
        'text': 'Teclado Microsoft SwiftKey - Teclado Microsoft SwiftKey',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: syncProvider),
            ChangeNotifierProvider.value(value: accountProvider),
          ],
          child: const MaterialApp(
            home: BankSyncScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Consola de Diagnóstico en Vivo'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Consola de Diagnóstico en Vivo'), findsOneWidget);
      expect(find.text('Limpiar'), findsOneWidget);
      expect(find.text('Enseñar a My Money'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Motor de Aprendizaje'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Motor de Aprendizaje'), findsOneWidget);
      final error = tester.takeException();
      if (error is FlutterError) {
        debugPrint(error.toStringDeep());
      }
      expect(error, isNull);
    });

    test('NotificationSettingsProvider toggles, persistence, and smart alert rules', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = NotificationSettingsProvider();

      expect(provider.notifyBankTransactions, isTrue);
      expect(provider.notifyBudgetAlerts, isTrue);
      expect(provider.notifyDebtReminders, isTrue);
      expect(provider.notifyRecurringReminders, isTrue);
      expect(provider.notifyDailyReminder, isTrue);
      expect(provider.dailyReminderHour, 20);

      await provider.setNotifyBudgetAlerts(false);
      expect(provider.notifyBudgetAlerts, isFalse);

      await provider.setDailyReminderTime(const TimeOfDay(hour: 21, minute: 30));
      expect(provider.dailyReminderHour, 21);
      expect(provider.dailyReminderMinute, 30);

      // Evaluar alertas inteligentes sin excepciones
      final now = DateTime.now();
      await provider.evaluateAndDispatchAlerts(
        transactions: [
          TransactionModel(
            id: 'tx-test-budget',
            title: 'Mercado Carulla',
            amount: 90000.0,
            type: TransactionType.expense,
            category: 'Alimentación',
            date: now,
          ),
        ],
        budgets: [
          const BudgetModel(id: 'b-1', category: 'Alimentación', amount: 100000.0),
        ],
        debts: [
          DebtModel(
            id: 'd-1',
            personName: 'Carlos M.',
            amount: 50000.0,
            type: DebtType.iOwe,
            createdDate: now,
            dueDate: now.add(const Duration(days: 1)),
          ),
        ],
        recurring: [
          RecurringModel(
            id: 'r-1',
            title: 'Netflix',
            amount: 38900.0,
            type: TransactionType.expense,
            category: 'Suscripciones',
            accountId: 'acc-1',
            frequency: RecurringFrequency.monthly,
            startDate: now,
            nextDueDate: now.add(const Duration(days: 1)),
          ),
        ],
        currency: CurrencyModel.defaultCurrency,
      );

      final testSent = await provider.sendTestNotification();
      expect(testSent, isTrue);
    });

    testWidgets('NotificationSettingsScreen renders on 360x800 viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final provider = NotificationSettingsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(
            home: NotificationSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Centro de Notificaciones'), findsOneWidget);
      expect(find.text('Movimientos bancarios detectados'), findsOneWidget);
      expect(find.text('Límites de Presupuesto (80% y 100%)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Vencimiento de Deudas y Préstamos'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Vencimiento de Deudas y Préstamos'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Recordatorio Diario de Balance'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Recordatorio Diario de Balance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GoalsScreen renders on 360x800 and 320x640 viewports without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = MockGoalProvider();
      provider.goals = [
        GoalModel(
          id: 'goal-1',
          title: 'Fondo de Emergencia Familiar 2026',
          targetAmount: 15000000.0,
          currentAmount: 7500000.0,
          color: 0xFF4F46E5,
          icon: 'savings',
          createdAt: DateTime.now(),
          targetDate: DateTime.now().add(const Duration(days: 90)),
        ),
      ];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GoalProvider>.value(value: provider),
          ],
          child: const MaterialApp(
            home: GoalsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ahorro Consolidado'), findsOneWidget);
      expect(find.text('0/1 cumplidas'), findsOneWidget);
      expect(find.text('Progreso general'), findsOneWidget);
      expect(find.text('Fondo de Emergencia Familiar 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify on ultra compact 320x640 viewport as well
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('LearnedRuleBottomSheet renders on 360x800 viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final accountProvider = AccountProvider();
      final syncProvider = NotificationSyncProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<NotificationSyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LearnedRuleBottomSheet(),
            ),
          ),
        ),
      );
      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        originalOnError?.call(details);
      };

      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;

      if (caughtDetails != null) {
        debugPrint('DIAGNOSTICS:\n${caughtDetails!.toDiagnosticsNode().toStringDeep()}');
      }
      expect(caughtDetails, isNull);

      // Verify on ultra compact 320x640 viewport
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test with captured notification from log
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
            ChangeNotifierProvider<NotificationSyncProvider>.value(value: syncProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LearnedRuleBottomSheet(
                initialPackage: 'com.falabella.banco',
                initialTitle: 'Banco Falabella',
                initialText: 'Compra aprobada por \$185.000 en EXITO CALLE 80 con tu CMR',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final testRule = UserLearnedRule(
        id: '1',
        name: 'Regla Falabella',
        bankName: 'Falabella',
        packageName: 'com.falabella.banco',
        triggerKeywords: ['compra aprobada'],
        type: TransactionType.expense,
        createdAt: DateTime.now(),
      );
      final matches = testRule.matches(
        textToEvaluate: 'Banco Falabella Compra aprobada por \$185.000 en EXITO CALLE 80 con tu CMR',
        incomingPackage: 'com.falabella.banco',
      );
      final tx = testRule.processNotification(
        title: 'Banco Falabella',
        text: 'Compra aprobada por \$185.000 en EXITO CALLE 80 con tu CMR',
        incomingPackage: 'com.falabella.banco',
      );
      expect(matches, isTrue);
      expect(tx, isNotNull);
      expect(tx!.amount, 185000.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppWalkthroughSheet renders on 360x800 and 320x640 viewports without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppWalkthroughSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido a My Money'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Siguiente to advance slide
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      expect(find.text('Cuentas y Tarjetas de Crédito'), findsOneWidget);
      expect(find.byTooltip('Anterior'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify on ultra compact 320x640 viewport
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ConceptGlossarySheet renders on 360x800 and 320x640 viewports and filters categories', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConceptGlossarySheet(initialCategory: 'Motor de Reglas'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Glosario y Guía de Conceptos'), findsOneWidget);
      expect(find.text('Palabras Clave (Trigger Keywords)'), findsOneWidget);
      expect(find.text('Paquete de la App (Package Name)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switch category filter
      final cuentasChip = find.text('Cuentas y Tarjetas');
      await tester.scrollUntilVisible(cuentasChip, 50.0, scrollable: find.byType(Scrollable).first);
      await tester.tap(cuentasChip);
      await tester.pumpAndSettle();

      expect(find.text('Cupo Total de Tarjeta de Crédito'), findsOneWidget);
      expect(find.text('Fecha de Corte (Billing Cutoff)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify on ultra compact 320x640 viewport
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TransactionsScreen search with virtual keyboard renders without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final financeProvider = FinanceProvider();
      final accountProvider = AccountProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<FinanceProvider>.value(value: financeProvider),
            ChangeNotifierProvider<AccountProvider>.value(value: accountProvider),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Actividad Financiera'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap search icon to open search mode
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Simulate keyboard opening (bottom inset = 340px)
      tester.view.viewInsets = const FakeViewPadding(bottom: 340.0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Type a query that has no results (empty state while keyboard is active)
      await tester.enterText(find.byType(TextField), 'inexistente');
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron movimientos con "inexistente"'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify on ultra compact 320x640 viewport with keyboard still active
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Clear search text with the suffix clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('SplashScreen renders on 360x800 and 320x640 viewports without RenderFlex overflow in light and dark mode', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      // Test dark mode on standard 360x800 viewport
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: const SplashScreen(
            autoNavigate: false,
          ),
        ),
      );

      // Advance initial animation
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('My Money'), findsOneWidget);
      expect(find.text('Tu centro financiero personal'), findsOneWidget);
      expect(find.text('Iniciando tus finanzas...'), findsOneWidget);
      expect(find.text('100% Local, Seguro y Privado'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Advance further
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.takeException(), isNull);

      // Test light mode on ultra-compact 320x640 viewport
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SplashScreen(
            autoNavigate: false,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('My Money'), findsOneWidget);
      expect(find.text('Tu centro financiero personal'), findsOneWidget);
      expect(find.text('Iniciando tus finanzas...'), findsOneWidget);
      expect(find.text('100% Local, Seguro y Privado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SplashScreen tap skips animation and triggers onFinished and navigation immediately', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      bool finishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            autoNavigate: true,
            animationDuration: const Duration(seconds: 3),
            onFinished: () => finishedCalled = true,
            nextScreen: const Scaffold(
              body: Center(child: Text('Destination Screen')),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(finishedCalled, isFalse);
      expect(find.text('Destination Screen'), findsNothing);

      // User taps anywhere to skip
      await tester.tap(find.byType(SplashScreen));
      await tester.pumpAndSettle();

      expect(finishedCalled, isTrue);
      expect(find.text('Destination Screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SplashScreen auto-navigates smoothly upon animation completion', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.viewInsets = FakeViewPadding.zero;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      bool finishedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            autoNavigate: true,
            animationDuration: const Duration(milliseconds: 100),
            onFinished: () => finishedCalled = true,
            nextScreen: const Scaffold(
              body: Center(child: Text('Auto Destination Screen')),
            ),
          ),
        ),
      );

      // Pump through animation duration and navigation delay
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(finishedCalled, isTrue);
      expect(find.text('Auto Destination Screen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class MockGoalProvider extends ChangeNotifier implements GoalProvider {
  @override
  List<GoalModel> goals = [];
  @override
  bool isLoading = false;
  @override
  List<GoalModel> get activeGoals => goals.where((g) => !g.isCompleted && g.currentAmount < g.targetAmount).toList();
  @override
  List<GoalModel> get completedGoals => goals.where((g) => g.isCompleted || g.currentAmount >= g.targetAmount).toList();
  @override
  double get totalTarget => goals.fold(0.0, (sum, g) => sum + g.targetAmount);
  @override
  double get totalSaved => goals.fold(0.0, (sum, g) => sum + g.currentAmount);
  @override
  double get overallProgress => totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
  @override
  int get completedCount => completedGoals.length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
