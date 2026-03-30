import 'package:intl/intl.dart';

/// Formats numbers as Israeli New Shekel (₪) values.
abstract class CurrencyFormatter {
  static final _full = NumberFormat.currency(
    symbol: '₪',
    decimalDigits: 0,
    locale: 'he_IL',
  );

  static final _compact = NumberFormat.compactCurrency(
    symbol: '₪',
    decimalDigits: 1,
    locale: 'he_IL',
  );

  /// Full format: ₪2,400,000
  static String nis(double amount) => _full.format(amount);

  /// Compact format: ₪2.4M  (used in dashboard hero metrics)
  static String nisCompact(double amount) {
    if (amount >= 1000000) {
      return '₪${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '₪${(amount / 1000).toStringAsFixed(0)}K';
    }
    return nis(amount);
  }

  /// Change indicator: ↓ ₪1.6M reduced  or  ↑ ₪200K added
  static String nisChange(double change) {
    final arrow = change < 0 ? '↓' : '↑';
    return '$arrow ${nisCompact(change.abs())}';
  }
}
