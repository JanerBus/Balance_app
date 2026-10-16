class CurrencyModel {
  final String code;
  final String symbol;
  final String name;
  final int decimalDigits;
  final String flag;

  const CurrencyModel({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
    required this.flag,
  });

  static const List<CurrencyModel> supportedCurrencies = [
    CurrencyModel(code: 'COP', symbol: '\$', name: 'Peso colombiano', decimalDigits: 0, flag: '🇨🇴'),
    CurrencyModel(code: 'USD', symbol: '\$', name: 'Dólar estadounidense', decimalDigits: 2, flag: '🇺🇸'),
    CurrencyModel(code: 'EUR', symbol: '€', name: 'Euro', decimalDigits: 2, flag: '🇪🇺'),
    CurrencyModel(code: 'MXN', symbol: '\$', name: 'Peso mexicano', decimalDigits: 2, flag: '🇲🇽'),
    CurrencyModel(code: 'ARS', symbol: '\$', name: 'Peso argentino', decimalDigits: 0, flag: '🇦🇷'),
    CurrencyModel(code: 'CLP', symbol: '\$', name: 'Peso chileno', decimalDigits: 0, flag: '🇨🇱'),
    CurrencyModel(code: 'PEN', symbol: 'S/', name: 'Sol peruano', decimalDigits: 2, flag: '🇵🇪'),
    CurrencyModel(code: 'BRL', symbol: 'R\$', name: 'Real brasileño', decimalDigits: 2, flag: '🇧🇷'),
    CurrencyModel(code: 'GBP', symbol: '£', name: 'Libra esterlina', decimalDigits: 2, flag: '🇬🇧'),
  ];

  static CurrencyModel get defaultCurrency => supportedCurrencies.first; // COP

  static CurrencyModel findByCode(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => defaultCurrency,
    );
  }
}
