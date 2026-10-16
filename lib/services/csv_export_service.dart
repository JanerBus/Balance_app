import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';
import '../models/account_model.dart';
import '../models/currency_model.dart';

class CsvExportService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  /// Generates RFC-4180 compliant CSV string with UTF-8 BOM for Microsoft Excel compatibility.
  static String generateCsv({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required CurrencyModel currency,
  }) {
    final buffer = StringBuffer();
    // UTF-8 Byte Order Mark (BOM) prevents Excel from misinterpreting accented characters (tildes, ñ)
    buffer.write('\uFEFF');

    // Header row
    buffer.writeln(
      'ID,Fecha,Hora,Tipo,Concepto,Categoría,Monto,Moneda,Cuenta Origen,Cuenta Destino,Nota',
    );

    final accountMap = {for (final a in accounts) a.id: a.name};

    for (final t in transactions) {
      final dateStr = _dateFormat.format(t.date);
      final timeStr = _timeFormat.format(t.date);
      final typeStr = switch (t.type) {
        TransactionType.income => 'Ingreso',
        TransactionType.expense => 'Gasto',
        TransactionType.transfer => 'Transferencia',
      };
      final originAccount = accountMap[t.accountId] ?? 'Principal';
      final destAccount = t.toAccountId != null ? (accountMap[t.toAccountId] ?? 'Destino') : '';
      final amountStr = t.amount.toStringAsFixed(currency.decimalDigits);

      final row = [
        _escapeCsv(t.id),
        _escapeCsv(dateStr),
        _escapeCsv(timeStr),
        _escapeCsv(typeStr),
        _escapeCsv(t.title),
        _escapeCsv(t.category),
        _escapeCsv(amountStr),
        _escapeCsv(currency.code),
        _escapeCsv(originAccount),
        _escapeCsv(destAccount),
        _escapeCsv(t.note ?? ''),
      ].join(',');

      buffer.writeln(row);
    }

    return buffer.toString();
  }

  /// Escapes fields containing commas, quotes or newlines according to RFC-4180
  /// and neutralizes CSV Formula Injection (DDE) triggers (=, +, -, @).
  static String _escapeCsv(String value) {
    var sanitized = value;
    if (sanitized.isNotEmpty &&
        (sanitized.startsWith('=') ||
         sanitized.startsWith('+') ||
         sanitized.startsWith('-') ||
         sanitized.startsWith('@'))) {
      // Si no es un valor puramente numérico (ej: -50.0), neutralizar ante Excel/Sheets con apóstrofe
      if (double.tryParse(sanitized) == null) {
        sanitized = "'$sanitized";
      }
    }

    final str = sanitized.replaceAll('"', '""');
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"$str"';
    }
    return str;
  }

  /// Writes CSV content to a temporary file and returns its path
  static Future<File> saveCsvTempFile({
    required String csvContent,
    String prefix = 'balance_movimientos',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${prefix}_$timestamp.csv';
    final file = File('${tempDir.path}/$fileName');
    return await file.writeAsString(csvContent);
  }

  /// Shares the generated CSV file via native share sheet
  static Future<void> shareCsv({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required CurrencyModel currency,
    String? subject,
  }) async {
    final csvContent = generateCsv(
      transactions: transactions,
      accounts: accounts,
      currency: currency,
    );
    final file = await saveCsvTempFile(csvContent: csvContent);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv', name: file.uri.pathSegments.last)],
        subject: subject ?? 'Movimientos Financieros - My Money',
      ),
    );
  }
}
