import 'package:intl/intl.dart';
import '../models/currency_model.dart';

class Formatters {
  static CurrencyModel activeCurrency = CurrencyModel.defaultCurrency;
  static bool isPrivacyMode = false;

  static void setCurrency(CurrencyModel currency) {
    activeCurrency = currency;
  }

  static String currency(double value, [CurrencyModel? overrideCurrency, bool? forcePrivacy]) {
    final curr = overrideCurrency ?? activeCurrency;
    if (forcePrivacy ?? isPrivacyMode) {
      return '${curr.symbol} ••••••';
    }
    final formatter = NumberFormat.currency(
      locale: 'es',
      symbol: '${curr.symbol} ',
      decimalDigits: curr.decimalDigits,
    );
    return formatter.format(value);
  }

  static final DateFormat _shortDate = DateFormat('d MMM yyyy', 'es');
  static String shortDate(DateTime date) => _shortDate.format(date);

  static final DateFormat _dayMonth = DateFormat('d MMM', 'es');
  static String dayMonth(DateTime date) => _dayMonth.format(date);

  static final DateFormat _monthYear = DateFormat('MMMM yyyy', 'es');
  static String monthYear(DateTime date) => _monthYear.format(date);
}
