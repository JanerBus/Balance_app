import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/security_provider.dart';
import '../../providers/notification_sync_provider.dart';
import '../../providers/goal_provider.dart';
import '../../models/transaction_model.dart';
import '../../widgets/account_card_carousel.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/currency_selector_sheet.dart';
import '../../widgets/app_walkthrough_sheet.dart';
import '../../widgets/concept_glossary_sheet.dart';
import '../../utils/formatters.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transactions_screen.dart';
import '../accounts/accounts_screen.dart';
import '../budgets/budgets_screen.dart';
import '../recurring/recurring_screen.dart';
import '../security/security_settings_screen.dart';
import '../settings/bank_sync_screen.dart';
import '../settings/notification_settings_screen.dart';
import '../goals/goals_screen.dart';
import '../debts/debts_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/data_backup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Buenos días';
    if (hour >= 12 && hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '☀️';
    if (hour >= 12 && hour < 19) return '🌤️';
    return '🌙';
  }

  void _openAdd(BuildContext context, TransactionType type) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final recurringProvider = context.watch<RecurringProvider>();
    final securityProvider = context.watch<SecurityProvider>();
    final syncProvider = context.watch<NotificationSyncProvider>();
    final goalProvider = context.watch<GoalProvider>();

    final selectedAccount = accountProvider.selectedAccount;

    // Filtrar transacciones si hay una cuenta específica seleccionada en el carrusel
    var filteredTransactions = financeProvider.transactions;
    if (selectedAccount != null) {
      filteredTransactions = filteredTransactions
          .where((t) => t.accountId == selectedAccount.id || t.toAccountId == selectedAccount.id)
          .toList();
    }

    final recentTransactions = filteredTransactions.take(6).toList();

    // Calcular balance e ingresos/gastos dinámicos
    final double cardBalance = selectedAccount != null
        ? selectedAccount.currentBalance
        : accountProvider.totalBalance;

    final double cardIncome = selectedAccount != null
        ? filteredTransactions
            .where((t) => t.type == TransactionType.income || (t.type == TransactionType.transfer && t.toAccountId == selectedAccount.id))
            .fold(0.0, (s, t) => s + t.amount)
        : financeProvider.totalIncome;

    final double cardExpense = selectedAccount != null
        ? filteredTransactions
            .where((t) => (t.accountId == selectedAccount.id) && (t.type == TransactionType.expense || t.type == TransactionType.transfer))
            .fold(0.0, (s, t) => s + t.amount)
        : financeProvider.totalExpense;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 18,
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _getGreeting(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(_getGreetingEmoji(), style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Balance',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          // Selector de Moneda Dinámica (Bandera + Código)
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              CurrencySelectorSheet.show(context);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currencyProvider.currency.flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    currencyProvider.currency.code,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Sincronización Bancaria Nu con indicador
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.account_balance_outlined, size: 21),
                tooltip: 'Sincronización Bancaria',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BankSyncScreen()),
                  );
                },
              ),
              if (syncProvider.pendingTransactions.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF43F5E),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                    child: Text(
                      '${syncProvider.pendingTransactions.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else if (syncProvider.isEnabled && syncProvider.isPermissionGranted)
                Positioned(
                  top: 10,
                  right: 8,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          // Seguridad y Modo Privacidad
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              securityProvider.isPrivacyModeEnabled
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 21,
              color: securityProvider.isPrivacyModeEnabled
                  ? const Color(0xFF6366F1)
                  : colorScheme.onSurfaceVariant,
            ),
            tooltip: securityProvider.isPrivacyModeEnabled ? 'Mostrar montos' : 'Ocultar montos',
            onPressed: () {
              HapticFeedback.selectionClick();
              securityProvider.togglePrivacyMode();
            },
          ),

          // Menú rápido de herramientas (incluye Modo Claro/Oscuro, Seguridad, Reportes, Cuentas)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 21),
            tooltip: 'Más opciones',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              HapticFeedback.lightImpact();
              if (val == 'theme') {
                context.read<ThemeProvider>().toggleDarkMode();
              } else if (val == 'security') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()));
              } else if (val == 'reports') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
              } else if (val == 'accounts') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen()));
              } else if (val == 'notifications') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()));
              } else if (val == 'tour') {
                AppWalkthroughSheet.show(context);
              } else if (val == 'glossary') {
                ConceptGlossarySheet.show(context);
              } else if (val == 'backup') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DataBackupScreen()));
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'tour',
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined, size: 18, color: Color(0xFF6366F1)),
                    const SizedBox(width: 10),
                    const Text('Recorrido y Tutorial', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'glossary',
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 10),
                    const Text('Glosario de Conceptos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 18,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isDark ? 'Cambiar a Modo Claro' : 'Cambiar a Modo Oscuro',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFF8B5CF6)),
                    SizedBox(width: 10),
                    Text('Notificaciones y Alertas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'security',
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: Color(0xFF6366F1)),
                    SizedBox(width: 10),
                    Text('Seguridad y PIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined, size: 18, color: Color(0xFFF43F5E)),
                    SizedBox(width: 10),
                    Text('Reportes y Extractos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 10),
                    Text('Gestionar Cuentas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.cloud_sync_outlined, size: 18, color: Color(0xFF0D9488)),
                    SizedBox(width: 10),
                    Text('Copia y Restauración', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await financeProvider.loadTransactions();
          await debtProvider.loadDebts();
          await accountProvider.loadAccounts(financeProvider.transactions);
          await budgetProvider.loadBudgets(financeProvider.transactions);
          await recurringProvider.loadRecurring();
          await recurringProvider.checkAndApplyDue(financeProvider);
          await goalProvider.loadGoals();
        },
        child: ListView(
          // Sin padding horizontal en el ListView raíz para permitir que el carrusel de tarjetas llegue de borde a borde
          padding: const EdgeInsets.only(top: 8, bottom: 110),
          children: [
            // 1. Alerta de Notificaciones Bancarias de Nu pendientes
            if (syncProvider.pendingTransactions.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: _buildPendingBankAlert(context, syncProvider, isDark),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Encabezado de Saldo Consolidado (Apple Wallet / Revolut Style)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildNetWorthHero(
                context: context,
                title: selectedAccount != null ? selectedAccount.name : 'PATRIMONIO TOTAL',
                subtitle: selectedAccount != null ? selectedAccount.typeLabel : 'Todas tus cuentas',
                balance: cardBalance,
                income: cardIncome,
                expense: cardExpense,
                isPrivacyMode: securityProvider.isPrivacyModeEnabled,
                isFiltered: selectedAccount != null,
                onClearFilter: () {
                  HapticFeedback.selectionClick();
                  accountProvider.selectAccount(null);
                },
                colorScheme: colorScheme,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 16),

            // 3. Carrusel Interactivo de Cuentas y Tarjetas (Edge-to-Edge sin recorte lateral)
            AccountCardCarousel(
              accounts: accountProvider.accounts,
              totalBalance: accountProvider.totalBalance,
              selectedAccountId: accountProvider.selectedAccountId,
              isPrivacyMode: securityProvider.isPrivacyModeEnabled,
              onAccountSelected: (accId) {
                accountProvider.selectAccount(accId);
              },
            ),
            const SizedBox(height: 22),

            // 4. Contenido principal con margen lateral uniforme
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de Acciones Rápidas (Gasto, Ingreso, Transferir, Metas)
                  _buildQuickActionsBar(context, isDark),
                  const SizedBox(height: 24),

                  // 5. Bento Insights (Presupuesto + Metas de Ahorro)
                  _buildBentoInsights(
                    context: context,
                    budgetProvider: budgetProvider,
                    goalProvider: goalProvider,
                    debtProvider: debtProvider,
                    isDark: isDark,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 26),

                  // 6. Alerta de suscripciones o pagos recurrentes próximos
                  if (recurringProvider.recurring.isNotEmpty) ...[
                    _buildRecurringCard(context, recurringProvider, isDark, colorScheme),
                    const SizedBox(height: 24),
                  ],

                  // 7. Movimientos Recientes
                  _buildRecentTransactionsSection(
                    context: context,
                    transactions: recentTransactions,
                    selectedAccountName: selectedAccount?.name,
                    financeProvider: financeProvider,
                    accountProvider: accountProvider,
                    isDark: isDark,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SECCIONES MODULARES ---

  Widget _buildNetWorthHero({
    required BuildContext context,
    required String title,
    required String subtitle,
    required double balance,
    required double income,
    required double expense,
    required bool isPrivacyMode,
    required bool isFiltered,
    required VoidCallback onClearFilter,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: isFiltered ? const Color(0xFF6366F1) : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isFiltered) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onClearFilter,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ver todo',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.close_rounded, size: 12, color: Color(0xFF6366F1)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Balance Gigante Minimalista con auto-escalado para montos grandes
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.currency(balance, null, isPrivacyMode),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Píldoras de Flujo Mensual (Ingresos vs Gastos) responsivas sin desbordamiento
          Row(
            children: [
              Expanded(
                child: _buildFlowBadge(
                  label: 'Ingresos',
                  amount: income,
                  isIncome: true,
                  isPrivacyMode: isPrivacyMode,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFlowBadge(
                  label: 'Gastos',
                  amount: expense,
                  isIncome: false,
                  isPrivacyMode: isPrivacyMode,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowBadge({
    required String label,
    required double amount,
    required bool isIncome,
    required bool isPrivacyMode,
    required bool isDark,
  }) {
    final color = isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E);
    final prefix = isIncome ? '↑' : '↓';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.25 : 0.18)),
      ),
      child: Row(
        children: [
          Text(
            prefix,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              Formatters.currency(amount, null, isPrivacyMode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickActionButton(
          context,
          label: 'Gasto',
          icon: Icons.arrow_upward_rounded,
          color: const Color(0xFFF43F5E),
          isDark: isDark,
          onTap: () => _openAdd(context, TransactionType.expense),
        ),
        _buildQuickActionButton(
          context,
          label: 'Ingreso',
          icon: Icons.arrow_downward_rounded,
          color: const Color(0xFF10B981),
          isDark: isDark,
          onTap: () => _openAdd(context, TransactionType.income),
        ),
        _buildQuickActionButton(
          context,
          label: 'Transferir',
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFF6366F1),
          isDark: isDark,
          onTap: () => _openAdd(context, TransactionType.transfer),
        ),
        _buildQuickActionButton(
          context,
          label: 'Metas',
          icon: Icons.flag_rounded,
          color: const Color(0xFF8B5CF6),
          isDark: isDark,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GoalsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161D2B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingBankAlert(BuildContext context, NotificationSyncProvider syncProvider, bool isDark) {
    final count = syncProvider.pendingTransactions.length;
    final first = syncProvider.pendingTransactions.first;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BankSyncScreen()),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF820AD1).withValues(alpha: isDark ? 0.18 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF820AD1).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF820AD1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$count alerta${count > 1 ? 's' : ''} bancaria${count > 1 ? 's' : ''} detectada${count > 1 ? 's' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF820AD1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          first.bankName,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${first.merchantOrPayee}: ${Formatters.currency(first.amount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF820AD1)),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoInsights({
    required BuildContext context,
    required BudgetProvider budgetProvider,
    required GoalProvider goalProvider,
    required DebtProvider debtProvider,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    final topBudget = budgetProvider.budgets.firstOrNull;
    final topGoal = goalProvider.goals.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Salud Financiera',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                );
              },
              child: const Text(
                'Ver presupuestos',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            // Tarjeta Bento 1: Presupuesto del Mes
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131824) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.pie_chart_rounded, size: 16, color: Color(0xFF6366F1)),
                          ),
                          if (topBudget != null)
                            Text(
                              '${(topBudget.progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: topBudget.isOverbudget ? const Color(0xFFF43F5E) : const Color(0xFF6366F1),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        topBudget != null ? topBudget.category : 'Presupuestos',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topBudget != null
                            ? '${Formatters.currency(topBudget.spent)} / ${Formatters.currency(topBudget.amount)}'
                            : 'Configura tus límites de gasto',
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: topBudget != null ? topBudget.clampedProgress : 0.0,
                          minHeight: 5,
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            topBudget != null && topBudget.isOverbudget
                                ? const Color(0xFFF43F5E)
                                : const Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Tarjeta Bento 2: Metas de Ahorro
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131824) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.savings_rounded, size: 16, color: Color(0xFF8B5CF6)),
                          ),
                          if (topGoal != null)
                            Text(
                              '${topGoal.progressPercentage.toInt()}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF8B5CF6),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        topGoal != null ? topGoal.title : 'Metas de Ahorro',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        topGoal != null
                            ? '${Formatters.currency(topGoal.currentAmount)} / ${Formatters.currency(topGoal.targetAmount)}'
                            : 'Crea tu primera alcancía',
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: topGoal != null ? (topGoal.progressPercentage / 100).clamp(0.0, 1.0) : 0.0,
                          minHeight: 5,
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Fila compacta de Deudas (si existen)
        if (debtProvider.debts.isNotEmpty) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebtsScreen()),
            ),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131824) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.handshake_outlined, size: 18, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deudas y préstamos activos',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Te deben ${Formatters.currency(debtProvider.totalTheyOweMe)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('•', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ),
                            Flexible(
                              child: Text(
                                'Debes ${Formatters.currency(debtProvider.totalIOwe)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF43F5E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecurringCard(
    BuildContext context,
    RecurringProvider recurringProvider,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final next = recurringProvider.recurring.first;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecurringScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131824) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_repeat_rounded, color: Color(0xFF06B6D4), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Próximo pago: ${next.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${Formatters.currency(next.amount)} • ${next.frequencyLabel}',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection({
    required BuildContext context,
    required List<TransactionModel> transactions,
    required String? selectedAccountName,
    required FinanceProvider financeProvider,
    required AccountProvider accountProvider,
    required bool isDark,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Movimientos Recientes',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                ),
                if (selectedAccountName != null)
                  Text(
                    'Filtrado por: $selectedAccountName',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                );
              },
              child: const Text('Ver todos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (transactions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131824) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6366F1), size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No hay movimientos recientes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Registra un gasto o compra con Nu para comenzar.',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return TransactionTile(
                transaction: tx,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(existing: tx),
                    ),
                  );
                },
                onDelete: () {
                  HapticFeedback.mediumImpact();
                  financeProvider.deleteTransaction(tx.id);
                },
              );
            },
          ),
      ],
    );
  }
}
