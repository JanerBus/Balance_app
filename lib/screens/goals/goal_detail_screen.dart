import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/goal_model.dart';
import '../../models/goal_transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/goal_provider.dart';
import '../../utils/calculator_evaluator.dart';
import '../../utils/formatters.dart';
import '../../widgets/financial_calculator_sheet.dart';
import 'add_edit_goal_screen.dart';

class GoalDetailScreen extends StatelessWidget {
  final String goalId;

  const GoalDetailScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context) {
    final goalProvider = context.watch<GoalProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final goal = goalProvider.goals.where((g) => g.id == goalId).firstOrNull;

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meta no encontrada')),
        body: const Center(child: Text('Esta meta ha sido eliminada.')),
      );
    }

    final color = goal.colorValue;

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar meta',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditGoalScreen(existingGoal: goal),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Eliminar meta',
            onPressed: () => _confirmDelete(context, goalProvider, goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Hero Card de Progreso Circular
          _buildHeroProgressCard(context, goal, color, colorScheme, isDark),
          const SizedBox(height: 20),

          // Botones de Acción (Abonar y Retirar)
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showTransactionSheet(
                    context,
                    goal: goal,
                    isDeposit: true,
                    goalProvider: goalProvider,
                    accountProvider: accountProvider,
                    financeProvider: financeProvider,
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Abonar dinero', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: goal.currentAmount > 0
                      ? () => _showTransactionSheet(
                            context,
                            goal: goal,
                            isDeposit: false,
                            goalProvider: goalProvider,
                            accountProvider: accountProvider,
                            financeProvider: financeProvider,
                          )
                      : null,
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                  label: const Text('Retirar', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Proyección y Salud de la Meta (si tiene fecha límite)
          if (!goal.isCompleted && goal.targetDate != null && goal.daysRemaining != null && goal.daysRemaining! > 0) ...[
            _buildProjectionCard(goal, colorScheme),
            const SizedBox(height: 24),
          ],

          // Historial de Aportes y Retiros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historial de movimientos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FutureBuilder<List<GoalTransactionModel>>(
            future: goalProvider.getTransactions(goal.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }

              final transactions = snapshot.data ?? [];
              if (transactions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history_rounded, size: 40, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      const Text('Aún no hay movimientos registrados', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Toca "Abonar dinero" para empezar a llenar tu alcancía.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: transactions.map((t) => _buildTransactionTile(t, colorScheme, accountProvider)).toList(),
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildHeroProgressCard(
    BuildContext context,
    GoalModel goal,
    Color color,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final progress = goal.progress;
    final isCompleted = goal.isCompleted || goal.currentAmount >= goal.targetAmount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Anillo Circular de Progreso
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(goal.iconData, size: 36, color: color),
                    const SizedBox(height: 2),
                    Text(
                      '${goal.progressPercentage}%',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Monto Ahorrado vs Objetivo
          Text(
            Formatters.currency(goal.currentAmount),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.8),
          ),
          const SizedBox(height: 4),
          Text(
            'de ${Formatters.currency(goal.targetAmount)} objetivo',
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          // Badges de Estado
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.celebration_rounded, size: 16, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        '¡Meta cumplida!',
                        style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Faltan ${Formatters.currency(goal.remainingAmount)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                ),
                if (goal.targetDate != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: goal.isOverdue
                          ? const Color(0xFFF43F5E).withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      goal.isOverdue
                          ? 'Vencida hace ${goal.daysRemaining!.abs()} días'
                          : '${goal.daysRemaining} días restantes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: goal.isOverdue ? const Color(0xFFF43F5E) : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ],
          ),

          if (goal.note != null && goal.note!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '"${goal.note}"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectionCard(GoalModel goal, ColorScheme colorScheme) {
    final monthly = goal.suggestedMonthlySavings;
    final weekly = goal.suggestedWeeklySavings;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights_rounded, color: Color(0xFF6366F1), size: 20),
              SizedBox(width: 8),
              Text(
                'Plan de Ahorro Recomendado',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Para alcanzar tu meta antes del ${goal.targetDate!.day}/${goal.targetDate!.month}/${goal.targetDate!.year}, debes ahorrar:',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (monthly != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Al mes', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(monthly),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              if (monthly != null && weekly != null) const SizedBox(width: 8),
              if (weekly != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('A la semana', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          Formatters.currency(weekly),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
    GoalTransactionModel t,
    ColorScheme colorScheme,
    AccountProvider accountProvider,
  ) {
    final isDeposit = t.type == GoalTransactionType.deposit;
    final linkedAccount = accountProvider.accounts.where((a) => a.id == t.accountId).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDeposit
                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 18,
              color: isDeposit ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDeposit ? 'Aporte a la alcancía' : 'Retiro de la alcancía',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (t.note != null && t.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(t.note!, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
                if (linkedAccount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Cuenta: ${linkedAccount.name}',
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isDeposit ? '+' : '-'}${Formatters.currency(t.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDeposit ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Formatters.shortDate(t.date),
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showTransactionSheet(
    BuildContext context, {
    required GoalModel goal,
    required bool isDeposit,
    required GoalProvider goalProvider,
    required AccountProvider accountProvider,
    required FinanceProvider financeProvider,
  }) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime txDate = DateTime.now();
    bool syncToAccount = true;
    String? selectedAccountId = accountProvider.accounts.firstOrNull?.id;
    final currency = context.read<CurrencyProvider>().currency;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                        isDeposit ? 'Abonar a ${goal.title}' : 'Retirar de ${goal.title}',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDeposit
                          ? 'Agrega dinero a tu alcancía para acercarte a tu meta.'
                          : 'Retira fondos de tu alcancía cuando los necesites.',
                        style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),

                      // Entrada de Monto con Calculadora
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autofocus: true,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: '${currency.symbol} ',
                          labelText: isDeposit ? 'Monto a abonar' : 'Monto a retirar',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calculate_rounded, color: Color(0xFF6366F1)),
                            tooltip: 'Calculadora integrada',
                            onPressed: () async {
                              final current = double.tryParse(amountController.text.replaceAll(',', '.'));
                              final calc = await FinancialCalculatorSheet.show(
                                context,
                                initialValue: current,
                                title: isDeposit ? 'Calcular Aporte' : 'Calcular Retiro',
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
                          if (value == null || value.isEmpty) return 'Ingresa un monto';
                          final parsed = double.tryParse(value.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) return 'Monto inválido';
                          if (!isDeposit && parsed > goal.currentAmount) {
                            return 'No puedes retirar más de lo ahorrado (${Formatters.currency(goal.currentAmount)})';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Nota
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Nota (opcional)',
                          hintText: 'Ej. Aporte quincenal, Bono extra...',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sincronización con cuenta
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: syncToAccount,
                        activeThumbColor: goal.colorValue,
                        title: Text(
                          isDeposit ? 'Descontar de una billetera' : 'Depositar en una billetera',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          isDeposit
                              ? 'Se registrará como gasto de ahorro en tu balance'
                              : 'Se registrará como ingreso de ahorro en tu balance',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onChanged: (val) => setModalState(() => syncToAccount = val),
                      ),

                      if (syncToAccount && accountProvider.accounts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: selectedAccountId,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            labelText: isDeposit ? 'Cuenta origen' : 'Cuenta destino',
                          ),
                          items: accountProvider.accounts.map((acc) {
                            return DropdownMenuItem(
                              value: acc.id,
                              child: Row(
                                children: [
                                  Icon(acc.iconData, size: 16, color: Color(acc.color)),
                                  const SizedBox(width: 8),
                                  Text(acc.name, style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedAccountId = val);
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final amount = double.parse(amountController.text.replaceAll(',', '.'));
                            final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();

                            if (isDeposit) {
                              await goalProvider.depositToGoal(
                                goalId: goal.id,
                                amount: amount,
                                accountId: syncToAccount ? selectedAccountId : null,
                                note: note,
                                date: txDate,
                                syncToAccount: syncToAccount,
                                financeProvider: financeProvider,
                              );
                            } else {
                              await goalProvider.withdrawFromGoal(
                                goalId: goal.id,
                                amount: amount,
                                accountId: syncToAccount ? selectedAccountId : null,
                                note: note,
                                date: txDate,
                                syncToAccount: syncToAccount,
                                financeProvider: financeProvider,
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: goal.colorValue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(isDeposit ? 'Confirmar Aporte' : 'Confirmar Retiro'),
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

  void _confirmDelete(BuildContext context, GoalProvider provider, GoalModel goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar meta de ahorro?'),
        content: Text('Se eliminará la meta "${goal.title}" y todo su historial de movimientos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteGoal(goal.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
