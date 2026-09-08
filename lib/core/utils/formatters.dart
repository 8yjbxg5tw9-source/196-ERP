import 'package:intl/intl.dart';

/// Locale-aware formatting helpers for financial and audit-facing UI.
abstract final class AppFormatters {
  static String currency(
    num value, {
    String locale = 'en_US',
    String symbol = r'$',
  }) {
    return NumberFormat.currency(locale: locale, symbol: symbol).format(value);
  }

  static String decimal(
    num value, {
    String locale = 'en_US',
    int decimalDigits = 2,
  }) {
    return NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  static String date(DateTime value, {String locale = 'en_US'}) {
    return DateFormat.yMMMd(locale).format(value);
  }

  static String dateTime(DateTime value, {String locale = 'en_US'}) {
    return DateFormat.yMMMd(locale).add_jm().format(value);
  }
}
