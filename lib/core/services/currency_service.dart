import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// Currency Model
// ─────────────────────────────────────────────

class CurrencyInfo {
  final String code;       // e.g. "INR"
  final String symbol;     // e.g. "₹"
  final String name;       // e.g. "Indian Rupee"
  final String flag;       // e.g. "🇮🇳"

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });
}

// ─────────────────────────────────────────────
// Supported Currencies
// ─────────────────────────────────────────────

class SupportedCurrencies {
  static const List<CurrencyInfo> all = [
    CurrencyInfo(code: 'INR', symbol: '₹', name: 'Indian Rupee', flag: '🇮🇳'),
    CurrencyInfo(code: 'USD', symbol: '\$', name: 'US Dollar', flag: '🇺🇸'),
    CurrencyInfo(code: 'EUR', symbol: '€', name: 'Euro', flag: '🇪🇺'),
    CurrencyInfo(code: 'GBP', symbol: '£', name: 'British Pound', flag: '🇬🇧'),
    CurrencyInfo(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', flag: '🇦🇪'),
    CurrencyInfo(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar', flag: '🇸🇬'),
    CurrencyInfo(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar', flag: '🇦🇺'),
    CurrencyInfo(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar', flag: '🇨🇦'),
    CurrencyInfo(code: 'JPY', symbol: '¥', name: 'Japanese Yen', flag: '🇯🇵'),
    CurrencyInfo(code: 'CNY', symbol: '¥', name: 'Chinese Yuan', flag: '🇨🇳'),
    CurrencyInfo(code: 'CHF', symbol: 'Fr', name: 'Swiss Franc', flag: '🇨🇭'),
    CurrencyInfo(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit', flag: '🇲🇾'),
  ];

  static CurrencyInfo byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);

  // Map country codes to currency codes
  static const Map<String, String> countryToCurrency = {
    'IN': 'INR',
    'US': 'USD',
    'GB': 'GBP',
    'EU': 'EUR',
    'DE': 'EUR',
    'FR': 'EUR',
    'IT': 'EUR',
    'ES': 'EUR',
    'NL': 'EUR',
    'AE': 'AED',
    'SG': 'SGD',
    'AU': 'AUD',
    'CA': 'CAD',
    'JP': 'JPY',
    'CN': 'CNY',
    'CH': 'CHF',
    'MY': 'MYR',
  };
}

// ─────────────────────────────────────────────
// Currency State
// ─────────────────────────────────────────────

class CurrencyState {
  final CurrencyInfo currency;
  final Map<String, double> rates; // rates relative to USD
  final bool isLoading;
  final DateTime? lastUpdated;

  const CurrencyState({
    required this.currency,
    this.rates = const {},
    this.isLoading = false,
    this.lastUpdated,
  });

  CurrencyState copyWith({
    CurrencyInfo? currency,
    Map<String, double>? rates,
    bool? isLoading,
    DateTime? lastUpdated,
  }) {
    return CurrencyState(
      currency: currency ?? this.currency,
      rates: rates ?? this.rates,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Format an amount with the current currency symbol
  String format(double amount, {bool showSign = false}) {
    final formatter = NumberFormat.currency(
      symbol: currency.symbol,
      decimalDigits: currency.code == 'JPY' ? 0 : 2,
    );
    final formatted = formatter.format(amount.abs());
    if (showSign && amount != 0) {
      return amount < 0 ? '-$formatted' : '+$formatted';
    }
    return formatted;
  }
}

// ─────────────────────────────────────────────
// Currency Notifier
// ─────────────────────────────────────────────

class CurrencyNotifier extends StateNotifier<CurrencyState> {
  static const _prefKey = 'selected_currency_code';
  static const _ratesKey = 'exchange_rates_json';
  static const _ratesTimestampKey = 'exchange_rates_timestamp';

  CurrencyNotifier()
      : super(const CurrencyState(
          currency: CurrencyInfo(
            code: 'INR',
            symbol: '₹',
            name: 'Indian Rupee',
            flag: '🇮🇳',
          ),
        )) {
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Detect or load saved currency
    final savedCode = prefs.getString(_prefKey);
    final currencyCode = savedCode ?? _detectDeviceCurrency();
    final currency = SupportedCurrencies.byCode(currencyCode);

    // 2. Load cached exchange rates
    final cachedRatesJson = prefs.getString(_ratesKey);
    final cachedTimestamp = prefs.getInt(_ratesTimestampKey);
    Map<String, double> rates = {};

    if (cachedRatesJson != null) {
      final decoded = jsonDecode(cachedRatesJson) as Map<String, dynamic>;
      rates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    state = CurrencyState(
      currency: currency,
      rates: rates,
      lastUpdated: cachedTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(cachedTimestamp)
          : null,
    );

    // 3. Refresh rates if stale (older than 24h) or not cached
    final isStale = cachedTimestamp == null ||
        DateTime.now().millisecondsSinceEpoch - cachedTimestamp >
            const Duration(hours: 24).inMilliseconds;

    if (isStale) {
      await fetchExchangeRates();
    }
  }

  String _detectDeviceCurrency() {
    try {
      final locale = Platform.localeName; // e.g. "en_IN", "en_US"
      final parts = locale.split('_');
      if (parts.length >= 2) {
        final countryCode = parts.last.toUpperCase();
        return SupportedCurrencies.countryToCurrency[countryCode] ?? 'USD';
      }
    } catch (_) {}
    return 'USD';
  }

  Future<void> fetchExchangeRates() async {
    state = state.copyWith(isLoading: true);
    try {
      // Free API, no key required — rates relative to USD
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawRates = data['rates'] as Map<String, dynamic>;
        final rates = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));

        // Cache to prefs
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_ratesKey, jsonEncode(rates));
        await prefs.setInt(
            _ratesTimestampKey, DateTime.now().millisecondsSinceEpoch);

        state = state.copyWith(
          rates: rates,
          isLoading: false,
          lastUpdated: DateTime.now(),
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> changeCurrency(String currencyCode) async {
    final currency = SupportedCurrencies.byCode(currencyCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, currencyCode);
    state = state.copyWith(currency: currency);
  }

  /// Convert an amount FROM the current currency TO the target currency code
  double convertTo(double amount, String targetCode) {
    if (state.rates.isEmpty || state.currency.code == targetCode) return amount;
    // Convert via USD as base
    final fromRate = state.rates[state.currency.code] ?? 1.0;
    final toRate = state.rates[targetCode] ?? 1.0;
    return amount / fromRate * toRate;
  }

  /// Convert an amount from any currency code to the current display currency
  double convertFrom(double amount, String fromCode) {
    if (state.rates.isEmpty || fromCode == state.currency.code) return amount;
    final fromRate = state.rates[fromCode] ?? 1.0;
    final toRate = state.rates[state.currency.code] ?? 1.0;
    return amount / fromRate * toRate;
  }
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencyState>(
  (ref) => CurrencyNotifier(),
);

// Convenience extension
extension CurrencyFormat on WidgetRef {
  String formatAmount(double amount, {bool showSign = false}) {
    return read(currencyProvider).format(amount, showSign: showSign);
  }
}
