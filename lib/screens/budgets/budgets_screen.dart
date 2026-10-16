import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/budget_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/currency_provider.dart';
import '../../utils/formatters.dart';
import '../../utils/calculator_evaluator.dart';
import '../../widgets/financial_calculator_sheet.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final selectedMonth = budgetProvider.selectedMonth;
    final budgets = budgetProvider.budgets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditBudgetSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Presupuesto'),
      ),
      body: budgetProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                // Selector de Mes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        final prev = DateTime(selectedMonth.year, selectedMonth.month - 1);
                        budgetProvider.setMonth(prev, financeProvider.transactions);
                      },
                    ),
                    Text(
                      Formatters.monthYear(selectedMonth),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        final next = DateTime(selectedMonth.year, selectedMonth.month + 1);
                        budgetProvider.setMonth(next, financeProvider.transactions);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Resumen Global Consolidado de Presupuestos
                if (budgets.isNotEmpty) ...[
                  _GlobalBudgetSummaryCard(
                    totalBudget: budgetProvider.totalBudget,
                    totalSpent: budgetProvider.totalSpent,
                    totalRemaining: budgetProvider.totalRemaining,
                    overallProgress: budgetProvider.clampedOverallProgress,
                    overbudgetCount: budgetProvider.overbudgetCount,
                    nearLimitCount: budgetProvider.nearLimitCount,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Categorías presupuestadas (${budgets.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...budgets.map(
                    (b) => _BudgetCard(
                      budget: b,
                      selectedMonth: selectedMonth,
                      onEdit: () => _showAddEditBudgetSheet(context, existing: b),
                      onDelete: () => _confirmDelete(context, b),
                    ),
                  ),
                ] else
                  _EmptyBudgetsView(
                    onAdd: () => _showAddEditBudgetSheet(context),
                  ),
              ],
            ),
    );
  }

  Future<void> _showAddEditBudgetSheet(BuildContext context, {BudgetModel? existing}) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    String selectedCategory = existing?.category ?? AppCategories.expenseCategories.first.name;

    // Calcular cuánto se gastó en esta categoría el mes anterior para referencia
    final financeProvider = context.read<FinanceProvider>();
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevMonthSpent = financeProvider
        .transactionsForMonth(prevMonth)
        .where((t) => t.type == TransactionType.expense && t.category == selectedCategory)
        .fold(0.0, (s, t) => s + t.amount);

    final currency = context.read<CurrencyProvider>().currency;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        existing != null ? 'Editar Presupuesto' : 'Nuevo Presupuesto Mensual',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fija un límite mensual de gasto para mantener tus finanzas bajo control.',
                        style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),

                      // Entrada de Monto Límite
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autofocus: true,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: '${currency.symbol} ',
                          labelText: 'Límite de gasto mensual',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calculate_rounded, color: Color(0xFF6366F1)),
                            tooltip: 'Calculadora integrada',
                            onPressed: () async {
                              final current = double.tryParse(amountController.text.replaceAll(',', '.'));
                              final calc = await FinancialCalculatorSheet.show(
                                context,
                                initialValue: current,
                                title: 'Calcular Presupuesto',
                              );
                              if (calc != null) {
                                setModalState(() {
                                  amountController.text = CalculatorEvaluator.formatResult(calc);
                                });
                              }
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa un límite';
                          final parsed = double.tryParse(value.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Selector de Categoría
                      Text('Categoría', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppCategories.expenseCategories.map((c) {
                          final isSelected = c.name == selectedCategory;
                          return ChoiceChip(
                            selected: isSelected,
                            label: Text(c.name),
                            avatar: Icon(c.icon, size: 18, color: isSelected ? null : c.color),
                            onSelected: existing != null
                                ? null // No cambiar categoría si se está editando
                                : (_) {
                                    setModalState(() => selectedCategory = c.name);
                                  },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Tarjeta de sugerencia / gasto histórico del mes anterior
                      if (prevMonthSpent > 0)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'El mes pasado gastaste ${Formatters.currency(prevMonthSpent)} en esta categoría.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final amount = double.parse(amountController.text.replaceAll(',', '.'));

                            final budgetProvider = context.read<BudgetProvider>();
                            final financeProvider = context.read<FinanceProvider>();

                            if (existing != null) {
                              await budgetProvider.updateBudget(existing.copyWith(amount: amount));
                            } else {
                              await budgetProvider.addBudget(category: selectedCategory, amount: amount);
                            }

                            // Actualizar cálculo con transacciones actuales
                            budgetProvider.updateSpending(financeProvider.transactions);

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(existing != null ? 'Guardar Cambios' : 'Establecer Presupuesto'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, BudgetModel budget) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar presupuesto de ${budget.category}?'),
        content: const Text('Dejarás de monitorear el límite de gasto para esta categoría.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<BudgetProvider>().deleteBudget(budget.id);
    }
  }
}

class _GlobalBudgetSummaryCard extends StatelessWidget {
  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;
  final double overallProgress;
  final int overbudgetCount;
  final int nearLimitCount;

  const _GlobalBudgetSummaryCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
    required this.overallProgress,
    required this.overbudgetCount,
    required this.nearLimitCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOver = totalSpent > totalBudget;
    final progressColor = isOver
        ? const Color(0xFFF43F5E)
        : (overallProgress >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Presupuesto consolidado',
                style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(overallProgress * 100).toStringAsFixed(0)}% consumido',
                  style: TextStyle(fontWeight: FontWeight.bold, color: progressColor, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Formatters.currency(totalSpent),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: -0.5),
              ),
              const SizedBox(width: 6),
              Text(
                'de ${Formatters.currency(totalBudget)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOver ? 'Sobregiro total' : 'Disponible restante',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
              Text(
                Formatters.currency(isOver ? (totalSpent - totalBudget) : totalRemaining),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isOver ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          if (overbudgetCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF43F5E)),
                  const SizedBox(width: 6),
                  Text(
                    '$overbudgetCount ${overbudgetCount == 1 ? 'categoría superó' : 'categorías superaron'} el límite',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF43F5E)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final DateTime selectedMonth;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.selectedMonth,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = AppCategories.findByName(budget.category, TransactionType.expense);

    final isOver = budget.isOverbudget;
    final isNear = budget.isNearLimit;
    final Color progressColor = isOver
        ? const Color(0xFFF43F5E)
        : (isNear ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    final daily = budget.dailyAllowance(selectedMonth);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C2C) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.currency(budget.spent)} de ${Formatters.currency(budget.amount)}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar límite')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar', style: TextStyle(color: colorScheme.error)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budget.clampedProgress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOver
                      ? '⚠️ Sobregiro: ${Formatters.currency(budget.overspent)}'
                      : 'Resta: ${Formatters.currency(budget.remaining)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isOver ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                  ),
                ),
                Text(
                  '${(budget.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: progressColor),
                ),
              ],
            ),
            if (!isOver && budget.remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Pauta sugerida: ~${Formatters.currency(daily)} / día restante',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      );
    }
  }

class _EmptyBudgetsView extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyBudgetsView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(Icons.pie_chart_outline, size: 40, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(
            'Controla tus gastos con Presupuestos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Fija límites para tus categorías de gasto (ej. Alimentación, Transporte) y recibe alertas antes de excederte.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Crear primer presupuesto'),
          ),
        ],
      ),
    );
  }
}
