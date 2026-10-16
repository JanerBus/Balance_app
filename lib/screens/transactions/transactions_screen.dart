import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/security_provider.dart';
import '../../models/transaction_model.dart';
import '../../widgets/transaction_tile.dart';
import '../../utils/formatters.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TransactionType? _filter;
  String? _accountFilter;
  String _searchQuery = '';
  bool _isSearching = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _formatGroupHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return 'Hoy · ${Formatters.dayMonth(date)}';
    } else if (checkDate == yesterday) {
      return 'Ayer · ${Formatters.dayMonth(date)}';
    } else {
      return Formatters.shortDate(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final isPrivacyMode = context.watch<SecurityProvider?>()?.isPrivacyModeEnabled ?? false;
    final accounts = accountProvider.accounts;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    var list = financeProvider.transactions;

    // Filtro por tipo (Ingreso, Gasto, Transferencia)
    if (_filter != null) {
      list = list.where((t) => t.type == _filter).toList();
    }

    // Filtro por cuenta
    if (_accountFilter != null) {
      list = list.where((t) => t.accountId == _accountFilter || t.toAccountId == _accountFilter).toList();
    }

    // Filtro por búsqueda de texto
    if (_searchQuery.isNotEmpty) {
      list = list.where((t) =>
          t.title.toLowerCase().contains(_searchQuery) ||
          t.category.toLowerCase().contains(_searchQuery) ||
          (t.note?.toLowerCase().contains(_searchQuery) ?? false)
      ).toList();
    }

    // Métricas del listado filtrado
    final totalFilteredIncome = list
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final totalFilteredExpense = list
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final totalFilteredTransfers = list
        .where((t) => t.type == TransactionType.transfer)
        .fold(0.0, (s, t) => s + t.amount);

    // Agrupación por fecha normalizada
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final t in list) {
      final dateKey = DateTime(t.date.year, t.date.month, t.date.day);
      grouped.putIfAbsent(dateKey, () => []).add(t);
    }

    // Ordenar fechas descendente
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 18,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Buscar concepto o categoría...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          tooltip: 'Limpiar texto',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              )
            : const Text('Actividad Financiera'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                } else {
                  _searchFocusNode.requestFocus();
                }
              });
            },
          ),
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Nuevo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Banner de Métricas del Filtro Activo (visible solo cuando no se busca para evitar desbordamiento con teclado)
          if (!_isSearching)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131824) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _filter == null
                                  ? 'TOTAL MOVIMIENTOS'
                                  : (_filter == TransactionType.expense
                                      ? 'TOTAL GASTOS'
                                      : (_filter == TransactionType.income
                                          ? 'TOTAL INGRESOS'
                                          : 'TOTAL TRANSFERIDO')),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${list.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _filter == null
                                ? Formatters.currency(totalFilteredIncome - totalFilteredExpense, null, isPrivacyMode)
                                : (_filter == TransactionType.expense
                                    ? Formatters.currency(totalFilteredExpense, null, isPrivacyMode)
                                    : (_filter == TransactionType.income
                                        ? Formatters.currency(totalFilteredIncome, null, isPrivacyMode)
                                        : Formatters.currency(totalFilteredTransfers, null, isPrivacyMode))),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: _filter == TransactionType.expense
                                  ? const Color(0xFFF43F5E)
                                  : (_filter == TransactionType.income
                                      ? const Color(0xFF10B981)
                                      : colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_filter == null) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 13, color: Color(0xFF10B981)),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.currency(totalFilteredIncome, null, isPrivacyMode),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFFF43F5E)),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.currency(totalFilteredExpense, null, isPrivacyMode),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF43F5E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Indicador de resultados activos durante la búsqueda
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 15, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Escribe para buscar movimientos...'
                          : '${list.length} ${list.length == 1 ? 'resultado encontrado' : 'resultados encontrados'}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // 2. Segmented Filter Bar tipo Cápsula
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131824) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _buildTypeTab(label: 'Todos', type: null, isDark: isDark),
                  _buildTypeTab(label: 'Gastos', type: TransactionType.expense, isDark: isDark),
                  _buildTypeTab(label: 'Ingresos', type: TransactionType.income, isDark: isDark),
                  _buildTypeTab(label: 'Transf.', type: TransactionType.transfer, isDark: isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 3. Chips de filtro por billetera/cuenta
          if (accounts.length > 1)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildAccountChip(
                    label: 'Todas las billeteras',
                    icon: Icons.all_inclusive_rounded,
                    isSelected: _accountFilter == null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _accountFilter = null);
                    },
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  ...accounts.map((acc) {
                    final isSelected = _accountFilter == acc.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildAccountChip(
                        label: acc.name,
                        icon: acc.iconData,
                        iconColor: acc.colorValue,
                        isSelected: isSelected,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _accountFilter = isSelected ? null : acc.id);
                        },
                        isDark: isDark,
                      ),
                    );
                  }),
                ],
              ),
            ),

          const SizedBox(height: 6),

          // 4. Lista de movimientos agrupada por fecha
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF151C2C) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              size: 28,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No se encontraron movimientos con "$_searchQuery"'
                                : 'No hay movimientos registrados en este filtro',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Intenta buscando por otro término o limpia los filtros activos.'
                                : 'Toca "Nuevo" para registrar tu primer gasto o compra.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, isKeyboardOpen ? 16 : 115),
                    itemCount: sortedDates.length,
                    itemBuilder: (context, dateIndex) {
                      final date = sortedDates[dateIndex];
                      final transactions = grouped[date]!;

                      final dayIncome = transactions
                          .where((t) => t.type == TransactionType.income)
                          .fold(0.0, (s, t) => s + t.amount);
                      final dayExpense = transactions
                          .where((t) => t.type == TransactionType.expense)
                          .fold(0.0, (s, t) => s + t.amount);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF6366F1),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatGroupHeader(date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: -0.2,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${transactions.length})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                if (dayExpense > 0 || dayIncome > 0)
                                  Flexible(
                                    child: Text(
                                      dayIncome > 0 && dayExpense == 0
                                          ? '+${Formatters.currency(dayIncome, null, isPrivacyMode)}'
                                          : '-${Formatters.currency(dayExpense, null, isPrivacyMode)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: dayIncome > 0 && dayExpense == 0
                                            ? const Color(0xFF10B981)
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ...transactions.map((t) => TransactionTile(
                                transaction: t,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: t)),
                                ),
                                onDelete: () => context.read<FinanceProvider>().deleteTransaction(t.id),
                              )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required String label,
    required TransactionType? type,
    required bool isDark,
  }) {
    final isSelected = _filter == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filter = type);
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? (type == TransactionType.expense
                      ? const Color(0xFFF43F5E)
                      : (type == TransactionType.income
                          ? const Color(0xFF10B981)
                          : (type == TransactionType.transfer
                              ? const Color(0xFF6366F1)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)))))
                  : (isDark ? Colors.white54 : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountChip({
    required String label,
    required IconData icon,
    Color? iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? const Color(0xFF131824) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (iconColor ?? (isDark ? Colors.white70 : const Color(0xFF475569))),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
