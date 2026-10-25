import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/account_model.dart';
import '../../providers/finance_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/financial_calculator_sheet.dart';
import '../../utils/calculator_evaluator.dart';
import '../../utils/formatters.dart';
import '../accounts/accounts_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existing;
  final TransactionType? initialType;
  final String? initialAccountId;
  final String? initialToAccountId;
  final double? initialAmount;
  final String? initialTitle;
  final String? initialCategory;

  const AddTransactionScreen({
    super.key,
    this.existing,
    this.initialType,
    this.initialAccountId,
    this.initialToAccountId,
    this.initialAmount,
    this.initialTitle,
    this.initialCategory,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  String? _selectedAccountId;
  String? _selectedToAccountId;

  // Sugerencias rápidas de conceptos según tipo
  final Map<TransactionType, List<Map<String, String>>> _quickSuggestions = {
    TransactionType.expense: [
      {'title': 'Almuerzo', 'category': 'Alimentación'},
      {'title': 'Supermercado', 'category': 'Alimentación'},
      {'title': 'Transporte', 'category': 'Transporte'},
      {'title': 'Café', 'category': 'Alimentación'},
      {'title': 'Servicios', 'category': 'Servicios'},
      {'title': 'Farmacia', 'category': 'Salud'},
    ],
    TransactionType.income: [
      {'title': 'Salario mensual', 'category': 'Salario'},
      {'title': 'Honorarios Freelance', 'category': 'Freelance'},
      {'title': 'Venta', 'category': 'Ventas'},
      {'title': 'Rendimientos', 'category': 'Inversiones'},
      {'title': 'Regalo', 'category': 'Regalo'},
    ],
    TransactionType.transfer: [
      {'title': 'Ahorro quincenal', 'category': 'Transferencia'},
      {'title': 'Pago tarjeta de crédito', 'category': 'Transferencia'},
      {'title': 'Retiro de efectivo', 'category': 'Transferencia'},
      {'title': 'Bolsillo de emergencia', 'category': 'Transferencia'},
    ],
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(0);
      _noteController.text = e.note ?? '';
      _type = e.type;
      _selectedCategory = e.category;
      _selectedDate = e.date;
      _selectedAccountId = e.accountId;
      _selectedToAccountId = e.toAccountId;
    } else {
      if (widget.initialType != null) {
        _type = widget.initialType!;
      }
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(0);
      }
      if (widget.initialAccountId != null) {
        _selectedAccountId = widget.initialAccountId;
      }
      if (widget.initialToAccountId != null) {
        _selectedToAccountId = widget.initialToAccountId;
      }
      _selectedCategory = widget.initialCategory ??
          (_type == TransactionType.income
              ? AppCategories.incomeCategories.first.name
              : AppCategories.expenseCategories.first.name);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (_type) {
      case TransactionType.expense:
        return const Color(0xFFF43F5E); // Rose
      case TransactionType.income:
        return const Color(0xFF10B981); // Emerald
      case TransactionType.transfer:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  Future<void> _openCalculator() async {
    HapticFeedback.selectionClick();
    final currentAmount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    final calculated = await FinancialCalculatorSheet.show(
      context,
      initialValue: currentAmount,
      title: 'Monto de ${_type == TransactionType.income ? 'Ingreso' : (_type == TransactionType.expense ? 'Gasto' : 'Transferencia')}',
    );
    if (calculated != null && mounted) {
      setState(() {
        _amountController.text = CalculatorEvaluator.formatResult(calculated);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final currencyProvider = context.watch<CurrencyProvider>();
    final accounts = accountProvider.accounts;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existing != null;
    final isTransfer = _type == TransactionType.transfer;

    // Asignar cuenta por defecto si no está seteada
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accountProvider.selectedAccountId ?? accounts.first.id;
    }
    if (isTransfer && _selectedToAccountId == null && accounts.length > 1) {
      _selectedToAccountId = accounts.firstWhere(
        (a) => a.id != _selectedAccountId,
        orElse: () => accounts.last,
      ).id;
    }

    final categories = AppCategories.byType(_type);
    final suggestions = _quickSuggestions[_type] ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F141F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          isEditing ? 'Editar movimiento' : 'Nuevo movimiento',
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF43F5E)),
              tooltip: 'Eliminar movimiento',
              onPressed: _confirmDelete,
            ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _submit(accounts);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 4,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isEditing
                      ? 'Guardar cambios'
                      : (_type == TransactionType.expense
                          ? 'Registrar Gasto'
                          : (_type == TransactionType.income
                              ? 'Registrar Ingreso'
                              : 'Realizar Transferencia')),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          children: [
            // 1. Selector de Tipo Segmentado Cápsula
            _buildTypeSwitcher(isDark),

            const SizedBox(height: 18),

            // 2. Hero Card de Monto con Calculadora Integrada
            _buildAmountHero(currencyProvider, isDark),

            const SizedBox(height: 20),

            // 3. Card de Cuentas (Origen y Destino si es transferencia)
            _buildAccountsCard(accounts, isDark),

            const SizedBox(height: 16),

            // 4. Card de Título y Sugerencias Rápidas
            _buildTitleAndSuggestionsCard(suggestions, isDark),

            const SizedBox(height: 16),

            // 5. Card de Categorías (solo para Gastos e Ingresos)
            if (!isTransfer) ...[
              _buildCategorySelectorCard(categories, isDark),
              const SizedBox(height: 16),
            ],

            // 6. Card de Fecha y Notas
            _buildDateAndNotesCard(isDark),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Switcher segmentado moderno para Gasto, Ingreso, Transferencia
  Widget _buildTypeSwitcher(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : const Color(0xFFEDF2F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          _buildTypeTab(
            type: TransactionType.expense,
            label: 'Gasto',
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFF43F5E),
            isDark: isDark,
          ),
          _buildTypeTab(
            type: TransactionType.income,
            label: 'Ingreso',
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          _buildTypeTab(
            type: TransactionType.transfer,
            label: 'Transfer.',
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab({
    required TransactionType type,
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _type = type;
            if (_type != TransactionType.transfer) {
              _selectedCategory = AppCategories.byType(_type).first.name;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF222B3E) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de entrada Hero de monto con acceso a calculadora
  Widget _buildAmountHero(CurrencyProvider currencyProvider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'MONTO A REGISTRAR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '${currencyProvider.currency.symbol} ',
              prefixStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: _accentColor,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa un monto';
              final parsed = double.tryParse(value.replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) return 'Monto inválido';
              return null;
            },
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _openCalculator,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calculate_rounded, size: 16, color: _accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'Calculadora',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de cuentas (Origen / Destino)
  Widget _buildAccountsCard(List<AccountModel> accounts, bool isDark) {
    final isTransfer = _type == TransactionType.transfer;
    final originAccount = accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => accounts.isNotEmpty ? accounts.first : const AccountModel(id: '', name: 'General', type: AccountType.cash, color: 0xFF6366F1, icon: 'wallet'),
    );

    final destAccount = isTransfer
        ? accounts.firstWhere(
            (a) => a.id == _selectedToAccountId,
            orElse: () => accounts.last,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isTransfer ? 'CUENTAS DE TRANSFERENCIA' : 'CUENTA / BILLETERA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await AccountsScreen.showAddEditAccountDialog(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                      SizedBox(width: 4),
                      Text(
                        'Nueva cuenta',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (!isTransfer) ...[
            // Selector simple de cuenta origen
            _buildAccountPickerTile(
              label: 'Cuenta afectada',
              account: originAccount,
              accounts: accounts,
              isDark: isDark,
              onSelected: (acc) => setState(() => _selectedAccountId = acc.id),
            ),
          ] else ...[
            // Modo transferencia con visual bridge
            _buildAccountPickerTile(
              label: 'Desde (Origen)',
              account: originAccount,
              accounts: accounts,
              isDark: isDark,
              onSelected: (acc) {
                setState(() {
                  _selectedAccountId = acc.id;
                  if (_selectedToAccountId == acc.id) {
                    _selectedToAccountId = accounts.firstWhere((a) => a.id != acc.id).id;
                  }
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: Divider()),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, size: 16, color: Color(0xFF6366F1)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
            if (destAccount != null)
              _buildAccountPickerTile(
                label: 'Hacia (Destino)',
                account: destAccount,
                accounts: accounts.where((a) => a.id != originAccount.id).toList(),
                isDark: isDark,
                onSelected: (acc) => setState(() => _selectedToAccountId = acc.id),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountPickerTile({
    required String label,
    required AccountModel account,
    required List<AccountModel> accounts,
    required bool isDark,
    required ValueChanged<AccountModel> onSelected,
  }) {
    return InkWell(
      onTap: () => _showAccountSelectionModal(context, accounts, account, onSelected, isDark),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2738) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: account.colorValue.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(account.iconData, size: 20, color: account.colorValue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.currency(account.currentBalance),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountSelectionModal(
    BuildContext context,
    List<AccountModel> accounts,
    AccountModel selected,
    ValueChanged<AccountModel> onSelected,
    bool isDark,
  ) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF151C2C) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seleccionar Cuenta',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final acc = accounts[index];
                      final isCurrent = acc.id == selected.id;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelected(acc);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF1E2738) : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrent ? const Color(0xFF6366F1) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: acc.colorValue.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(acc.iconData, size: 20, color: acc.colorValue),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: TextStyle(
                                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      acc.typeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                Formatters.currency(acc.currentBalance),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Tarjeta de Título/Concepto con sugerencias rápidas
  Widget _buildTitleAndSuggestionsCard(List<Map<String, String>> suggestions, bool isDark) {
    final isTransfer = _type == TransactionType.transfer;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTransfer ? 'DESCRIPCIÓN DE LA TRANSFERENCIA' : 'CONCEPTO / DESCRIPCIÓN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _titleController,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: InputDecoration(
              hintText: isTransfer ? 'Ej. Transferencia a ahorros' : 'Ej. Almuerzo con amigos',
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 22),
              suffixIcon: _titleController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => setState(() => _titleController.clear()),
                    )
                  : null,
            ),
            validator: (value) {
              if (!isTransfer && (value == null || value.trim().isEmpty)) {
                return 'Ingresa un concepto';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Sugerencias rápidas:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: suggestions.map((sug) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(sug['title']!),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                      ),
                      backgroundColor: isDark ? const Color(0xFF1E2738) : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _titleController.text = sug['title']!;
                          if (!isTransfer && sug['category'] != null) {
                            _selectedCategory = sug['category']!;
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Selector de categorías moderno con visual grid de iconos y chips
  Widget _buildCategorySelectorCard(List<CategoryModel> categories, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CATEGORÍA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              if (_selectedCategory != null)
                Text(
                  _selectedCategory!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _accentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final isSelected = cat.name == _selectedCategory;
              return ChoiceChip(
                selected: isSelected,
                selectedColor: cat.color.withValues(alpha: 0.2),
                backgroundColor: isDark ? const Color(0xFF1E2738) : const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: isSelected ? cat.color : Colors.transparent,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                avatar: Icon(cat.icon, size: 16, color: isSelected ? cat.color : (isDark ? Colors.grey : const Color(0xFF64748B))),
                label: Text(cat.name),
                labelStyle: TextStyle(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat.name);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Tarjeta de Fecha con selector rápido y Nota opcional
  Widget _buildDateAndNotesCard(bool isDark) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = _selectedDate.year == yesterday.year && _selectedDate.month == yesterday.month && _selectedDate.day == yesterday.day;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FECHA DEL MOVIMIENTO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildDatePresetChip(
                label: 'Hoy',
                isSelected: isToday,
                isDark: isDark,
                onTap: () => setState(() => _selectedDate = DateTime.now()),
              ),
              const SizedBox(width: 8),
              _buildDatePresetChip(
                label: 'Ayer',
                isSelected: isYesterday,
                isDark: isDark,
                onTap: () => setState(() => _selectedDate = DateTime.now().subtract(const Duration(days: 1))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (!isToday && !isYesterday)
                          ? const Color(0xFF6366F1).withValues(alpha: 0.14)
                          : (isDark ? const Color(0xFF1E2738) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (!isToday && !isYesterday) ? const Color(0xFF6366F1) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            Formatters.shortDate(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 14),
          Text(
            'NOTA ADICIONAL (OPCIONAL)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _noteController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Detalles adicionales, número de factura o etiqueta...',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePresetChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.14)
              : (isDark ? const Color(0xFF1E2738) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
            color: isSelected ? const Color(0xFF6366F1) : (isDark ? Colors.white : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('¿Eliminar movimiento?'),
        content: const Text('Esta acción revertirá el balance de tus cuentas y no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<FinanceProvider>().deleteTransaction(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _submit(List<AccountModel> accounts) async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<FinanceProvider>();
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final isTransfer = _type == TransactionType.transfer;
    final accountId = _selectedAccountId ?? (accounts.isNotEmpty ? accounts.first.id : 'default-cash');

    String title = _titleController.text.trim();
    if (isTransfer && title.isEmpty) {
      final fromAcc = accounts.firstWhere((a) => a.id == accountId, orElse: () => accounts.first);
      final toAcc = accounts.firstWhere((a) => a.id == _selectedToAccountId, orElse: () => accounts.last);
      title = 'Transferencia: ${fromAcc.name} ➔ ${toAcc.name}';
    }

    if (widget.existing != null) {
      await provider.updateTransaction(
        widget.existing!.copyWith(
          title: title,
          amount: amount,
          type: _type,
          category: isTransfer ? 'Transferencia' : (_selectedCategory ?? 'Otros'),
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          accountId: accountId,
          toAccountId: isTransfer ? _selectedToAccountId : null,
        ),
      );
    } else {
      if (isTransfer) {
        final fromAcc = accounts.firstWhere((a) => a.id == accountId, orElse: () => accounts.first);
        final toAcc = accounts.firstWhere((a) => a.id == _selectedToAccountId, orElse: () => accounts.last);

        await provider.addTransfer(
          fromAccountId: accountId,
          toAccountId: _selectedToAccountId!,
          amount: amount,
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          fromAccountName: fromAcc.name,
          toAccountName: toAcc.name,
        );
      } else {
        await provider.addTransaction(
          title: title,
          amount: amount,
          type: _type,
          category: _selectedCategory ?? 'Otros',
          date: _selectedDate,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          accountId: accountId,
        );
      }
    }

    if (mounted) Navigator.pop(context);
  }
}
