import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/currency_model.dart';
import '../utils/formatters.dart';

class CurrencyProvider with ChangeNotifier {
  static const _prefsKey = 'selectedCurrencyCode';

  CurrencyModel _currency = CurrencyModel.defaultCurrency;

  CurrencyModel get currency => _currency;

  Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      _currency = CurrencyModel.findByCode(code);
    }
    Formatters.setCurrency(_currency);
    notifyListeners();
  }

  Future<void> setCurrency(CurrencyModel currency) async {
    _currency = currency;
    Formatters.setCurrency(currency);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, currency.code);
  }
}
