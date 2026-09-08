import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../domain/entities/document_entity.dart';
import '../../domain/entities/invoice_item_entity.dart';

/// SQLite/API representation of a [DocumentEntity].
class DocumentModel extends DocumentEntity {
  const DocumentModel({
    required super.id,
    required super.companyId,
    required super.filePath,
    required super.fileName,
    super.vendorName,
    super.vendorVoen,
    super.invoiceNumber,
    super.issueDate,
    super.dueDate,
    super.subtotal,
    super.vatAmount,
    super.totalAmount,
    super.createdAt,
    super.currency,
    super.status,
    super.lineItems,
    super.extractedData,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final String filePath = _requiredString(
      json,
      <String>['filePath', 'file_path'],
    );
    return DocumentModel(
      id: _requiredString(json, <String>['id']),
      companyId: _requiredString(json, <String>['companyId', 'company_id']),
      filePath: filePath,
      fileName: _readString(
        json,
        <String>['fileName', 'file_name'],
        fallback: p.basename(filePath),
      ),
      vendorName: _optionalString(json, <String>['vendorName', 'vendor_name']),
      vendorVoen: _optionalString(json, <String>['vendorVoen', 'vendor_voen']),
      invoiceNumber: _optionalString(
        json,
        <String>['invoiceNumber', 'invoice_number'],
      ),
      issueDate: _optionalDateTime(
        _firstValue(json, <String>['issueDate', 'issue_date']),
      ),
      dueDate: _optionalDateTime(
        _firstValue(json, <String>['dueDate', 'due_date']),
      ),
      subtotal: _optionalDouble(json, <String>['subtotal']),
      vatAmount: _optionalDouble(json, <String>['vatAmount', 'vat_amount']),
      totalAmount: _optionalDouble(
        json,
        <String>['totalAmount', 'total_amount'],
      ),
      createdAt: _optionalDateTime(
        _firstValue(json, <String>['createdAt', 'created_at']),
      ),
      currency: _readString(
        json,
        <String>['currency'],
        fallback: 'AZN',
      ),
      status: _status(_firstValue(json, <String>['status'])),
      lineItems: _lineItems(
        _firstValue(json, <String>['lineItems', 'line_items']),
      ),
      extractedData: _asMap(
        _firstValue(json, <String>['extractedData', 'extracted_json']),
      ),
    );
  }

  factory DocumentModel.fromSqflite(Map<String, Object?> row) {
    final String filePath = _requiredRowString(row, 'file_path');
    return DocumentModel(
      id: _requiredRowString(row, 'id'),
      companyId: _requiredRowString(row, 'company_id'),
      filePath: filePath,
      fileName: _rowString(row, 'file_name', fallback: p.basename(filePath)),
      vendorName: _optionalRowString(row, 'vendor_name'),
      vendorVoen: _optionalRowString(row, 'vendor_voen'),
      invoiceNumber: _optionalRowString(row, 'invoice_number'),
      issueDate: _optionalDateTime(row['issue_date']),
      dueDate: _optionalDateTime(row['due_date']),
      subtotal: _rowDouble(row['subtotal']),
      vatAmount: _rowDouble(row['vat_amount']),
      totalAmount: _rowDouble(row['total_amount']),
      createdAt: _optionalDateTime(row['created_at']),
      currency: _rowString(row, 'currency', fallback: 'AZN'),
      status: _status(row['status']),
      lineItems: _lineItems(_decodeJson(row['line_items_json'])),
      extractedData: _asMap(_decodeJson(row['extracted_json'])),
    );
  }

  /// Creates a completed model from the OCR response while preserving file
  /// identity and the original payload for audit/reprocessing.
  factory DocumentModel.fromOcrResult({
    required DocumentModel base,
    required Map<String, dynamic> ocrPayload,
  }) {
    final Map<String, dynamic> structured = _asMap(
          ocrPayload['structured'],
        ) ??
        ocrPayload;
    return DocumentModel(
      id: base.id,
      companyId: base.companyId,
      filePath: base.filePath,
      fileName: base.fileName,
      vendorName: _optionalString(
            structured,
            <String>['vendorName', 'vendor_name'],
          ) ??
          base.vendorName,
      vendorVoen: _optionalString(
            structured,
            <String>['vendorVoen', 'vendor_voen'],
          ) ??
          base.vendorVoen,
      invoiceNumber: _optionalString(
            structured,
            <String>['invoiceNumber', 'invoice_number'],
          ) ??
          base.invoiceNumber,
      issueDate: _optionalDateTime(
            _firstValue(structured, <String>['issueDate', 'issue_date']),
          ) ??
          base.issueDate,
      dueDate: _optionalDateTime(
            _firstValue(structured, <String>['dueDate', 'due_date']),
          ) ??
          base.dueDate,
      subtotal: _optionalDouble(structured, <String>['subtotal']) ??
          base.subtotal,
      vatAmount: _optionalDouble(
            structured,
            <String>['vatAmount', 'vat_amount'],
          ) ??
          base.vatAmount,
      totalAmount: _optionalDouble(
            structured,
            <String>['totalAmount', 'total_amount'],
          ) ??
          base.totalAmount,
      createdAt: base.createdAt,
      currency: _readString(
        structured,
        <String>['currency'],
        fallback: base.currency,
      ),
      status: DocumentStatus.completed,
      lineItems: _lineItems(
        _firstValue(structured, <String>['lineItems', 'line_items']),
      ),
      extractedData: ocrPayload,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'company_id': companyId,
      'file_path': filePath,
      'file_name': fileName,
      'vendor_name': vendorName,
      'vendor_voen': vendorVoen,
      'invoice_number': invoiceNumber,
      'issue_date': issueDate?.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
      'subtotal': subtotal,
      'vat_amount': vatAmount,
      'total_amount': totalAmount,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'currency': currency,
      'status': status.name,
      'line_items': lineItems.map(_itemToJson).toList(growable: false),
      'extracted_json': extractedData,
    };
  }

  Map<String, Object?> toSqflite() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'file_path': filePath,
      'file_name': fileName,
      'document_type': _documentType(filePath),
      'extracted_json': extractedData == null ? null : jsonEncode(extractedData),
      'vendor_name': vendorName,
      'vendor_voen': vendorVoen,
      'invoice_number': invoiceNumber,
      'issue_date': issueDate?.toUtc().toIso8601String(),
      'due_date': dueDate?.toUtc().toIso8601String(),
      'subtotal': subtotal,
      // Version 1/2 databases declared these legacy columns NOT NULL.
      'vat_amount': vatAmount ?? 0,
      'total_amount': totalAmount ?? 0,
      'currency': currency,
      'status': status.name,
      'line_items_json': jsonEncode(
        lineItems.map(_itemToJson).toList(growable: false),
      ),
      'created_at': (createdAt ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
    };
  }

  DocumentModel withStatus(DocumentStatus nextStatus) {
    return DocumentModel(
      id: id,
      companyId: companyId,
      filePath: filePath,
      fileName: fileName,
      vendorName: vendorName,
      vendorVoen: vendorVoen,
      invoiceNumber: invoiceNumber,
      issueDate: issueDate,
      dueDate: dueDate,
      subtotal: subtotal,
      vatAmount: vatAmount,
      totalAmount: totalAmount,
      currency: currency,
      status: nextStatus,
      lineItems: lineItems,
      extractedData: extractedData,
      createdAt: createdAt,
    );
  }

  /// Refreshes the structured section of the retained OCR payload after an
  /// accountant edits fields in the verification workspace.
  DocumentModel withVerificationData() {
    final Map<String, dynamic> payload = <String, dynamic>{
      ...?extractedData,
    };
    final Map<String, dynamic> structured = <String, dynamic>{
      ...?_asMap(payload['structured']),
    };
    _writeOrRemove(structured, 'vendorName', vendorName);
    _writeOrRemove(structured, 'vendorVoen', vendorVoen);
    _writeOrRemove(structured, 'invoiceNumber', invoiceNumber);
    _writeOrRemove(
      structured,
      'issueDate',
      issueDate?.toUtc().toIso8601String(),
    );
    _writeOrRemove(
      structured,
      'dueDate',
      dueDate?.toUtc().toIso8601String(),
    );
    _writeOrRemove(structured, 'subtotal', subtotal);
    _writeOrRemove(structured, 'vatAmount', vatAmount);
    _writeOrRemove(structured, 'totalAmount', totalAmount);
    _writeOrRemove(structured, 'currency', currency);
    structured['lineItems'] = lineItems.map(_itemToJson).toList(growable: false);
    payload['structured'] = structured;
    payload['verified'] = true;
    payload['verifiedAt'] = DateTime.now().toUtc().toIso8601String();

    return DocumentModel(
      id: id,
      companyId: companyId,
      filePath: filePath,
      fileName: fileName,
      vendorName: vendorName,
      vendorVoen: vendorVoen,
      invoiceNumber: invoiceNumber,
      issueDate: issueDate,
      dueDate: dueDate,
      subtotal: subtotal,
      vatAmount: vatAmount,
      totalAmount: totalAmount,
      createdAt: createdAt,
      currency: currency,
      status: status,
      lineItems: lineItems,
      extractedData: payload,
    );
  }

  static void _writeOrRemove(
    Map<String, dynamic> values,
    String key,
    Object? value,
  ) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  static Map<String, dynamic> _itemToJson(InvoiceItemEntity item) {
    return <String, dynamic>{
      'id': item.id,
      'description': item.description,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'line_total': item.lineTotal,
      'vat_rate': item.vatRate,
    };
  }

  static List<InvoiceItemEntity> _lineItems(Object? value) {
    if (value is String) {
      value = _decodeJson(value);
    }
    if (value is! Iterable<Object?>) {
      return const <InvoiceItemEntity>[];
    }

    return value
        .map(_itemFromObject)
        .whereType<InvoiceItemEntity>()
        .toList(growable: false);
  }

  static InvoiceItemEntity? _itemFromObject(Object? value) {
    final Map<String, dynamic>? map = _asMap(value);
    if (map == null) {
      return null;
    }
    return InvoiceItemEntity(
      id: _readString(
        map,
        <String>['id'],
        fallback: '',
      ),
      description: _readString(
        map,
        <String>['description', 'name'],
        fallback: 'Unspecified item',
      ),
      quantity: _readDouble(
        map,
        <String>['quantity'],
        fallback: 1,
      ),
      unitPrice: _readDouble(
        map,
        <String>['unitPrice', 'unit_price'],
        fallback: 0,
      ),
      lineTotal: _readDouble(
        map,
        <String>['lineTotal', 'line_total'],
        fallback: 0,
      ),
      vatRate: _readDouble(
        map,
        <String>['vatRate', 'vat_rate'],
        fallback: 0,
      ),
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return <String, dynamic>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          entry.key.toString(): entry.value,
      };
    }
    if (value is String) {
      return _asMap(_decodeJson(value));
    }
    return null;
  }

  static Object? _decodeJson(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return value;
    }
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  static Object? _firstValue(
    Map<String, dynamic> values,
    List<String> keys,
  ) {
    for (final String key in keys) {
      if (values.containsKey(key)) {
        return values[key];
      }
    }
    return null;
  }

  static String _requiredString(
    Map<String, dynamic> values,
    List<String> keys,
  ) {
    final String? value = _optionalString(values, keys);
    if (value == null) {
      throw FormatException('Document field "${keys.join(' / ')}" is required.');
    }
    return value;
  }

  static String? _optionalString(
    Map<String, dynamic> values,
    List<String> keys,
  ) {
    final Object? value = _firstValue(values, keys);
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static String _readString(
    Map<String, dynamic> values,
    List<String> keys, {
    required String fallback,
  }) {
    return _optionalString(values, keys) ?? fallback;
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    final String normalized = value.trim();
    final DateTime? parsedIso = DateTime.tryParse(normalized);
    if (parsedIso != null) {
      return parsedIso;
    }

    final List<String> parts = normalized.split(RegExp(r'[./-]'));
    if (parts.length != 3) {
      return null;
    }
    final int? first = int.tryParse(parts[0]);
    final int? second = int.tryParse(parts[1]);
    final int? third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) {
      return null;
    }

    final int year;
    final int month;
    final int day;
    if (first > 31) {
      year = first;
      month = second;
      day = third;
    } else if (third > 31) {
      year = third;
      // Accept both day/month/year and month/day/year OCR output when the
      // second component makes the ordering unambiguous.
      if (second > 12 && first <= 12) {
        month = first;
        day = second;
      } else {
        month = second;
        day = first;
      }
    } else {
      return null;
    }

    if (year < 100 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  static double? _optionalDouble(
    Map<String, dynamic> values,
    List<String> keys,
  ) {
    final Object? value = _firstValue(values, keys);
    return _parseDouble(value);
  }

  static double? _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is! String) {
      return null;
    }

    String normalized = value.replaceAll(RegExp(r'\s+'), '');
    final int lastComma = normalized.lastIndexOf(',');
    final int lastDot = normalized.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      normalized = lastComma > lastDot
          ? normalized.replaceAll('.', '').replaceAll(',', '.')
          : normalized.replaceAll(',', '');
    } else if (lastComma >= 0) {
      final int decimals = normalized.length - lastComma - 1;
      normalized = decimals == 3
          ? normalized.replaceAll(',', '')
          : normalized.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  static double _readDouble(
    Map<String, dynamic> values,
    List<String> keys, {
    required double fallback,
  }) {
    return _optionalDouble(values, keys) ?? fallback;
  }

  static double? _rowDouble(Object? value) => _parseDouble(value);

  static String _requiredRowString(
    Map<String, Object?> row,
    String key,
  ) {
    final Object? value = row[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('Document SQLite field "$key" is required.');
  }

  static String _rowString(
    Map<String, Object?> row,
    String key, {
    required String fallback,
  }) {
    final Object? value = row[key];
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }

  static String? _optionalRowString(Map<String, Object?> row, String key) {
    final Object? value = row[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  static DocumentStatus _status(Object? value) {
    final String? name = value is String ? value : null;
    for (final DocumentStatus status in DocumentStatus.values) {
      if (status.name == name) {
        return status;
      }
    }
    return DocumentStatus.pending;
  }

  static String _documentType(String filePath) {
    final String extension = p.extension(filePath).replaceFirst('.', '');
    return extension.isEmpty ? 'document' : extension.toLowerCase();
  }
}
