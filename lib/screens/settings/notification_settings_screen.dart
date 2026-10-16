import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_settings_provider.dart';
import 'bank_sync_screen.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<NotificationSettingsProvider>().checkPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final notifProvider = context.watch<NotificationSettingsProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Centro de Notificaciones',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Banner de Permiso del Sistema si está desactivado
          if (!notifProvider.isSystemPermissionGranted)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E).withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFF43F5E), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Permiso de notificaciones requerido',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF43F5E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para recibir alertas bancarias, recordatorios de deudas y presupuestos, habilita el permiso de notificaciones en el sistema.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF43F5E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        await notifProvider.requestPermission();
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Conceder Permiso', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),

          // SECCIÓN 1: SINCRONIZACIÓN BANCARIA EN TIEMPO REAL
          _buildSectionHeader(context, 'Detección Bancaria Automática'),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Movimientos bancarios detectados',
            subtitle: 'Alerta instantánea al capturar transferencias, compras o abonos de Nu, Bancolombia, Nequi, Davivienda, etc.',
            value: notifProvider.notifyBankTransactions,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              notifProvider.setNotifyBankTransactions(val);
            },
            extraWidget: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BankSyncScreen()),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text(
                  'Configurar bancos y cuentas asociadas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // SECCIÓN 2: CONTROL DE PRESUPUESTOS
          _buildSectionHeader(context, 'Alertas Financieras y Control'),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.pie_chart_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Límites de Presupuesto (80% y 100%)',
            subtitle: 'Notificación preventiva al alcanzar el 80% y alerta prioritaria al superar el 100% del presupuesto mensual en una categoría.',
            value: notifProvider.notifyBudgetAlerts,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              notifProvider.setNotifyBudgetAlerts(val);
            },
          ),

          const SizedBox(height: 12),

          // SECCIÓN 3: COMPROMISOS Y PRÉSTAMOS
          _buildCard(
            context,
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: 'Vencimiento de Deudas y Préstamos',
            subtitle: 'Aviso 1 día antes y el día del vencimiento de cuotas por pagar o cobros a tu favor pendientes.',
            value: notifProvider.notifyDebtReminders,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              notifProvider.setNotifyDebtReminders(val);
            },
          ),

          const SizedBox(height: 12),

          // SECCIÓN 4: RECURRENTES Y SUSCRIPCIONES
          _buildCard(
            context,
            icon: Icons.autorenew_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Suscripciones y Pagos Fijos',
            subtitle: 'Recordatorio oportuno previo al cobro de suscripciones (Netflix, Spotify, servicios públicos, arriendos, etc.).',
            value: notifProvider.notifyRecurringReminders,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              notifProvider.setNotifyRecurringReminders(val);
            },
          ),

          const SizedBox(height: 24),

          // SECCIÓN 5: HÁBITOS Y BALANCE DIARIO
          _buildSectionHeader(context, 'Hábitos Financieros'),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.alarm_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Recordatorio Diario de Balance',
            subtitle: 'Aviso nocturno para registrar tus gastos diarios y mantener tu dinero siempre cuadrado.',
            value: notifProvider.notifyDailyReminder,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              notifProvider.setNotifyDailyReminder(val);
            },
            extraWidget: notifProvider.notifyDailyReminder
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: notifProvider.dailyReminderTime,
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          notifProvider.setDailyReminderTime(picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A2234) : const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Hora programada:',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                notifProvider.dailyReminderTime.format(context),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  )
                : null,
          ),

        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? extraWidget,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131824) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: value,
                activeThumbColor: iconColor,
                onChanged: onChanged,
              ),
            ],
          ),
          if (extraWidget != null) extraWidget,
        ],
      ),
    );
  }
}
