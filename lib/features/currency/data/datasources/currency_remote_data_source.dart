import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../../../../core/errors/exceptions.dart';

/// Fetches daily exchange rates from official central-bank open feeds.
abstract interface class CurrencyRemoteDataSource {
  /// Returns `targetCurrency -> rate` (base units per one target unit) for the
  /// given [baseCurrency] on [date].
  Future<Map<String, double>> fetchRates({
    required String baseCurrency,
    DateTime? date,
  });
}

/// Central Bank of Azerbaijan (CBAR) XML feed, which publishes AZN-denominated
/// rates for USD, EUR, GBP, TRY, RUB, and other currencies daily.
class CurrencyRemoteDataSourceImpl implements CurrencyRemoteDataSource {
  CurrencyRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static const String _cbarEndpoint = 'https://www.cbar.az/currencies/';

  @override
  Future<Map<String, double>> fetchRates({
    required String baseCurrency,
    DateTime? date,
  }) async {
    if (baseCurrency.toUpperCase() != 'AZN') {
      throw const ServerException(
        message: 'CBAR feed only publishes AZN-based rates.',
      );
    }
    final DateTime target = date ?? DateTime.now();
    final String day = '${target.day.toString().padLeft(2, '0')}.'
        '${target.month.toString().padLeft(2, '0')}.'
        '${target.year}';

    try {
      final Response<String> response = await _dio.get<String>(
        '$_cbarEndpoint$day.xml',
        options: Options(
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final String? body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw const ParsingException(
          message: 'The central-bank feed returned an empty response.',
        );
      }
      return _parseCbarXml(body);
    } on DioException catch (error) {
      throw NetworkException(
        message: 'Exchange rates could not be fetched from the central bank.',
        cause: error,
      );
    }
  }

  Map<String, double> _parseCbarXml(String body) {
    final XmlDocument document = XmlDocument.parse(body);
    final Map<String, double> rates = <String, double>{};
    for (final XmlElement valute in document.findAllElements('Valute')) {
      final String? code = valute.getAttribute('Code');
      if (code == null || code.trim().isEmpty) {
        continue;
      }
      final double? nominal = _parseDouble(
        valute.getElement('Nominal')?.innerText,
      );
      final double? value = _parseDouble(
        valute.getElement('Value')?.innerText,
      );
      if (nominal == null || value == null || nominal <= 0) {
        continue;
      }
      rates[code.toUpperCase()] = value / nominal;
    }
    if (rates.isEmpty) {
      throw const ParsingException(
        message: 'The central-bank feed contained no usable rates.',
      );
    }
    return rates;
  }

  static double? _parseDouble(String? value) {
    if (value == null) {
      return null;
    }
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
}
