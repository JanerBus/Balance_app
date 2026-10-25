import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/account_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/debt_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../services/notification_service.dart';
import 'home/home_screen.dart';
import 'transactions/transactions_screen.dart';
import 'statistics/statistics_screen.dart';
import 'accounts/accounts_screen.dart';
import 'settings/bank_sync_screen.dart';
import 'budgets/budgets_screen.dart';
import 'debts/debts_screen.dart';
import 'recurring/recurring_screen.dart';
import 'assistant/ai_assistant_screen.dart';
import '../widgets/quick_action_sheet.dart';
import '../widgets/app_walkthrough_sheet.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    TransactionsScreen(),
    StatisticsScreen(),
    AccountsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  Future<void> _initializeApp() async {
    if (!mounted) return;
    final financeProvider = context.read<FinanceProvider>();
    final accountProvider = context.read<AccountProvider>();
    final budgetProvider = context.read<BudgetProvider>();
    final recurringProvider = context.read<RecurringProvider>();
    final debtProvider = context.read<DebtProvider>();
    final currencyProvider = context.read<CurrencyProvider>();
    final notifSettings = context.read<NotificationSettingsProvider>();

    // Escucha clics en notificaciones locales para navegar de inmediato
    NotificationService.initialize(onNotificationClicked: _handleNotificationPayload);

    // Comprobar si la app fue abierta desde una notificación con payload
    final initialPayload = await NotificationService.getInitialPayload();
    if (initialPayload != null) {
      _handleNotificationPayload(initialPayload);
    }

    financeProvider.addTransactionsListener((transactions) {
      if (mounted) {
        accountProvider.updateBalances(transactions);
        budgetProvider.updateSpending(transactions);

        // Evaluar alertas inteligentes cuando cambian las transacciones
        notifSettings.evaluateAndDispatchAlerts(
          transactions: transactions,
          budgets: budgetProvider.budgets,
          debts: debtProvider.debts,
          recurring: recurringProvider.recurring,
          currency: currencyProvider.currency,
        );
      }
    });

    await financeProvider.loadTransactions();
    if (mounted) {
      await recurringProvider.checkAndApplyDue(financeProvider);

      // Evaluación inicial de recordatorios de deudas, suscripciones y presupuestos
      await notifSettings.evaluateAndDispatchAlerts(
        transactions: financeProvider.transactions,
        budgets: budgetProvider.budgets,
        debts: debtProvider.debts,
        recurring: recurringProvider.recurring,
        currency: currencyProvider.currency,
      );

      // Si es el primer inicio de la app, mostrar el recorrido y tutorial interactivo
      if (mounted) {
        await AppWalkthroughSheet.checkAndShowFirstTime(context);
      }
    }
  }

  void _handleNotificationPayload(String payloadString) {
    if (!mounted) return;
    try {
      final data = jsonDecode(payloadString) as Map<String, dynamic>;
      final action = data['action']?.toString();

      if (action == 'open_bank_sync') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BankSyncScreen()),
        );
      } else if (action == 'open_budgets') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetsScreen()),
        );
      } else if (action == 'open_debts') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DebtsScreen()),
        );
      } else if (action == 'open_recurring') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecurringScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error procesando payload de notificación: $e');
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: isKeyboardOpen
          ? null
          : _buildAiFloatingActionButton(context, isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: isKeyboardOpen
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131824) : Colors.white,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Tab 0: Inicio
                _buildNavItem(
                  index: 0,
                  label: 'Inicio',
                  activeIcon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  isDark: isDark,
                ),

                // Tab 1: Movimientos
                _buildNavItem(
                  index: 1,
                  label: 'Actividad',
                  activeIcon: Icons.receipt_long_rounded,
                  inactiveIcon: Icons.receipt_long_outlined,
                  isDark: isDark,
                ),

                const SizedBox(width: 4),
                // Central Floating (+) Action Button
                _buildCenterActionButton(context),
                const SizedBox(width: 4),

                // Tab 2: Estadísticas / Análisis
                _buildNavItem(
                  index: 2,
                  label: 'Análisis',
                  activeIcon: Icons.pie_chart_rounded,
                  inactiveIcon: Icons.pie_chart_outline_rounded,
                  isDark: isDark,
                ),

                // Tab 3: Billeteras & Cuentas
                _buildNavItem(
                  index: 3,
                  label: 'Billetera',
                  activeIcon: Icons.account_balance_wallet_rounded,
                  inactiveIcon: Icons.account_balance_wallet_outlined,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: isDark ? 0.2 : 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 22,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? activeColor : inactiveColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () => QuickActionSheet.show(context),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _buildAiFloatingActionButton(BuildContext context, bool isDark) {
    return Semantics(
      button: true,
      label: 'Asistente IA. Abre el asistente inteligente de finanzas',
      child: Tooltip(
        message: 'Asistente IA',
        child: Material(
          elevation: 0,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.3 : 0.45),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.5 : 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'IA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
