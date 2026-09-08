import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../network/api_client.dart';

/// OCR engines return raw text, positioned lines, and normalized fields.
abstract interface class OcrService {
  Future<Map<String, dynamic>> extractTextAndStructure(File file);
}

/// Deterministic offline OCR implementation used by the desktop shell and
/// development builds. It can parse text-based fixtures and still returns a
/// valid structured payload for binary images/PDFs until a real OCR engine is
/// configured.
class MockOcrService implements OcrService {
  const MockOcrService();

  @override
  Future<Map<String, dynamic>> extractTextAndStructure(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('OCR input file does not exist.', file.path);
    }

    final List<int> bytes = await file.readAsBytes();
    final String text = _bestEffortText(bytes, file.path);
    return OcrTextParser.parse(text);
  }

  String _bestEffortText(List<int> bytes, String filePath) {
    final String decoded = utf8.decode(bytes, allowMalformed: true);
    final List<String> lines = decoded
        .split(RegExp(r'\r?\n'))
        .map(_cleanLine)
        .where(_isUsefulLine)
        .take(300)
        .toList(growable: false);

    if (lines.isEmpty) {
      return 'File: ${p.basename(filePath)}';
    }
    return lines.join('\n');
  }

  String _cleanLine(String value) {
    final StringBuffer buffer = StringBuffer();
    for (final int codeUnit in value.codeUnits) {
      if (codeUnit == 9 || (codeUnit >= 32 && codeUnit != 127)) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isUsefulLine(String value) {
    if (value.length < 2) {
      return false;
    }
    return RegExp(r'[A-Za-zƏəÖöÜüĞğÇçŞşİı0-9]').hasMatch(value);
  }
}

/// HTTP adapter for hosted OCR, Vision APIs, or a local PaddleOCR gateway.
class HttpOcrService implements OcrService {
  const HttpOcrService(
    this._apiClient, {
    this.endpoint = '/ocr/extract',
  });

  final ApiClient _apiClient;
  final String endpoint;

  @override
  Future<Map<String, dynamic>> extractTextAndStructure(File file) async {
    if (!await file.exists()) {
      throw FileSystemException('OCR input file does not exist.', file.path);
    }

    final String encodedFile = base64Encode(await file.readAsBytes());
    final Response<Map<String, dynamic>> response = await _apiClient
        .post<Map<String, dynamic>>(
      endpoint,
      data: <String, dynamic>{
        'fileName': p.basename(file.path),
        'contentBase64': encodedFile,
      },
    );

    final Object? responseData = response.data;
    if (responseData is! Map<String, dynamic>) {
      throw const FormatException('OCR service returned an invalid payload.');
    }

    return OcrTextParser.normalizeRemotePayload(responseData);
  }
}

/// Shared parser used by the offline mock and remote adapters.
abstract final class OcrTextParser {
  static Map<String, dynamic> parse(String rawText) {
    final List<String> lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList(growable: false);
    final String combinedText = lines.join('\n');
    final Map<String, dynamic> structured = <String, dynamic>{};

    final String? vendorName = _namedValue(
      lines,
      RegExp(
        r'^(?:vendor|seller|supplier|company|satıcı|şirkət)'
        r'(?:\s+name|\s+adı)?\s*[:#-]\s*(.+)$',
        caseSensitive: false,
      ),
    );
    final String? vendorVoen = _firstCapture(
      combinedText,
      RegExp(
        r'(?:vöen(?:\s*/\s*tin)?|voen|tin|tax\s*'
        r'(?:id|registration(?:\s+number)?))'
        r'\s*[:#-]?\s*([A-Z0-9-]{5,})',
        caseSensitive: false,
      ),
    );
    final String? invoiceNumber = _firstCapture(
      combinedText,
      RegExp(
        r'(?:invoice|inv|invoice\s*(?:no|number)|factura)'
        r'\s*(?:no|number|#)?\s*[:#-]?\s*([A-Z0-9\-/]{2,})',
        caseSensitive: false,
      ),
    );
    final String? issueDate = _firstCapture(
      combinedText,
      RegExp(
        r'(?:^|\n)\s*(?:issue\s*date|date|tarix|invoice\s*date)'
        r'\s*[:#-]?\s*([0-9]{1,4}[./-][0-9]{1,2}[./-][0-9]{1,4})',
        caseSensitive: false,
      ),
    );
    final String? dueDate = _firstCapture(
      combinedText,
      RegExp(
        r'(?:^|\n)\s*(?:due\s*date|payment\s*due|son\s*ödəniş\s*tarixi|'
        r'odəniş\s*tarixi|ödəmə\s*tarixi)'
        r'\s*[:#-]?\s*([0-9]{1,4}[./-][0-9]{1,2}[./-][0-9]{1,4})',
        caseSensitive: false,
      ),
    );

    if (vendorName != null) {
      structured['vendorName'] = vendorName;
    }
    if (vendorVoen != null) {
      structured['vendorVoen'] = vendorVoen;
    }
    if (invoiceNumber != null) {
      structured['invoiceNumber'] = invoiceNumber;
    }
    if (issueDate != null) {
      structured['issueDate'] = issueDate;
    }
    if (dueDate != null) {
      structured['dueDate'] = dueDate;
    }

    final double? subtotal = _amountAfterLabel(
      combinedText,
      RegExp(
        r'(?:subtotal|sub\s*total|ara\s*məbləğ|ara\s*m\u0259bl\u0259ğ)',
        caseSensitive: false,
      ),
    );
    final double? vatAmount = _amountAfterLabel(
      combinedText,
      RegExp(
        r'(?:vat|tax|ƏDV|edv|sales\s*tax)',
        caseSensitive: false,
      ),
    );
    final double? totalAmount = _amountAfterLabel(
      combinedText,
      RegExp(
        r'(?:grand\s*total|total\s*amount|amount\s*due|total|yekun|'
        r'ümumi\s*məbləğ|umumi\s*mebleg)',
        caseSensitive: false,
      ),
    );

    if (subtotal != null) {
      structured['subtotal'] = subtotal;
    }
    if (vatAmount != null) {
      structured['vatAmount'] = vatAmount;
    }
    if (totalAmount != null) {
      structured['totalAmount'] = totalAmount;
    }
    structured['currency'] = _currency(combinedText);
    structured['lineItems'] = _lineItems(lines);

    return <String, dynamic>{
      'rawText': rawText,
      'lines': _positionedLines(lines),
      'structured': structured,
    };
  }

  static Map<String, dynamic> normalizeRemotePayload(
    Map<String, dynamic> payload,
  ) {
    final Object? structured = payload['structured'];
    final Object? rawText = payload['rawText'] ?? payload['text'];
    if (structured is Map<String, dynamic>) {
      return <String, dynamic>{
        ...payload,
        'lines': payload['lines'] ?? _positionedLines(
          rawText is String ? rawText.split(RegExp(r'\r?\n')) : <String>[],
        ),
      };
    }
    if (rawText is String) {
      final Map<String, dynamic> parsed = parse(rawText);
      return <String, dynamic>{...parsed, ...payload};
    }
    return payload;
  }

  static List<Map<String, dynamic>> _positionedLines(List<String> lines) {
    return <Map<String, dynamic>>[
      for (int index = 0; index < lines.length; index++)
        <String, dynamic>{
          'text': lines[index],
          'confidence': 0.0,
          'boundingBox': <String, double>{
            'left': 0,
            'top': index * 24.0,
            'right': 1000,
            'bottom': (index + 1) * 24.0,
          },
        },
    ];
  }

  static String? _namedValue(List<String> lines, RegExp expression) {
    for (final String line in lines) {
      final RegExpMatch? match = expression.firstMatch(line);
      final String? value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _firstCapture(String value, RegExp expression) {
    return expression.firstMatch(value)?.group(1)?.trim();
  }

  static double? _amountAfterLabel(String value, RegExp label) {
    final String expressionPattern =
        r'(?:^|\n)\s*' +
        label.pattern +
        r'\s*[:#-]?\s*(?:[A-Z]{3}\s*)?[$€£]?\s*'
        r'([0-9][0-9\s.,]*)';
    final RegExp expression = RegExp(
      expressionPattern,
      caseSensitive: false,
    );
    final String? rawAmount = expression.firstMatch(value)?.group(1);
    if (rawAmount == null) {
      return null;
    }
    return _parseAmount(rawAmount);
  }

  static double? _parseAmount(String value) {
    String normalized = value.replaceAll(RegExp(r'\s+'), '');
    final int lastComma = normalized.lastIndexOf(',');
    final int lastDot = normalized.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      final int decimals = normalized.length - lastComma - 1;
      normalized = decimals == 3
          ? normalized.replaceAll(',', '')
          : normalized.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  static String _currency(String value) {
    if (RegExp(r'\bUSD\b|\$', caseSensitive: false).hasMatch(value)) {
      return 'USD';
    }
    if (RegExp(r'\bEUR\b|€', caseSensitive: false).hasMatch(value)) {
      return 'EUR';
    }
    if (RegExp(r'\bGBP\b|£', caseSensitive: false).hasMatch(value)) {
      return 'GBP';
    }
    return 'AZN';
  }

  static List<Map<String, dynamic>> _lineItems(List<String> lines) {
    final RegExp lineExpression = RegExp(
      r'^\s*([0-9]+(?:[.,][0-9]+)?)\s*[x×]\s*'
      r'(.+?)\s+([0-9][0-9\s.,]*)\s*$',
    );
    final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
    for (final String line in lines) {
      final RegExpMatch? match = lineExpression.firstMatch(line);
      if (match == null) {
        continue;
      }
      final double? quantity = _parseAmount(match.group(1)!);
      final double? lineTotal = _parseAmount(match.group(3)!);
      if (quantity == null || lineTotal == null || quantity == 0) {
        continue;
      }
      items.add(<String, dynamic>{
        'id': 'ocr-line-${items.length + 1}',
        'description': match.group(2)!.trim(),
        'quantity': quantity,
        'unitPrice': lineTotal / quantity,
        'lineTotal': lineTotal,
        'vatRate': 0.0,
      });
    }
    return items;
  }
}
