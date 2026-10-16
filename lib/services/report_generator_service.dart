import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/currency_model.dart';
import '../models/goal_model.dart';

class ReportGeneratorService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  static String _formatMonth(DateTime month) {
    try {
      return DateFormat('MMMM yyyy', 'es').format(month);
    } catch (_) {
      return DateFormat('yyyy-MM').format(month);
    }
  }

  static String _formatFullTimestamp(DateTime dt) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm', 'es').format(dt);
    } catch (_) {
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }
  }

  // Palette colors for the PDF theme
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF475569);
  static const PdfColor accentColor = PdfColor.fromInt(0xFF4F46E5);
  static const PdfColor incomeGreen = PdfColor.fromInt(0xFF059669);
  static const PdfColor expenseRed = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor surfaceColor = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFE2E8F0);

  /// Generates a complete monthly PDF financial statement document as bytes
  static Future<Uint8List> generateMonthlyReportPdf({
    required DateTime month,
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required List<GoalModel> goals,
    required CurrencyModel currency,
    required double totalIncome,
    required double totalExpense,
  }) async {
    final pdf = pw.Document(
      title: 'Extracto Financiero - ${_formatMonth(month)}',
      author: 'My Money',
    );

    final netSavings = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (netSavings / totalIncome * 100) : 0.0;

    // Filter month transactions
    final monthTransactions = transactions
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Calculate category spending
    final Map<String, double> categorySpending = {};
    for (final t in monthTransactions.where((t) => t.type == TransactionType.expense)) {
      categorySpending[t.category] = (categorySpending[t.category] ?? 0.0) + t.amount;
    }
    final sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final accountMap = {for (final a in accounts) a.id: a.name};

    String formatMoney(double val) {
      final sign = val < 0 ? '-' : '';
      return '$sign${currency.symbol} ${val.abs().toStringAsFixed(currency.decimalDigits)}';
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(month, context),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // 1. Executive Summary KPI Cards
          _buildKpiSection(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netSavings: netSavings,
            savingsRate: savingsRate,
            formatMoney: formatMoney,
          ),
          pw.SizedBox(height: 18),

          // 2. Wallets / Accounts Breakdown
          if (accounts.isNotEmpty) ...[
            _buildSectionTitle('Estado de Cuentas y Billeteras'),
            pw.SizedBox(height: 8),
            _buildAccountsTable(accounts, formatMoney),
            pw.SizedBox(height: 18),
          ],

          // 3. Category Expenses Distribution
          if (sortedCategories.isNotEmpty) ...[
            _buildSectionTitle('Distribución de Gastos por Categoría'),
            pw.SizedBox(height: 8),
            _buildCategoryBreakdown(sortedCategories, totalExpense, formatMoney),
            pw.SizedBox(height: 18),
          ],

          // 4. Savings Goals Progress
          if (goals.isNotEmpty) ...[
            _buildSectionTitle('Metas de Ahorro Activas'),
            pw.SizedBox(height: 8),
            _buildGoalsTable(goals, formatMoney),
            pw.SizedBox(height: 18),
          ],

          // 5. Detailed Transactions Ledger
          _buildSectionTitle('Detalle de Movimientos del Periodo (${monthTransactions.length})'),
          pw.SizedBox(height: 8),
          if (monthTransactions.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: surfaceColor,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderColor),
              ),
              child: pw.Text(
                'No se registraron transacciones durante este mes.',
                style: const pw.TextStyle(color: secondaryColor, fontSize: 11),
              ),
            )
          else
            _buildTransactionsTable(monthTransactions, accountMap, formatMoney),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(DateTime month, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: borderColor, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 24,
                    height: 24,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      color: accentColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'B',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'MY MONEY',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Extracto Financiero Mensual',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: secondaryColor,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _formatMonth(month).toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: accentColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Emitido: ${_formatFullTimestamp(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: secondaryColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderColor, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Documento generado localmente con My Money | Privado y Seguro',
            style: const pw.TextStyle(fontSize: 8, color: secondaryColor),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3.5,
          height: 13,
          decoration: pw.BoxDecoration(
            color: accentColor,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildKpiSection({
    required double totalIncome,
    required double totalExpense,
    required double netSavings,
    required double savingsRate,
    required String Function(double) formatMoney,
  }) {
    return pw.Row(
      children: [
        _buildKpiCard(
          title: 'Ingresos Totales',
          value: formatMoney(totalIncome),
          color: incomeGreen,
          subtext: 'Flujo positivo',
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'Gastos Totales',
          value: formatMoney(totalExpense),
          color: expenseRed,
          subtext: 'Salidas del mes',
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'Balance Neto',
          value: formatMoney(netSavings),
          color: netSavings >= 0 ? incomeGreen : expenseRed,
          subtext: netSavings >= 0 ? 'Superávit' : 'Déficit',
        ),
        pw.SizedBox(width: 8),
        _buildKpiCard(
          title: 'Tasa de Ahorro',
          value: '${savingsRate.toStringAsFixed(1)}%',
          color: savingsRate >= 20 ? incomeGreen : (savingsRate >= 0 ? accentColor : expenseRed),
          subtext: 'Sobre ingresos',
        ),
      ],
    );
  }

  static pw.Widget _buildKpiCard({
    required String title,
    required String value,
    required PdfColor color,
    required String subtext,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: surfaceColor,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: borderColor),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8.5, color: secondaryColor),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              subtext,
              style: const pw.TextStyle(fontSize: 7.5, color: secondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildAccountsTable(
    List<AccountModel> accounts,
    String Function(double) formatMoney,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: surfaceColor),
          children: [
            _buildTableHeaderCell('Cuenta / Billetera'),
            _buildTableHeaderCell('Tipo'),
            _buildTableHeaderCell('Saldo Actual', align: pw.TextAlign.right),
          ],
        ),
        ...accounts.map(
          (acc) => pw.TableRow(
            children: [
              _buildTableCell(acc.name, isBold: true),
              _buildTableCell(acc.typeLabel),
              _buildTableCell(
                formatMoney(acc.currentBalance),
                align: pw.TextAlign.right,
                textColor: acc.currentBalance >= 0 ? primaryColor : expenseRed,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCategoryBreakdown(
    List<MapEntry<String, double>> categories,
    double totalExpense,
    String Function(double) formatMoney,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: surfaceColor),
          children: [
            _buildTableHeaderCell('Categoría'),
            _buildTableHeaderCell('Monto Gastado', align: pw.TextAlign.right),
            _buildTableHeaderCell('% del Total', align: pw.TextAlign.right),
          ],
        ),
        ...categories.take(8).map((cat) {
          final pct = totalExpense > 0 ? (cat.value / totalExpense * 100) : 0.0;
          return pw.TableRow(
            children: [
              _buildTableCell(cat.key),
              _buildTableCell(formatMoney(cat.value), align: pw.TextAlign.right),
              _buildTableCell('${pct.toStringAsFixed(1)}%', align: pw.TextAlign.right),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildGoalsTable(
    List<GoalModel> goals,
    String Function(double) formatMoney,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: surfaceColor),
          children: [
            _buildTableHeaderCell('Meta de Ahorro'),
            _buildTableHeaderCell('Ahorrado', align: pw.TextAlign.right),
            _buildTableHeaderCell('Objetivo', align: pw.TextAlign.right),
            _buildTableHeaderCell('Progreso', align: pw.TextAlign.right),
          ],
        ),
        ...goals.take(5).map((g) {
          return pw.TableRow(
            children: [
              _buildTableCell(g.title, isBold: true),
              _buildTableCell(formatMoney(g.currentAmount), align: pw.TextAlign.right),
              _buildTableCell(formatMoney(g.targetAmount), align: pw.TextAlign.right),
              _buildTableCell(
                '${(g.progress * 100).toStringAsFixed(1)}%',
                align: pw.TextAlign.right,
                textColor: g.isCompleted ? incomeGreen : accentColor,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTransactionsTable(
    List<TransactionModel> transactions,
    Map<String, String> accountMap,
    String Function(double) formatMoney,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: surfaceColor),
          children: [
            _buildTableHeaderCell('Fecha'),
            _buildTableHeaderCell('Concepto'),
            _buildTableHeaderCell('Categoría'),
            _buildTableHeaderCell('Cuenta'),
            _buildTableHeaderCell('Tipo'),
            _buildTableHeaderCell('Importe', align: pw.TextAlign.right),
          ],
        ),
        ...transactions.map((t) {
          final isIncome = t.type == TransactionType.income;
          final isExpense = t.type == TransactionType.expense;
          final typeText = isIncome ? 'Ingreso' : (isExpense ? 'Gasto' : 'Transfer');
          final typeColor = isIncome ? incomeGreen : (isExpense ? expenseRed : accentColor);
          final accountName = accountMap[t.accountId] ?? 'Cuenta';

          return pw.TableRow(
            children: [
              _buildTableCell(_dateFormat.format(t.date)),
              _buildTableCell(t.title, isBold: true),
              _buildTableCell(t.category),
              _buildTableCell(accountName),
              _buildTableCell(typeText, textColor: typeColor),
              _buildTableCell(
                formatMoney(t.amount),
                align: pw.TextAlign.right,
                textColor: typeColor,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: textColor ?? primaryColor,
        ),
      ),
    );
  }
}
