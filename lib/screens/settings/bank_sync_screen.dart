import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/bank_profile_model.dart';
import '../../models/category_model.dart';
import '../../models/parsed_bank_transaction.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/notification_sync_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/learned_rule_bottom_sheet.dart';
import '../../widgets/concept_glossary_sheet.dart';
import 'notification_settings_screen.dart';

class BankSyncScreen extends StatefulWidget {
  const BankSyncScreen({super.key});

  @override
  State<BankSyncScreen> createState() => _BankSyncScreenState();
}

class _BankSyncScreenState extends State<BankSyncScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Verificar estado de permisos al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationSyncProvider>().checkPermission();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-verificar si el usuario concedió el permiso en Ajustes de Android
      context.read<NotificationSyncProvider>().checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncProvider = context.watch<NotificationSyncProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronización Bancaria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Guía y Conceptos',
            onPressed: () {
              HapticFeedback.lightImpact();
              ConceptGlossarySheet.show(context, initialCategory: 'Motor de Reglas');
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Ajustes de Notificaciones',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Banner de Permiso de Android
          _buildPermissionBanner(context, syncProvider, colorScheme, isDark),
          const SizedBox(height: 20),

          // Ajustes Generales
          Text(
            'Configuración General',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Lectura de notificaciones', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Detecta compras y transferencias en segundo plano.'),
                  value: syncProvider.isEnabled,
                  activeThumbColor: const Color(0xFF6366F1),
                  onChanged: (val) async {
                    HapticFeedback.lightImpact();
                    await syncProvider.toggleSync(val);
                    if (val && !syncProvider.isPermissionGranted && context.mounted) {
                      _showPermissionDialog(context, syncProvider);
                    }
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('Preguntar antes de guardar', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    syncProvider.autoSave
                        ? 'Modo automático: guarda directo en la cuenta.'
                        : 'Modo seguro: te permite clasificar la categoría antes de registrar.',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                  value: !syncProvider.autoSave,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    syncProvider.toggleAutoSave(!val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Transacciones Pendientes por Confirmar
          if (syncProvider.pendingTransactions.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pendientes por confirmar (${syncProvider.pendingTransactions.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    syncProvider.clearAllPending();
                  },
                  child: const Text('Descartar todas', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...syncProvider.pendingTransactions.map(
              (tx) => _buildPendingCard(context, tx, syncProvider, accountProvider, colorScheme),
            ),
            const SizedBox(height: 24),
          ],

          // Bancos y Billeteras
          Text(
            'Bancos y Billeteras Monitoreadas',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          ...BankProfileModel.supportedBanks.map(
            (bank) => _buildBankTile(context, bank, syncProvider, accountProvider, colorScheme),
          ),
          const SizedBox(height: 24),

          // Consola de Diagnóstico en Vivo
          _buildDiagnosticLogsCard(context, syncProvider, colorScheme),
          const SizedBox(height: 24),

          // Motor de Aprendizaje Inteligente
          _buildLearnedRulesSection(context, syncProvider, accountProvider, colorScheme),
          const SizedBox(height: 24),

          // Guía de Solución de Problemas
          _buildTroubleshootingSection(context, colorScheme),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(
    BuildContext context,
    NotificationSyncProvider provider,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (provider.isPermissionGranted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detector Bancario Activo',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Balance App procesa las notificaciones de compras de forma 100% privada y local.',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final ok = await provider.rebindService();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Detector de notificaciones reconectado exitosamente.'
                                : 'Señal de reconexión enviada al sistema.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Reconectar detector', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    provider.requestPermission();
                  },
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Ajustes', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Permiso de Android Requerido',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Para que la app detecte tus movimientos de Nu, Nequi y otros bancos automáticamente, debes otorgar el permiso especial de Acceso a Notificaciones en Android.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.requestPermission();
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Conceder permiso en Ajustes'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => _showRestrictedSettingsGuide(context),
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text(
                '¿Interruptor bloqueado o gris? (Ajustes restringidos)',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankTile(
    BuildContext context,
    BankProfileModel bank,
    NotificationSyncProvider syncProvider,
    AccountProvider accountProvider,
    ColorScheme colorScheme,
  ) {
    final isEnabled = syncProvider.isBankEnabled(bank.id);
    final linkedAccountId = syncProvider.getBankAccountId(bank.id);
    final linkedAccount = accountProvider.accounts.where((a) => a.id == linkedAccountId).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? bank.primaryColor.withValues(alpha: 0.3)
              : colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bank.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(bank.icon, color: bank.primaryColor, size: 22),
        ),
        title: Text(bank.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(
          isEnabled
              ? (linkedAccount != null ? 'Cargar a: ${linkedAccount.name}' : 'Sin cuenta vinculada')
              : 'Desactivado',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: Switch(
          value: isEnabled,
          activeThumbColor: bank.primaryColor,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            syncProvider.toggleBank(bank.id, val);
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 4),
                Text(
                  'Asociar a una cuenta / billetera de Balance App:',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: linkedAccountId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Ninguna (cuenta por defecto)'),
                    ),
                    ...accountProvider.accounts.map(
                      (acc) => DropdownMenuItem<String?>(
                        value: acc.id,
                        child: Row(
                          children: [
                            Icon(acc.iconData, size: 16, color: Color(acc.color)),
                            const SizedBox(width: 8),
                            Text(acc.name, style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: isEnabled
                      ? (accId) {
                          HapticFeedback.selectionClick();
                          syncProvider.setBankAccount(bank.id, accId);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(
    BuildContext context,
    ParsedBankTransaction tx,
    NotificationSyncProvider syncProvider,
    AccountProvider accountProvider,
    ColorScheme colorScheme,
  ) {
    final isExpense = tx.type == TransactionType.expense;
    final bank = BankProfileModel.findById(tx.bankId);
    final linkedAccount = accountProvider.accounts.where((a) => a.id == tx.accountId).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (bank?.primaryColor ?? const Color(0xFF6366F1)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(bank?.icon ?? Icons.account_balance, size: 14, color: bank?.primaryColor ?? const Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tx.bankName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: bank?.primaryColor ?? const Color(0xFF6366F1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tx.category,
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${tx.timestamp.hour.toString().padLeft(2, '0')}:${tx.timestamp.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.merchantOrPayee,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (linkedAccount != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Cuenta: ${linkedAccount.name}',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${isExpense ? '-' : '+'}${Formatters.currency(tx.amount)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isExpense ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    syncProvider.dismissPending(tx.id);
                  },
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Descartar', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _confirmTransaction(context, tx, syncProvider, accountProvider),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Confirmar y Guardar', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearnedRulesSection(
    BuildContext context,
    NotificationSyncProvider syncProvider,
    AccountProvider accountProvider,
    ColorScheme colorScheme,
  ) {
    final rules = syncProvider.userRules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 18),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'Motor de Aprendizaje',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${rules.where((r) => r.isEnabled).length} activas',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                LearnedRuleBottomSheet.show(context);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16),
                  SizedBox(width: 4),
                  Text('Nueva Regla', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'Enseña a Balance a reconocer formatos de cualquier banco o entidad.',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ConceptGlossarySheet.show(context, initialCategory: 'Motor de Reglas');
              },
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                    SizedBox(width: 4),
                    Text(
                      'Conceptos',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rules.isEmpty)
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.school_outlined, size: 32, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aún no has creado reglas personalizadas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Cuando llegue una notificación no reconocida, toca "Enseñar a My Money" en la consola para entrenar al sistema, o pulsa "Nueva Regla" para añadir una entidad bancaria.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rule = rules[index];
              final account = accountProvider.accounts.where((a) => a.id == rule.defaultAccountId).firstOrNull;
              final isIncome = rule.type == TransactionType.income;
              final isTransfer = rule.type == TransactionType.transfer;
              final typeColor = isIncome
                  ? const Color(0xFF10B981)
                  : isTransfer
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFF43F5E);

              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: rule.isEnabled
                        ? typeColor.withValues(alpha: 0.25)
                        : colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isIncome ? 'Ingreso' : isTransfer ? 'Transferencia' : 'Gasto',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rule.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: rule.isEnabled ? colorScheme.onSurface : colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Switch(
                            value: rule.isEnabled,
                            activeThumbColor: typeColor,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              syncProvider.toggleLearnedRule(rule.id, val);
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            onSelected: (val) {
                              if (val == 'edit') {
                                LearnedRuleBottomSheet.show(context, existingRule: rule);
                              } else if (val == 'delete') {
                                syncProvider.deleteLearnedRule(rule.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Regla eliminada'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFF43F5E)),
                                    SizedBox(width: 8),
                                    Text('Eliminar', style: TextStyle(color: Color(0xFFF43F5E))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Entidad: ${rule.bankName}',
                              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                          if (account != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Cuenta: ${account.name}',
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ...rule.triggerKeywords.map(
                            (kw) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$kw',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _confirmTransaction(
    BuildContext context,
    ParsedBankTransaction tx,
    NotificationSyncProvider syncProvider,
    AccountProvider accountProvider,
  ) async {
    String selectedCategory = tx.category;
    String? selectedAccountId = tx.accountId ?? accountProvider.accounts.firstOrNull?.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar movimiento'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Comercio: ${tx.merchantOrPayee}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Monto: ${Formatters.currency(tx.amount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: tx.type == TransactionType.expense ? const Color(0xFFF43F5E) : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Categoría:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: (tx.type == TransactionType.expense
                              ? AppCategories.expenseCategories
                              : AppCategories.incomeCategories)
                          .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text('Cargar a la cuenta:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAccountId,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: accountProvider.accounts
                          .map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedAccountId = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await context.read<FinanceProvider>().addTransaction(
            title: tx.merchantOrPayee,
            amount: tx.amount,
            type: tx.type,
            category: selectedCategory,
            date: tx.timestamp,
            note: 'Registrado automáticamente desde ${tx.bankName}',
            accountId: selectedAccountId ?? 'default-cash',
          );
      syncProvider.dismissPending(tx.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Movimiento registrado en tu balance con éxito.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showPermissionDialog(BuildContext context, NotificationSyncProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permiso necesario'),
        content: const Text(
          'Para que Balance App pueda leer las notificaciones de Nu y tus otros bancos, debes conceder el permiso en la pantalla de Ajustes de Android.\n\n¿Deseas abrir la configuración ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Más tarde'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.requestPermission();
            },
            child: const Text('Abrir Ajustes'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticLogsCard(
    BuildContext context,
    NotificationSyncProvider syncProvider,
    ColorScheme colorScheme,
  ) {
    final logs = syncProvider.notificationLogs;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 20, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Consola de Diagnóstico en Vivo',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (logs.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      syncProvider.clearLogs();
                    },
                    child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Registra en tiempo real cada alerta que Android entrega a Balance App para verificar si tu banco está enviando la notificación.',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No hay registros aún.\nLas alertas recibidas de tus aplicaciones bancarias aparecerán aquí en vivo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final timeStr =
                      '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}';
                  final badgeColor = log.isSuccess
                      ? const Color(0xFF10B981)
                      : (log.status.contains('ignorado') || log.status.contains('desactivado'))
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF6B7280);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.status,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: TextStyle(fontSize: 10.5, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      if (log.packageName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          log.packageName,
                          style: TextStyle(fontSize: 10, color: colorScheme.outline, fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      if (log.title.isNotEmpty)
                        Text(
                          log.title,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      Text(
                        log.text.isNotEmpty ? log.text : '(Sin texto detectado)',
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            LearnedRuleBottomSheet.show(
                              context,
                              initialPackage: log.packageName,
                              initialTitle: log.title,
                              initialText: log.text,
                              sourceLogItem: log,
                            );
                          },
                          icon: const Icon(Icons.school_rounded, size: 14, color: Color(0xFF6366F1)),
                          label: const Text(
                            'Enseñar a My Money',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingSection(BuildContext context, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.help_center_outlined, color: Color(0xFF6366F1)),
          title: const Text('¿Por qué no detecta mis notificaciones?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('Solución para Xiaomi, Samsung y Android 13+', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _buildHelpItem(
                    icon: Icons.battery_alert_outlined,
                    title: '1. Ahorro de Batería agresivo (Mata el servicio)',
                    description: 'En Xiaomi (MIUI/HyperOS), Samsung, Motorola o Huawei, el sistema suspende apps que no están abiertas.\nSolución: Ve a Información de la App > Batería > Cambiar a "Sin restricciones". En Xiaomi activa también "Inicio automático".',
                  ),
                  const SizedBox(height: 12),
                  _buildHelpItem(
                    icon: Icons.notifications_active_outlined,
                    title: '2. Notificaciones activas en tu banco',
                    description: 'Asegúrate de que la app de Nu, Bancolombia o Nequi tenga activadas las notificaciones emergentes de compras y transacciones en su menú de ajustes.',
                  ),
                  const SizedBox(height: 12),
                  _buildHelpItem(
                    icon: Icons.sync_problem_outlined,
                    title: '3. Servicio descolgado tras actualizar la app',
                    description: 'Android suele descolgar los oyentes de notificaciones tras instalar o actualizar una APK.\nSolución: Toca el botón "Reconectar detector" en la parte superior de esta pantalla.',
                  ),
                  const SizedBox(height: 12),
                  _buildHelpItem(
                    icon: Icons.security_outlined,
                    title: '4. Ajustes restringidos en Android 13/14/15',
                    description: 'Si el interruptor de notificación aparece deshabilitado o gris en Ajustes, ve a Información de Balance App > Menú 3 puntos (⋮) > "Permitir ajustes restringidos".',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildHelpItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  void _showRestrictedSettingsGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Expanded(child: Text('Ajuste restringido en Android', style: TextStyle(fontSize: 18))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'En Android 13, 14 y 15, cuando instalas una app en desarrollo o fuera de Play Store, el sistema bloquea los permisos especiales con el mensaje "Ajuste restringido".',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Cómo desbloquearlo en 4 pasos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _buildStepRow('1', 'Abre Ajustes de tu teléfono > Aplicaciones > Balance App.'),
              _buildStepRow('2', 'Toca los tres puntos (⋮) en la esquina superior derecha.'),
              _buildStepRow('3', 'Toca "Permitir ajustes restringidos" (te pedirá tu huella o PIN).'),
              _buildStepRow('4', 'Vuelve a Ajustes > Acceso a notificaciones y enciende el interruptor de Balance App.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Una vez permitido, el permiso permanecerá activo para siempre.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  static Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
            child: Text(number, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
