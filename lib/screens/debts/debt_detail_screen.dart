import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/debt_model.dart';
import '../../models/debt_payment_model.dart';
import '../../models/transaction_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/finance_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/financial_calculator_sheet.dart';
import '../../utils/calculator_evaluator.dart';

class DebtDetailScreen extends StatefulWidget {
  final DebtModel debt;

  const DebtDetailScreen({super.key, required this.debt});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final debtProvider = context.watch<DebtProvider>();
    // Obtener la instancia reactiva actualizada de la deuda
    final debt = debtProvider.debts.firstWhere(
      (d) => d.id == widget.debt.id,
      orElse: () => widget.debt,
    );

    final isIncome = debt.type == DebtType.theyOweMe;
    final color = isIncome ? const Color(0xFF2E7D32) : colorScheme.error;

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.personName),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir estado de cuenta',
            onPressed: () => _shareDebtReminder(context, debt),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar deuda',
            onPressed: () => _confirmDelete(context, debtProvider, debt.id),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              if (!debt.isFullySettled)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showAddPaymentSheet(context, debt),
                    icon: const Icon(Icons.add),
                    label: const Text('Registrar abono'),
                  ),
                ),
              if (!debt.isFullySettled) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (debt.isFullySettled) {
                      await debtProvider.markAsUnpaid(debt);
                    } else {
                      await debtProvider.markAsPaid(debt);
                    }
                  },
                  icon: Icon(debt.isFullySettled ? Icons.undo : Icons.check_circle_outline),
                  label: Text(debt.isFullySettled ? 'Reabrir deuda' : 'Saldar total'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Tarjeta principal de saldo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isIncome ? 'Te debe' : 'Le debes',
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (debt.isFullySettled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Saldada',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  Formatters.currency(debt.isFullySettled ? 0 : debt.remainingAmount),
                  style: TextStyle(color: color, fontSize: 34, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  debt.isFullySettled
                      ? 'Deuda liquidada por completo'
                      : 'Saldo pendiente por pagar',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                // Barra de progreso
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: debt.progress,
                    minHeight: 10,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${Formatters.currency(debt.amount)}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      'Abonado: ${Formatters.currency(debt.totalPaid)} (${(debt.progress * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Información básica
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha de registro',
                    value: Formatters.shortDate(debt.createdDate),
                  ),
                  const Divider(height: 16),
                  _DetailRow(
                    icon: Icons.event_outlined,
                    label: 'Fecha límite',
                    value: debt.dueDate != null
                        ? '${Formatters.shortDate(debt.dueDate!)}${_getDueBadgeText(debt)}'
                        : 'Sin fecha límite definida',
                    valueColor: debt.isOverdue ? colorScheme.error : null,
                  ),
                  if (debt.description?.isNotEmpty == true) ...[
                    const Divider(height: 16),
                    _DetailRow(
                      icon: Icons.notes_outlined,
                      label: 'Motivo o detalle',
                      value: debt.description!,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sección de Historial de Abonos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Historial de abonos (${debt.payments.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (!debt.isFullySettled)
                TextButton.icon(
                  onPressed: () => _showAddPaymentSheet(context, debt),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Abonar'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (debt.payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.payments_outlined, size: 40, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'No hay abonos registrados',
                    style: TextStyle(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Registra abonos parciales conforme recibas o realices pagos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ...debt.payments.map((payment) => _PaymentTile(
                  payment: payment,
                  onDelete: () => _confirmDeletePayment(context, debtProvider, payment, debt.id),
                )),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  String _getDueBadgeText(DebtModel debt) {
    if (debt.isFullySettled) return '';
    if (debt.isOverdue) {
      final days = debt.daysUntilDue != null ? debt.daysUntilDue!.abs() : 0;
      return ' (Venció hace $days días)';
    }
    if (debt.daysUntilDue != null) {
      if (debt.daysUntilDue == 0) return ' (¡Vence hoy!)';
      if (debt.daysUntilDue == 1) return ' (Vence mañana)';
      return ' (En ${debt.daysUntilDue} días)';
    }
    return '';
  }

  Future<void> _showAddPaymentSheet(BuildContext context, DebtModel debt) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(
      text: debt.remainingAmount > 0 ? debt.remainingAmount.toStringAsFixed(0) : '',
    );
    final noteController = TextEditingController();
    DateTime paymentDate = DateTime.now();
    bool syncToTransactions = true;
    final isIncome = debt.type == DebtType.theyOweMe;
    final accentColor = isIncome ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151C2C) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Header con título y persona
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            debt.personName.isNotEmpty ? debt.personName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isIncome ? 'Abono de ${debt.personName}' : 'Abonar a ${debt.personName}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Saldo pendiente: ${Formatters.currency(debt.remainingAmount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Hero amount input container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2738) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  autofocus: true,
                                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                  decoration: const InputDecoration(
                                    prefixText: '\$ ',
                                    prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                                    hintText: '0',
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
                                    if (parsed > debt.remainingAmount * 1.5) {
                                      return 'El monto excede considerablemente el saldo';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.calculate_rounded, color: Color(0xFF6366F1), size: 24),
                                tooltip: 'Calculadora integrada',
                                onPressed: () async {
                                  HapticFeedback.selectionClick();
                                  final current = double.tryParse(amountController.text.replaceAll(',', '.'));
                                  final calc = await FinancialCalculatorSheet.show(
                                    ctx,
                                    initialValue: current,
                                    title: 'Calcular Abono',
                                  );
                                  if (calc != null) {
                                    setModalState(() {
                                      amountController.text = CalculatorEvaluator.formatResult(calc);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Chips rápidos de porcentaje del saldo
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildQuickPercentPill(
                                  label: '25%',
                                  amount: debt.remainingAmount * 0.25,
                                  controller: amountController,
                                  setModalState: setModalState,
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 6),
                                _buildQuickPercentPill(
                                  label: '50%',
                                  amount: debt.remainingAmount * 0.5,
                                  controller: amountController,
                                  setModalState: setModalState,
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 6),
                                _buildQuickPercentPill(
                                  label: 'Total (100%)',
                                  amount: debt.remainingAmount,
                                  controller: amountController,
                                  setModalState: setModalState,
                                  isDark: isDark,
                                  highlight: true,
                                  highlightColor: accentColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextFormField(
                      controller: noteController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        labelText: 'Nota (opcional)',
                        hintText: 'Ej. Primer cuota, Transferencia Nequi...',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2738) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        value: syncToTransactions,
                        onChanged: (val) => setModalState(() => syncToTransactions = val),
                        title: const Text('Registrar en balance general', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          debt.type == DebtType.theyOweMe
                              ? 'Se añadirá automáticamente como Ingreso (+)'
                              : 'Se añadirá automáticamente como Gasto (-)',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 3,
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          HapticFeedback.mediumImpact();
                          final amount = double.parse(amountController.text.replaceAll(',', '.'));
                          final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();

                          // 1. Registrar abono en deuda
                          await context.read<DebtProvider>().addPayment(
                                debtId: debt.id,
                                amount: amount,
                                date: paymentDate,
                                note: note,
                              );

                          // 2. Opcionalmente sincronizar con movimientos
                          if (syncToTransactions && context.mounted) {
                            final isIncome = debt.type == DebtType.theyOweMe;
                            await context.read<FinanceProvider>().addTransaction(
                                  title: isIncome
                                      ? 'Abono de ${debt.personName}'
                                      : 'Pago a ${debt.personName}',
                                  amount: amount,
                                  type: isIncome ? TransactionType.income : TransactionType.expense,
                                  category: 'Otros',
                                  date: paymentDate,
                                  note: 'Abono de deuda: ${debt.description ?? debt.personName}',
                                );
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Registrar Abono', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickPercentPill({
    required String label,
    required double amount,
    required TextEditingController controller,
    required StateSetter setModalState,
    required bool isDark,
    bool highlight = false,
    Color? highlightColor,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setModalState(() {
          controller.text = amount.toStringAsFixed(0);
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: highlight && highlightColor != null
              ? highlightColor.withValues(alpha: 0.16)
              : (isDark ? const Color(0xFF151C2C) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight && highlightColor != null
                ? highlightColor
                : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: highlight && highlightColor != null
                ? highlightColor
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  void _shareDebtReminder(BuildContext context, DebtModel debt) {
    final isIncome = debt.type == DebtType.theyOweMe;
    final message = isIncome
        ? 'Hola ${debt.personName}, te comparto el estado de tu cuenta pendiente: Saldo de ${Formatters.currency(debt.remainingAmount)}${debt.dueDate != null ? ' con fecha límite ${Formatters.shortDate(debt.dueDate!)}' : ''}. ¡Muchas gracias!'
        : 'Hola ${debt.personName}, te confirmo que tengo pendiente contigo un saldo de ${Formatters.currency(debt.remainingAmount)}.';

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Texto de recordatorio copiado al portapapeles.'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DebtProvider provider, String debtId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar deuda?'),
        content: const Text('Se eliminará la deuda y todo su historial de abonos permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteDebt(debtId);
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmDeletePayment(
    BuildContext context,
    DebtProvider provider,
    DebtPaymentModel payment,
    String debtId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar abono?'),
        content: Text('Se eliminará el abono de ${Formatters.currency(payment.amount)} y se recalculará el saldo pendiente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deletePayment(paymentId: payment.id, debtId: debtId);
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final DebtPaymentModel payment;
  final VoidCallback onDelete;

  const _PaymentTile({required this.payment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(Icons.arrow_downward, size: 16, color: colorScheme.onSecondaryContainer),
        ),
        title: Text(
          Formatters.currency(payment.amount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${Formatters.shortDate(payment.date)}${payment.note?.isNotEmpty == true ? ' · ${payment.note}' : ''}',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
          onPressed: onDelete,
          tooltip: 'Eliminar abono',
        ),
      ),
    );
  }
}
