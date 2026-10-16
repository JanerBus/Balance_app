import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/account_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/security_provider.dart';
import '../../utils/formatters.dart';
import '../budgets/budgets_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../recurring/recurring_screen.dart';
import '../reports/reports_screen.dart';
import '../security/security_settings_screen.dart';
import '../settings/bank_sync_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  static String accountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Efectivo';
      case AccountType.bank:
        return 'Cuenta Bancaria';
      case AccountType.creditCard:
        return 'Tarjeta de Crédito';
      case AccountType.savings:
        return 'Ahorros / Cajita';
      case AccountType.investment:
        return 'Inversión';
      case AccountType.other:
        return 'Otra';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final isPrivacyMode = context.watch<SecurityProvider?>()?.isPrivacyModeEnabled ?? false;
    final accounts = accountProvider.accounts;
    final totalBalance = accountProvider.totalBalance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billetera y Gestión'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                showAddEditAccountDialog(context);
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Nueva cuenta',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: accountProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 115),
              children: [
                // Tarjeta de Patrimonio Consolidado (Estilo Titanium Minimalista)
                Container(
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF1E2638), Color(0xFF111827), Color(0xFF0F172A)]
                          : const [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'PATRIMONIO CONSOLIDADO',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${accounts.length} ${accounts.length == 1 ? 'billetera' : 'billeteras'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Formatters.currency(totalBalance, null, isPrivacyMode),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tus cuentas y tarjetas',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => showAddEditAccountDialog(context),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('Agregar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...accounts.map(
                  (acc) => _AccountCard(
                    account: acc,
                    isPrivacyMode: isPrivacyMode,
                    onEdit: () => showAddEditAccountDialog(context, existing: acc),
                    onDelete: () => _confirmDelete(context, acc),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Herramientas y Automatización',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 10),
                _buildManagementTile(
                  context: context,
                  icon: Icons.notifications_active_outlined,
                  color: const Color(0xFF820AD1),
                  title: 'Sincronización Bancaria',
                  subtitle: 'Detecta compras de Nu, Bancolombia, Nequi y más',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankSyncScreen())),
                ),
                _buildManagementTile(
                  context: context,
                  icon: Icons.pie_chart_outline_rounded,
                  color: const Color(0xFF6366F1),
                  title: 'Presupuestos Mensuales',
                  subtitle: 'Límites de gasto por categoría y alertas',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen())),
                ),
                _buildManagementTile(
                  context: context,
                  icon: Icons.savings_outlined,
                  color: const Color(0xFF8B5CF6),
                  title: 'Metas de Ahorro',
                  subtitle: 'Alcancías virtuales y progreso de objetivos',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                ),
                _buildManagementTile(
                  context: context,
                  icon: Icons.handshake_outlined,
                  color: const Color(0xFFF59E0B),
                  title: 'Deudas y Préstamos',
                  subtitle: 'Control de dinero que debes o te deben',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
                ),
                _buildManagementTile(
                  context: context,
                  icon: Icons.event_repeat_rounded,
                  color: const Color(0xFF06B6D4),
                  title: 'Suscripciones y Pagos Fijos',
                  subtitle: 'Recordatorios y cargos automáticos recurrentes',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringScreen())),
                ),
                _buildManagementTile(
                  context: context,
                  icon: Icons.picture_as_pdf_outlined,
                  color: const Color(0xFFF43F5E),
                  title: 'Reportes y Extractos',
                  subtitle: 'Exporta tu historial en PDF o CSV para Excel',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
                ),
                _buildManagementTile(
                  context: context,
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF10B981),
                  title: 'Seguridad y Privacidad',
                  subtitle: 'Bloqueo con PIN, biometría y modo oculto',
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen())),
                ),
              ],
            ),
    );
  }

  Widget _buildManagementTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131824) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> showAddEditAccountDialog(BuildContext context, {AccountModel? existing}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: existing?.name ?? '');
    final initialBalanceController = TextEditingController(
      text: existing != null ? existing.initialBalance.toStringAsFixed(0) : '0',
    );
    final creditLimitController = TextEditingController(
      text: existing?.creditLimit != null ? existing!.creditLimit!.toStringAsFixed(0) : '',
    );
    AccountType selectedType = existing?.type ?? AccountType.bank;
    String selectedIcon = existing?.icon ?? 'account_balance';
    int selectedColor = existing?.color ?? 0xFF820AD1;
    bool includeInTotal = existing?.includeInTotal ?? true;
    int? closingDay = existing?.closingDay;
    int? dueDay = existing?.dueDay;

    final colorOptions = [
      0xFF820AD1, // Nu Purple
      0xFF00695C, // Teal
      0xFF1976D2, // Blue
      0xFF2E7D32, // Green
      0xFFC2185B, // Nequi Pink
      0xFFE65100, // Orange
      0xFF1E293B, // Bancolombia Slate
      0xFFD32F2F, // Daviplata Red
    ];

    final iconOptions = [
      {'key': 'payments', 'icon': Icons.payments, 'label': 'Efectivo'},
      {'key': 'account_balance', 'icon': Icons.account_balance, 'label': 'Banco'},
      {'key': 'credit_card', 'icon': Icons.credit_card, 'label': 'Tarjeta'},
      {'key': 'savings', 'icon': Icons.savings, 'label': 'Ahorros'},
      {'key': 'trending_up', 'icon': Icons.trending_up, 'label': 'Inversión'},
      {'key': 'wallet', 'icon': Icons.account_balance_wallet, 'label': 'Billetera'},
    ];

    final presets = [
      {'name': 'Nu Tarjeta', 'type': AccountType.creditCard, 'icon': 'credit_card', 'color': 0xFF820AD1, 'creditLimit': 3000000.0, 'closingDay': 15, 'dueDay': 5},
      {'name': 'Nu Débito', 'type': AccountType.bank, 'icon': 'credit_card', 'color': 0xFF820AD1},
      {'name': 'Bancolombia', 'type': AccountType.bank, 'icon': 'account_balance', 'color': 0xFF1E293B},
      {'name': 'Nequi', 'type': AccountType.bank, 'icon': 'wallet', 'color': 0xFFC2185B},
      {'name': 'Daviplata', 'type': AccountType.bank, 'icon': 'wallet', 'color': 0xFFD32F2F},
      {'name': 'Efectivo', 'type': AccountType.cash, 'icon': 'payments', 'color': 0xFF2E7D32},
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
                        existing != null ? 'Editar Cuenta' : 'Nueva Cuenta',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (existing == null) ...[
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: presets.map((preset) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ActionChip(
                                  avatar: CircleAvatar(
                                    backgroundColor: Color(preset['color'] as int),
                                    radius: 8,
                                  ),
                                  label: Text(
                                    preset['name'] as String,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setModalState(() {
                                      nameController.text = preset['name'] as String;
                                      selectedType = preset['type'] as AccountType;
                                      selectedIcon = preset['icon'] as String;
                                      selectedColor = preset['color'] as int;
                                      if (preset['creditLimit'] != null) {
                                        creditLimitController.text = (preset['creditLimit'] as double).toStringAsFixed(0);
                                      }
                                      closingDay = preset['closingDay'] as int?;
                                      dueDay = preset['dueDay'] as int?;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la cuenta',
                          hintText: 'Ej. Nu, Bancolombia, Nequi, Efectivo...',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                      ),
                      const SizedBox(height: 16),
                      if (existing == null) ...[
                        TextFormField(
                          controller: initialBalanceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Saldo inicial',
                            prefixText: '\$ ',
                            hintText: '0',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            final parsed = double.tryParse(v.replaceAll(',', '.'));
                            if (parsed == null) return 'Monto inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Tipo de cuenta', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<AccountType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                        items: AccountType.values.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(accountTypeLabel(t)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              selectedType = val;
                              if (val == AccountType.creditCard) {
                                selectedIcon = 'credit_card';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (selectedType == AccountType.creditCard) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF6366F1)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Configuración de Tarjeta de Crédito',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: creditLimitController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Cupo / Límite total de crédito',
                                  prefixText: '\$ ',
                                  hintText: 'Ej. 5000000',
                                  prefixIcon: Icon(Icons.speed_rounded),
                                ),
                                validator: (v) {
                                  if (selectedType == AccountType.creditCard && (v == null || v.trim().isEmpty)) {
                                    return 'Ingresa el cupo total de la tarjeta';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: closingDay,
                                      decoration: const InputDecoration(
                                        labelText: 'Día de corte',
                                        prefixIcon: Icon(Icons.event_outlined),
                                      ),
                                      items: List.generate(31, (i) => i + 1).map((d) {
                                        return DropdownMenuItem(value: d, child: Text('Día $d'));
                                      }).toList(),
                                      onChanged: (val) => setModalState(() => closingDay = val),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: dueDay,
                                      decoration: const InputDecoration(
                                        labelText: 'Día de pago',
                                        prefixIcon: Icon(Icons.calendar_today_outlined),
                                      ),
                                      items: List.generate(31, (i) => i + 1).map((d) {
                                        return DropdownMenuItem(value: d, child: Text('Día $d'));
                                      }).toList(),
                                      onChanged: (val) => setModalState(() => dueDay = val),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text('Icono', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: iconOptions.map((opt) {
                          final isSelected = selectedIcon == opt['key'];
                          return InkWell(
                            onTap: () => setModalState(() => selectedIcon = opt['key'] as String),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(selectedColor).withValues(alpha: 0.2)
                                    : Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                border: isSelected ? Border.all(color: Color(selectedColor), width: 2) : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                opt['icon'] as IconData,
                                color: isSelected ? Color(selectedColor) : Theme.of(ctx).colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text('Color distintivo', style: Theme.of(ctx).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: colorOptions.map((c) {
                          final isSelected = selectedColor == c;
                          return InkWell(
                            onTap: () => setModalState(() => selectedColor = c),
                            customBorder: const CircleBorder(),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(c),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: includeInTotal,
                        onChanged: (v) => setModalState(() => includeInTotal = v),
                        title: const Text('Incluir en balance consolidado', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Determina si suma al total patrimonial en el inicio', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final provider = context.read<AccountProvider>();

                            final isCredit = selectedType == AccountType.creditCard;
                            final creditLimit = isCredit
                                ? double.tryParse(creditLimitController.text.replaceAll(',', '.'))
                                : null;

                            if (existing != null) {
                              await provider.updateAccount(
                                existing.copyWith(
                                  name: nameController.text.trim(),
                                  type: selectedType,
                                  color: selectedColor,
                                  icon: selectedIcon,
                                  includeInTotal: includeInTotal,
                                  creditLimit: creditLimit,
                                  closingDay: isCredit ? closingDay : null,
                                  dueDay: isCredit ? dueDay : null,
                                ),
                              );
                            } else {
                              final initialBalance = double.tryParse(
                                    initialBalanceController.text.replaceAll(',', '.'),
                                  ) ??
                                  0.0;
                              await provider.addAccount(
                                name: nameController.text.trim(),
                                type: selectedType,
                                initialBalance: initialBalance,
                                color: selectedColor,
                                icon: selectedIcon,
                                includeInTotal: includeInTotal,
                                creditLimit: creditLimit,
                                closingDay: isCredit ? closingDay : null,
                                dueDay: isCredit ? dueDay : null,
                              );
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(existing != null ? 'Guardar Cambios' : 'Crear Cuenta'),
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

  Future<void> _confirmDelete(BuildContext context, AccountModel account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar cuenta "${account.name}"?'),
        content: const Text(
          'Las transacciones asociadas a esta cuenta se reasignarán automáticamente a tu cuenta en Efectivo principal.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final success = await context.read<AccountProvider>().deleteAccount(account.id);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes eliminar la única cuenta que tienes.')),
        );
      }
    }
  }
}

class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final bool isPrivacyMode;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.isPrivacyMode,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = account.colorValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(account.iconData, color: color, size: 23),
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
                            account.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!account.includeInTotal)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(Icons.visibility_off_outlined, size: 14, color: colorScheme.outline),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      account.isCreditCard
                          ? [
                              account.typeLabel,
                              if (account.closingDay != null) 'Corte: día ${account.closingDay}',
                              if (account.dueDay != null) 'Paga: día ${account.dueDay}',
                            ].join(' · ')
                          : account.typeLabel,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    account.isCreditCard
                        ? (account.currentDebt > 0
                            ? 'Deuda: ${Formatters.currency(account.currentDebt, null, isPrivacyMode)}'
                            : 'Al día')
                        : Formatters.currency(account.currentBalance, null, isPrivacyMode),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: -0.3,
                      color: account.isCreditCard
                          ? (account.currentDebt > 0 ? const Color(0xFFF43F5E) : const Color(0xFF10B981))
                          : (account.currentBalance < 0 ? const Color(0xFFF43F5E) : colorScheme.onSurface),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Editar',
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                        tooltip: 'Eliminar',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (account.isCreditCard && account.creditLimit != null && account.creditLimit! > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: account.creditUtilization,
                minHeight: 4,
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  account.creditUtilizationPercent > 70
                      ? const Color(0xFFF43F5E)
                      : account.creditUtilizationPercent > 30
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uso: ${account.creditUtilizationPercent.toStringAsFixed(0)}% de ${Formatters.currency(account.creditLimit!, null, isPrivacyMode)}',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
                Text(
                  'Disp: ${Formatters.currency(account.availableCredit, null, isPrivacyMode)}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
