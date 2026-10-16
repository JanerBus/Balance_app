import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/recurring_model.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import '../../models/account_model.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/currency_provider.dart';
import '../../utils/formatters.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  TransactionType _selectedType = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final recurringProvider = context.watch<RecurringProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    final items = _selectedType == TransactionType.expense
        ? recurringProvider.expenses
        : recurringProvider.incomes;

    final monthlyTotal = _selectedType == TransactionType.expense
        ? recurringProvider.monthlyExpenseCommitment
        : recurringProvider.monthlyIncomeExpected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripciones & Frecuentes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(context, accountProvider.accounts),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo recurrente'),
      ),
      body: recurringProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                // Segmented button: Gastos / Suscripciones vs Ingresos Fijos
                Center(
                  child: SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Suscripciones & Gastos'),
                        icon: Icon(Icons.subscriptions_outlined),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Ingresos fijos'),
                        icon: Icon(Icons.payments_outlined),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (val) => setState(() => _selectedType = val.first),
                  ),
                ),
                const SizedBox(height: 16),

                // Tarjeta de Compromiso Mensual Proyectado
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _selectedType == TransactionType.expense
                          ? [colorScheme.primary, colorScheme.primaryContainer]
                          : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedType == TransactionType.expense
                            ? 'Compromiso mensual estimado'
                            : 'Ingreso mensual proyectado',
                        style: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Formatters.currency(monthlyTotal),
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${items.where((i) => i.isActive).length} pagos activos programados',
                        style: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Lista de elementos recurrentes
                Text(
                  _selectedType == TransactionType.expense ? 'Tus suscripciones' : 'Tus ingresos fijos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                if (items.isEmpty)
                  _EmptyRecurringView(
                    isExpense: _selectedType == TransactionType.expense,
                    onAdd: () => _showAddEditSheet(context, accountProvider.accounts),
                  )
                else
                  ...items.map(
                    (item) => _RecurringCard(
                      item: item,
                      accounts: accountProvider.accounts,
                      onToggle: () => recurringProvider.toggleActive(item),
                      onExecuteNow: () => _executeNow(context, item),
                      onSkipNext: () => recurringProvider.skipNext(item),
                      onEdit: () => _showAddEditSheet(context, accountProvider.accounts, existing: item),
                      onDelete: () => _confirmDelete(context, item),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _executeNow(BuildContext context, RecurringModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Registrar "${item.title}" ahora?'),
        content: Text(
          'Se agregará un movimiento de ${Formatters.currency(item.amount)} en tu balance y la próxima fecha se reprogramará para el siguiente ciclo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar ahora')),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final financeProvider = context.read<FinanceProvider>();
      await context.read<RecurringProvider>().executeNow(item, financeProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pago de "${item.title}" registrado correctamente.')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, RecurringModel item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar "${item.title}"?'),
        content: const Text('Ya no se generarán pagos periódicos automáticos para este servicio.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await context.read<RecurringProvider>().deleteRecurring(item.id);
    }
  }

  Future<void> _showAddEditSheet(
    BuildContext context,
    List<AccountModel> accounts, {
    RecurringModel? existing,
  }) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    final noteController = TextEditingController(text: existing?.note ?? '');

    TransactionType type = existing?.type ?? _selectedType;
    String category = existing?.category ??
        (type == TransactionType.expense ? 'Suscripciones' : 'Salario');
    String accountId = existing?.accountId ?? (accounts.isNotEmpty ? accounts.first.id : 'default-cash');
    RecurringFrequency frequency = existing?.frequency ?? RecurringFrequency.monthly;
    DateTime nextDueDate = existing?.nextDueDate ?? DateTime.now();
    bool autoApply = existing?.autoApply ?? true;

    final currency = context.read<CurrencyProvider>().currency;

    // Servicios sugeridos predefinidos
    final presets = [
      {'title': 'Netflix', 'cat': 'Suscripciones', 'icon': Icons.movie},
      {'title': 'Spotify', 'cat': 'Suscripciones', 'icon': Icons.music_note},
      {'title': 'Disney+', 'cat': 'Suscripciones', 'icon': Icons.tv},
      {'title': 'Gimnasio', 'cat': 'Salud', 'icon': Icons.fitness_center},
      {'title': 'Internet Wi-Fi', 'cat': 'Servicios', 'icon': Icons.wifi},
      {'title': 'Alquiler', 'cat': 'Vivienda', 'icon': Icons.home},
      {'title': 'Sueldo / Nómina', 'cat': 'Salario', 'icon': Icons.payments},
    ];

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
                        existing != null ? 'Editar Recurrente' : 'Nuevo Pago Recurrente',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Programa cobros y suscripciones periódicas para que no olvides ningún pago.',
                        style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),

                      // Presets rápidos (solo si es nuevo)
                      if (existing == null) ...[
                        Text('Sugerencias rápidas', style: Theme.of(ctx).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: presets.map((p) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  avatar: Icon(p['icon'] as IconData, size: 16),
                                  label: Text(p['title'] as String),
                                  onPressed: () {
                                    setModalState(() {
                                      titleController.text = p['title'] as String;
                                      category = p['cat'] as String;
                                      if (p['title'] == 'Sueldo / Nómina') {
                                        type = TransactionType.income;
                                      } else {
                                        type = TransactionType.expense;
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Monto
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixText: '${currency.symbol} ',
                          labelText: 'Monto del cobro',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa un monto';
                          final parsed = double.tryParse(value.replaceAll(',', '.'));
                          if (parsed == null || parsed <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Título
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre / Servicio',
                          hintText: 'Ej. Netflix, Gimnasio SmartFit, Renta...',
                          prefixIcon: Icon(Icons.edit_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un título' : null,
                      ),
                      const SizedBox(height: 14),

                      // Frecuencia
                      Text('Frecuencia de cobro', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<RecurringFrequency>(
                        initialValue: frequency,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.repeat)),
                        items: RecurringFrequency.values.map((f) {
                          String label;
                          switch (f) {
                            case RecurringFrequency.daily:
                              label = 'Diario';
                              break;
                            case RecurringFrequency.weekly:
                              label = 'Semanal';
                              break;
                            case RecurringFrequency.biweekly:
                              label = 'Quincenal (cada 14 días)';
                              break;
                            case RecurringFrequency.monthly:
                              label = 'Mensual';
                              break;
                            case RecurringFrequency.yearly:
                              label = 'Anual';
                              break;
                          }
                          return DropdownMenuItem(value: f, child: Text(label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => frequency = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Cuenta / Billetera
                      Text('Cuenta a debitar/acreditar', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: accountId,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
                        items: accounts.map((acc) {
                          return DropdownMenuItem(
                            value: acc.id,
                            child: Row(
                              children: [
                                Icon(acc.iconData, size: 16, color: acc.colorValue),
                                const SizedBox(width: 8),
                                Text(acc.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => accountId = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Fecha del próximo cobro
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Próxima fecha de cobro'),
                        subtitle: Text('${nextDueDate.day}/${nextDueDate.month}/${nextDueDate.year}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: nextDueDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setModalState(() => nextDueDate = picked);
                        },
                      ),
                      const SizedBox(height: 10),

                      // Switch de ejecución automática
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: autoApply,
                        onChanged: (v) => setModalState(() => autoApply = v),
                        title: const Text('Registrar automáticamente', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Crea el movimiento en tu balance automáticamente al llegar la fecha programada', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final amount = double.parse(amountController.text.replaceAll(',', '.'));
                            final provider = context.read<RecurringProvider>();

                            if (existing != null) {
                              await provider.updateRecurring(
                                existing.copyWith(
                                  title: titleController.text.trim(),
                                  amount: amount,
                                  type: type,
                                  category: category,
                                  accountId: accountId,
                                  frequency: frequency,
                                  nextDueDate: nextDueDate,
                                  autoApply: autoApply,
                                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                ),
                              );
                            } else {
                              await provider.addRecurring(
                                title: titleController.text.trim(),
                                amount: amount,
                                type: type,
                                category: category,
                                accountId: accountId,
                                frequency: frequency,
                                startDate: DateTime.now(),
                                nextDueDate: nextDueDate,
                                autoApply: autoApply,
                                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(existing != null ? 'Guardar Cambios' : 'Guardar Recurrente'),
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
}

class _RecurringCard extends StatelessWidget {
  final RecurringModel item;
  final List<AccountModel> accounts;
  final VoidCallback onToggle;
  final VoidCallback onExecuteNow;
  final VoidCallback onSkipNext;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecurringCard({
    required this.item,
    required this.accounts,
    required this.onToggle,
    required this.onExecuteNow,
    required this.onSkipNext,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final category = AppCategories.findByName(item.category, item.type);
    final account = accounts.firstWhere((a) => a.id == item.accountId, orElse: () => accounts.first);
    final isIncome = item.type == TransactionType.income;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: category.color.withValues(alpha: 0.15),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: item.isActive ? null : TextDecoration.lineThrough,
                          color: item.isActive ? null : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${account.name} · ${item.frequencyLabel}',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'} ${Formatters.currency(item.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isIncome ? const Color(0xFF2E7D32) : colorScheme.error,
                      ),
                    ),
                    Switch(
                      value: item.isActive,
                      onChanged: (_) => onToggle(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDueBadge(context, item),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onExecuteNow,
                      icon: const Icon(Icons.play_arrow_outlined, size: 16),
                      label: const Text('Cobrar ya', style: TextStyle(fontSize: 12)),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (val) {
                        if (val == 'edit') onEdit();
                        if (val == 'skip') onSkipNext();
                        if (val == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                        const PopupMenuItem(value: 'skip', child: Text('Saltar este ciclo')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar', style: TextStyle(color: colorScheme.error)),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueBadge(BuildContext context, RecurringModel item) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = item.daysUntilNextDue;

    Color badgeColor;
    String text;

    if (!item.isActive) {
      badgeColor = colorScheme.outline;
      text = 'Pausada';
    } else if (days < 0) {
      badgeColor = colorScheme.error;
      text = 'Vencido hace ${days.abs()} días';
    } else if (days == 0) {
      badgeColor = Colors.orange;
      text = '¡Cobro hoy!';
    } else if (days == 1) {
      badgeColor = Colors.orange;
      text = 'Cobro mañana';
    } else if (days <= 3) {
      badgeColor = Colors.orange;
      text = 'En $days días';
    } else {
      badgeColor = colorScheme.onSurfaceVariant;
      text = 'Próximo: ${Formatters.shortDate(item.nextDueDate)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
      ),
    );
  }
}

class _EmptyRecurringView extends StatelessWidget {
  final bool isExpense;
  final VoidCallback onAdd;

  const _EmptyRecurringView({required this.isExpense, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              isExpense ? Icons.subscriptions_outlined : Icons.payments_outlined,
              size: 36,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isExpense ? 'No tienes suscripciones registradas' : 'No tienes ingresos fijos programados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isExpense
                ? 'Agrega tus suscripciones y gastos periódicos (Netflix, Gimnasio, Renta) para automatizar cobros y predecir tu gasto mensual.'
                : 'Programa tus sueldos o rentas fijas para que se agreguen automáticamente a tu balance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(isExpense ? 'Agregar suscripción' : 'Agregar ingreso fijo'),
          ),
        ],
      ),
    );
  }
}
