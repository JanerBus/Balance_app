import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/recurring_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/notification_sync_provider.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../reports/reports_screen.dart';

/// Pantalla moderna para Exportar e Importar copias de seguridad de la información del usuario
class DataBackupScreen extends StatefulWidget {
  const DataBackupScreen({super.key});

  @override
  State<DataBackupScreen> createState() => _DataBackupScreenState();
}

class _DataBackupScreenState extends State<DataBackupScreen> {
  bool _isExporting = false;
  bool _isImporting = false;

  Future<void> _handleExportAndShare() async {
    HapticFeedback.lightImpact();
    setState(() => _isExporting = true);

    try {
      await BackupService.shareBackup();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al exportar la copia: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleCopyToClipboard() async {
    HapticFeedback.lightImpact();
    try {
      await BackupService.copyBackupToClipboard();
      if (mounted) {
        _showSnackBar('¡Copia de seguridad copiada al portapapeles!');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al copiar al portapapeles: $e', isError: true);
      }
    }
  }

  Future<void> _handlePickFile() async {
    HapticFeedback.lightImpact();
    try {
      final jsonContent = await BackupService.pickBackupFile();
      if (jsonContent == null) return; // Usuario canceló selección

      _processRawJsonForImport(jsonContent);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al leer el archivo de respaldo: $e', isError: true);
      }
    }
  }

  Future<void> _handlePasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();

    if (text == null || text.isEmpty) {
      if (mounted) {
        _showSnackBar('El portapapeles está vacío o no contiene texto.', isError: true);
      }
      return;
    }

    _processRawJsonForImport(text);
  }

  void _processRawJsonForImport(String rawJson) {
    final validation = BackupService.validateAndSummarizeJson(rawJson);

    if (!validation.isValid || validation.parsedData == null || validation.summary == null) {
      _showSnackBar(
        validation.errorMessage ?? 'El formato del archivo no es compatible.',
        isError: true,
      );
      return;
    }

    _showImportConfirmationSheet(
      summary: validation.summary!,
      backupData: validation.parsedData!,
    );
  }

  void _showImportConfirmationSheet({
    required BackupSummary summary,
    required Map<String, dynamic> backupData,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ImportConfirmationSheet(
        summary: summary,
        backupData: backupData,
        onConfirm: (mode) async {
          Navigator.pop(sheetContext);
          await _executeImport(backupData: backupData, mode: mode);
        },
      ),
    );
  }

  Future<void> _executeImport({
    required Map<String, dynamic> backupData,
    required ImportMode mode,
  }) async {
    setState(() => _isImporting = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await BackupService.restoreBackup(
        backupData: backupData,
        mode: mode,
        context: context,
      );

      if (mounted) {
        if (result.success) {
          _showSnackBar(result.message);
        } else {
          _showSnackBar(result.message, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error durante la restauración: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppTheme.expenseRed : const Color(0xFF10B981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final financeProvider = context.watch<FinanceProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final debtProvider = context.watch<DebtProvider>();
    final budgetProvider = context.watch<BudgetProvider>();
    final goalProvider = context.watch<GoalProvider>();
    final recurringProvider = context.watch<RecurringProvider>();
    final syncProvider = context.watch<NotificationSyncProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Copia y Restauración',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HERO BANNER ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                        : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFC7D2FE),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primarySeed.withValues(alpha: isDark ? 0.2 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.primarySeed.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        color: Color(0xFF6366F1),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control Total de tus Datos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tus finanzas permanecen 100% privadas. Exporta copias portables en JSON o traspasa tu historial entre dispositivos.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --- RESUMEN DE DATOS ACTUALES ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A29) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Datos actuales en este dispositivo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDataBadge(
                          icon: Icons.account_balance_wallet_rounded,
                          label: '${accountProvider.accounts.length} Cuentas',
                          color: const Color(0xFF3B82F6),
                          isDark: isDark,
                        ),
                        _buildDataBadge(
                          icon: Icons.receipt_long_rounded,
                          label: '${financeProvider.transactions.length} Movimientos',
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                        _buildDataBadge(
                          icon: Icons.flag_rounded,
                          label: '${goalProvider.goals.length} Metas',
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                        _buildDataBadge(
                          icon: Icons.handshake_outlined,
                          label: '${debtProvider.debts.length} Deudas',
                          color: const Color(0xFFF43F5E),
                          isDark: isDark,
                        ),
                        _buildDataBadge(
                          icon: Icons.autorenew_rounded,
                          label: '${recurringProvider.recurring.length} Recurrentes',
                          color: const Color(0xFF06B6D4),
                          isDark: isDark,
                        ),
                        _buildDataBadge(
                          icon: Icons.pie_chart_outline_rounded,
                          label: '${budgetProvider.budgets.length} Presupuestos',
                          color: const Color(0xFFEAB308),
                          isDark: isDark,
                        ),
                        _buildDataBadge(
                          icon: Icons.psychology_outlined,
                          label: '${syncProvider.userRules.length} Reglas',
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // --- SECCIÓN 1: EXPORTAR ---
              Text(
                'EXPORTAR INFORMACIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A29) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Copia de Seguridad Completa (.json)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Genera un archivo con todas tus cuentas, movimientos, metas, reglas aprendidas y presupuestos para respaldar o transferir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón Compartir Archivo
                    ElevatedButton.icon(
                      onPressed: _isExporting ? null : _handleExportAndShare,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isExporting ? 'Generando archivo...' : 'Exportar y Compartir Archivo',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primarySeed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Botón Copiar al Portapapeles
                    OutlinedButton.icon(
                      onPressed: _handleCopyToClipboard,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Copiar Respaldo al Portapapeles',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Atajo a exportación Excel
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ReportsScreen()),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Exportar a Excel (CSV)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- SECCIÓN 2: IMPORTAR ---
              Text(
                'IMPORTAR Y RESTAURAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131A29) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Restaurar desde Copia de Seguridad',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Carga un archivo de respaldo generado anteriormente. Podrás previsualizar el contenido antes de confirmar el reemplazo o combinación de datos.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón Seleccionar Archivo
                    ElevatedButton.icon(
                      onPressed: _isImporting ? null : _handlePickFile,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.file_open_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isImporting ? 'Procesando respaldo...' : 'Seleccionar Archivo de Respaldo (.json)',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Botón Pegar del portapapeles
                    OutlinedButton.icon(
                      onPressed: _isImporting ? null : _handlePasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Pegar Respaldo desde Portapapeles',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataBadge({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja modal de confirmación y selección de modo de restauración
class _ImportConfirmationSheet extends StatefulWidget {
  final BackupSummary summary;
  final Map<String, dynamic> backupData;
  final ValueChanged<ImportMode> onConfirm;

  const _ImportConfirmationSheet({
    required this.summary,
    required this.backupData,
    required this.onConfirm,
  });

  @override
  State<_ImportConfirmationSheet> createState() => _ImportConfirmationSheetState();
}

class _ImportConfirmationSheetState extends State<_ImportConfirmationSheet> {
  ImportMode _selectedMode = ImportMode.replace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dateStr = widget.summary.exportedAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(widget.summary.exportedAt!)
        : 'Fecha desconocida';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131824) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primarySeed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_backup_restore_rounded, color: AppTheme.primarySeed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmar Restauración',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Respaldo de ${widget.summary.app} ($dateStr)',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Resumen de registros a importar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2234) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contenido detectado en la copia:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• ${widget.summary.accountsCount} cuentas bancarias y billeteras\n'
                  '• ${widget.summary.transactionsCount} movimientos históricos\n'
                  '• ${widget.summary.debtsCount} deudas (${widget.summary.debtPaymentsCount} abonos)\n'
                  '• ${widget.summary.budgetsCount} presupuestos de gasto\n'
                  '• ${widget.summary.recurringCount} suscripciones recurrentes\n'
                  '• ${widget.summary.goalsCount} metas de ahorro\n'
                  '• ${widget.summary.learnedRulesCount} reglas inteligentes de aprendizaje',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Selector de Modo de Importación
          Text(
            'Elige cómo aplicar la copia:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // Opción 1: Reemplazar todo
          _buildModeOption(
            mode: ImportMode.replace,
            title: 'Reemplazar todo (Restauración completa)',
            subtitle: 'Borra los datos actuales y restaura con exactitud los de la copia.',
            icon: Icons.restore_rounded,
            color: const Color(0xFFF43F5E),
            isDark: isDark,
          ),

          const SizedBox(height: 8),

          // Opción 2: Combinar / Fusionar
          _buildModeOption(
            mode: ImportMode.merge,
            title: 'Combinar datos (Fusión inteligente)',
            subtitle: 'Agrega transacciones y metas nuevas sin borrar los registros que ya tienes.',
            icon: Icons.merge_type_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => widget.onConfirm(_selectedMode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMode == ImportMode.replace
                        ? const Color(0xFFE11D48)
                        : const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _selectedMode == ImportMode.replace ? 'Reemplazar y Restaurar' : 'Combinar Datos',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required ImportMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedMode = mode);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? color : (isDark ? Colors.white54 : Colors.black38),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected && !isDark ? color : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
