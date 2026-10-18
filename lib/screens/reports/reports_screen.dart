import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../providers/finance_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/goal_provider.dart';
import '../../models/transaction_model.dart';
import '../../services/report_generator_service.dart';
import '../../services/csv_export_service.dart';
import '../../utils/formatters.dart';
import 'pdf_preview_screen.dart';
import '../settings/data_backup_screen.dart';

enum CsvExportRange {
  selectedMonth,
  last3Months,
  currentYear,
  allTime,
}

class ReportsScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const ReportsScreen({super.key, this.initialMonth});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTime _selectedMonth;
  CsvExportRange _selectedCsvRange = CsvExportRange.selectedMonth;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.initialMonth != null
        ? DateTime(widget.initialMonth!.year, widget.initialMonth!.month)
        : DateTime(now.year, now.month);
  }

  void _previousMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  Future<Uint8List> _generatePdfBytes() async {
    final financeProvider = context.read<FinanceProvider>();
    final accountProvider = context.read<AccountProvider>();
    final goalProvider = context.read<GoalProvider>();
    final currencyProvider = context.read<CurrencyProvider>();

    final monthTransactions = financeProvider.transactionsForMonth(_selectedMonth);
    final monthIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final monthExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);

    return await ReportGeneratorService.generateMonthlyReportPdf(
      month: _selectedMonth,
      transactions: financeProvider.transactions,
      accounts: accountProvider.accounts,
      goals: goalProvider.goals,
      currency: currencyProvider.currency,
      totalIncome: monthIncome,
      totalExpense: monthExpense,
    );
  }

  Future<void> _openPdfPreview() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          month: _selectedMonth,
          buildPdf: _generatePdfBytes,
        ),
      ),
    );
  }

  Future<void> _sharePdfDirect() async {
    HapticFeedback.lightImpact();
    setState(() => _isExporting = true);
    try {
      final bytes = await _generatePdfBytes();
      final monthStr = DateFormat('yyyy_MM').format(_selectedMonth);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'extracto_financiero_$monthStr.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  List<TransactionModel> _getFilteredTransactionsForCsv(List<TransactionModel> allTransactions) {
    final now = DateTime.now();
    switch (_selectedCsvRange) {
      case CsvExportRange.selectedMonth:
        return allTransactions
            .where((t) => t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month)
            .toList();
      case CsvExportRange.last3Months:
        final threeMonthsAgo = DateTime(now.year, now.month - 2, 1);
        return allTransactions.where((t) => t.date.isAfter(threeMonthsAgo)).toList();
      case CsvExportRange.currentYear:
        return allTransactions.where((t) => t.date.year == now.year).toList();
      case CsvExportRange.allTime:
        return allTransactions;
    }
  }

  String _getCsvRangeLabel(CsvExportRange range) {
    switch (range) {
      case CsvExportRange.selectedMonth:
        return 'Mes seleccionado (${DateFormat('MMM yyyy', 'es').format(_selectedMonth)})';
      case CsvExportRange.last3Months:
        return 'Últimos 3 meses';
      case CsvExportRange.currentYear:
        return 'Año en curso (${DateTime.now().year})';
      case CsvExportRange.allTime:
        return 'Todo el historial completo';
    }
  }

  Future<void> _exportCsv() async {
    HapticFeedback.lightImpact();
    final financeProvider = context.read<FinanceProvider>();
    final accountProvider = context.read<AccountProvider>();
    final currencyProvider = context.read<CurrencyProvider>();

    final transactions = _getFilteredTransactionsForCsv(financeProvider.transactions);
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay movimientos en el periodo seleccionado para exportar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      await CsvExportService.shareCsv(
        transactions: transactions,
        accounts: accountProvider.accounts,
        currency: currencyProvider.currency,
        subject: 'Extracto Financiero CSV - Balance App',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = context.watch<FinanceProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final monthTransactions = financeProvider.transactionsForMonth(_selectedMonth);
    final monthIncome = monthTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (s, t) => s + t.amount);
    final monthExpense = monthTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (s, t) => s + t.amount);
    final netSavings = monthIncome - monthExpense;
    final savingsRate = monthIncome > 0 ? (netSavings / monthIncome * 100) : 0.0;

    final csvCount = _getFilteredTransactionsForCsv(financeProvider.transactions).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extractos y Reportes'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Selector de Mes
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 24),
                    onPressed: _previousMonth,
                    splashRadius: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      Formatters.monthYear(_selectedMonth).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 24),
                    onPressed: _nextMonth,
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resumen del Periodo Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                    : [const Color(0xFFEEF2FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                    : const Color(0xFFC7D2FE),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Resumen Financiero',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${monthTransactions.length} movs',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Ingresos',
                        amount: Formatters.currency(monthIncome),
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Gastos',
                        amount: Formatters.currency(monthExpense),
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Balance Neto',
                        amount: Formatters.currency(netSavings),
                        color: netSavings >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        label: 'Tasa de Ahorro',
                        amount: '${savingsRate.toStringAsFixed(1)}%',
                        color: savingsRate >= 20
                            ? const Color(0xFF10B981)
                            : (savingsRate >= 0 ? const Color(0xFF6366F1) : const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECCIÓN 1: EXTRACTO EN PDF
          _buildActionCard(
            context: context,
            icon: Icons.picture_as_pdf_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Extracto Mensual en PDF',
            description:
                'Genera un informe profesional con balance general, distribución por categorías, estado de cuentas y listado detallado.',
            primaryButtonText: 'Vista Previa e Imprimir',
            primaryButtonIcon: Icons.visibility_rounded,
            onPrimaryTap: _openPdfPreview,
            secondaryButtonText: 'Compartir PDF',
            secondaryButtonIcon: Icons.share_rounded,
            onSecondaryTap: _sharePdfDirect,
            isLoading: _isExporting,
          ),
          const SizedBox(height: 18),

          // SECCIÓN 2: EXPORTACIÓN EXCEL / CSV
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.table_chart_rounded, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exportar a Excel / CSV',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Compatible con Microsoft Excel, Google Sheets y Numbers con codificación UTF-8.',
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
                Text(
                  'Rango de movimientos a exportar:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),

                // Selector de Rango
                ...CsvExportRange.values.map((range) {
                  final isSelected = _selectedCsvRange == range;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCsvRange = range);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? const Color(0xFF10B981) : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getCsvRangeLabel(range),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Botón Exportar CSV
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportCsv,
                    icon: const Icon(Icons.file_download_outlined, size: 20),
                    label: Text('Exportar $csvCount movimientos (.csv)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Banner Copia de Seguridad Completa (JSON)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copia de Seguridad Completa',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Exporta o restaura toda tu base de datos en formato JSON portable.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DataBackupScreen()),
                    );
                  },
                  child: const Text('Abrir', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String amount,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String primaryButtonText,
    required IconData primaryButtonIcon,
    required VoidCallback onPrimaryTap,
    required String secondaryButtonText,
    required IconData secondaryButtonIcon,
    required VoidCallback onSecondaryTap,
    required bool isLoading,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onSecondaryTap,
                  icon: Icon(secondaryButtonIcon, size: 18),
                  label: Text(secondaryButtonText),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onPrimaryTap,
                  icon: Icon(primaryButtonIcon, size: 18),
                  label: Text(primaryButtonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
