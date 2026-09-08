import 'dart:io';

import 'package:intl/intl.dart';

import '../../domain/entities/bank_transaction_entity.dart';

/// Unified contract implemented by each supported bank export format.
abstract interface class StatementParser {
  bool supports(String fileName);

  Future<List<BankTransactionEntity>> parse(File file, String companyId);
}

class StatementParserException extends FormatException {
  const StatementParserException(super.message);
}

/// Shared header mapping and scalar conversion for tabular bank statements.
abstract final class StatementRowMapper {
  static List<BankTransactionEntity> mapRows(
    List<List<Object?>> rows,
    String companyId, {
    required String sourcePrefix,
    bool skipWhenHeaderMissing = false,
  }) {
    final int headerIndex = _findHeaderIndex(rows);
    if (headerIndex < 0) {
      if (skipWhenHeaderMissing) {
        return const <BankTransactionEntity>[];
      }
      throw const StatementParserException(
        'The statement does not contain recognizable transaction headers.',
      );
    }

    final List<String> headers = rows[headerIndex]
        .map(_cellText)
        .map(_normalizeHeader)
        .toList(growable: false);
    final _ColumnIndexes columns = _ColumnIndexes.fromHeaders(headers);
    if (columns.date == null ||
        (columns.amount == null &&
            columns.debit == null &&
            columns.credit == null)) {
      throw const StatementParserException(
        'The statement needs a date and amount, debit, or credit column.',
      );
    }

    final int importSeed = DateTime.now().toUtc().microsecondsSinceEpoch;
    final List<BankTransactionEntity> transactions =
        <BankTransactionEntity>[];
    for (int rowIndex = headerIndex + 1; rowIndex < rows.length; rowIndex++) {
      final List<Object?> row = rows[rowIndex];
      if (row.every((Object? value) => _cellText(value).trim().isEmpty)) {
        continue;
      }

      final DateTime? date = parseDate(_valueAt(row, columns.date));
      if (date == null) {
        throw StatementParserException(
          'Row ${rowIndex + 1} has an invalid transaction date.',
        );
      }

      final double? debit = parseAmount(_valueAt(row, columns.debit));
      final double? credit = parseAmount(_valueAt(row, columns.credit));
      final double? amountValue = parseAmount(_valueAt(row, columns.amount));
      final BankTransactionType? explicitType = _parseType(
        _valueAt(row, columns.type),
      );

      final BankTransactionType type;
      final double amount;
      if (credit != null && credit != 0) {
        type = BankTransactionType.credit;
        amount = credit.abs();
      } else if (debit != null && debit != 0) {
        type = BankTransactionType.debit;
        amount = debit.abs();
      } else if (amountValue != null) {
        type = explicitType ??
            (amountValue < 0
                ? BankTransactionType.debit
                : BankTransactionType.credit);
        amount = amountValue.abs();
      } else {
        throw StatementParserException(
          'Row ${rowIndex + 1} has no debit, credit, or amount value.',
        );
      }

      final String? counterpartyName = _nullableCell(
        _valueAt(row, columns.counterparty),
      );
      final String? counterpartyVoen = _nullableCell(
        _valueAt(row, columns.voen),
      );
      final String? referenceCode = _nullableCell(
        _valueAt(row, columns.reference),
      );
      final String description = _nullableCell(
            _valueAt(row, columns.description),
          ) ??
          referenceCode ??
          counterpartyName ??
          'Bank transaction';

      transactions.add(
        BankTransactionEntity(
          id: '$sourcePrefix-$importSeed-$rowIndex',
          companyId: companyId,
          transactionDate: date,
          counterpartyName: counterpartyName,
          counterpartyVoen: counterpartyVoen,
          referenceCode: referenceCode,
          description: description,
          amount: amount,
          type: type,
        ),
      );
    }
    return transactions;
  }

  static bool hasHeader(List<Object?> row) {
    final List<String> headers = row.map(_cellText).map(_normalizeHeader).toList();
    return _hasDateHeader(headers) &&
        (_hasAny(headers, _amountHeaders) ||
            _hasAny(headers, _debitHeaders) ||
            _hasAny(headers, _creditHeaders));
  }

  static DateTime? parseDate(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is DateTime) {
      return raw.toUtc();
    }
    if (raw is num && raw.isFinite) {
      final DateTime excelEpoch = DateTime.utc(1899, 12, 30);
      return excelEpoch.add(Duration(milliseconds: (raw * 86400000).round()));
    }

    final String value = _cellText(raw).trim();
    if (value.isEmpty) {
      return null;
    }
    final DateTime? isoDate = DateTime.tryParse(value);
    if (isoDate != null) {
      return isoDate.toUtc();
    }
    const List<String> formats = <String>[
      'dd.MM.yyyy',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd.MM.yy',
      'dd/MM/yy',
    ];
    for (final String format in formats) {
      try {
        return DateFormat(format).parseStrict(value).toUtc();
      } on FormatException {
        // Try the next bank-specific date format.
      }
    }
    return null;
  }

  static double? parseAmount(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      final double value = raw.toDouble();
      return value.isFinite ? value : null;
    }

    String value = _cellText(raw).trim();
    if (value.isEmpty || value == '-') {
      return null;
    }
    bool negative = false;
    if (value.startsWith('(') && value.endsWith(')')) {
      negative = true;
      value = value.substring(1, value.length - 1);
    }
    value = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (value.isEmpty) {
      return null;
    }

    final int commaIndex = value.lastIndexOf(',');
    final int dotIndex = value.lastIndexOf('.');
    if (commaIndex >= 0 && dotIndex >= 0) {
      if (commaIndex > dotIndex) {
        value = value.replaceAll('.', '').replaceFirst(',', '.');
      } else {
        value = value.replaceAll(',', '');
      }
    } else if (commaIndex >= 0) {
      final int decimals = value.length - commaIndex - 1;
      value = decimals <= 2
          ? value.replaceFirst(',', '.')
          : value.replaceAll(',', '');
    }

    final double? parsed = double.tryParse(value);
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return negative ? -parsed.abs() : parsed;
  }

  static String _cellText(Object? value) {
    if (value == null) {
      return '';
    }
    return value is String ? value : value.toString();
  }

  static String? _nullableCell(Object? value) {
    final String text = _cellText(value).trim();
    return text.isEmpty ? null : text;
  }

  static Object? _valueAt(List<Object?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return null;
    }
    return row[index];
  }

  static int _findHeaderIndex(List<List<Object?>> rows) {
    for (int index = 0; index < rows.length && index < 30; index++) {
      if (hasHeader(rows[index])) {
        return index;
      }
    }
    return -1;
  }

  static BankTransactionType? _parseType(Object? raw) {
    final String value = _normalizeHeader(_cellText(raw));
    if (value.contains('credit') ||
        value == 'cr' ||
        value.contains('incoming') ||
        value.contains('deposit')) {
      return BankTransactionType.credit;
    }
    if (value.contains('debit') ||
        value == 'dr' ||
        value.contains('outgoing') ||
        value.contains('withdrawal')) {
      return BankTransactionType.debit;
    }
    return null;
  }

  static String _normalizeHeader(String value) {
    String normalized = value.replaceAll('\ufeff', '').trim().toLowerCase();
    const Map<String, String> replacements = <String, String>{
      'ə': 'e',
      'ı': 'i',
      'ö': 'o',
      'ü': 'u',
      'ş': 's',
      'ç': 'c',
      'ğ': 'g',
    };
    replacements.forEach((String from, String to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static bool _hasDateHeader(List<String> headers) {
    return _hasAny(headers, _dateHeaders);
  }

  static bool _hasAny(List<String> headers, Set<String> aliases) {
    return headers.any(
      (String header) => aliases.any(
        (String alias) => header == alias || header.contains(alias),
      ),
    );
  }
}

class _ColumnIndexes {
  const _ColumnIndexes({
    this.date,
    this.counterparty,
    this.voen,
    this.debit,
    this.credit,
    this.amount,
    this.description,
    this.reference,
    this.type,
  });

  factory _ColumnIndexes.fromHeaders(List<String> headers) {
    int? find(Set<String> aliases) {
      for (int index = 0; index < headers.length; index++) {
        if (aliases.any(
            (String alias) =>
                headers[index] == alias || headers[index].contains(alias))) {
          return index;
        }
      }
      return null;
    }

    return _ColumnIndexes(
      date: find(_dateHeaders),
      counterparty: find(_counterpartyHeaders),
      voen: find(_voenHeaders),
      debit: find(_debitHeaders),
      credit: find(_creditHeaders),
      amount: find(_amountHeaders),
      description: find(_descriptionHeaders),
      reference: find(_referenceHeaders),
      type: find(_typeHeaders),
    );
  }

  final int? date;
  final int? counterparty;
  final int? voen;
  final int? debit;
  final int? credit;
  final int? amount;
  final int? description;
  final int? reference;
  final int? type;
}

const Set<String> _dateHeaders = <String>{
  'date',
  'transactiondate',
  'valuedate',
  'bookingdate',
  'operationdate',
  'tarix',
  'emeliyyattarixi',
};

const Set<String> _counterpartyHeaders = <String>{
  'counterparty',
  'counterpartyname',
  'beneficiary',
  'payee',
  'payer',
  'sender',
  'receiver',
  'name',
  'merchant',
  'qarshiteref',
  'qarsiteref',
  'alici',
  'odyen',
};

const Set<String> _voenHeaders = <String>{
  'voen',
  'ven',
  'tin',
  'taxid',
  'taxidentificationnumber',
  'voentin',
};

const Set<String> _debitHeaders = <String>{
  'debit',
  'debitamount',
  'withdrawal',
  'withdrawals',
  'outgoing',
  'debet',
  'dr',
};

const Set<String> _creditHeaders = <String>{
  'credit',
  'creditamount',
  'deposit',
  'incoming',
  'inflow',
  'kredit',
  'cr',
};

const Set<String> _amountHeaders = <String>{
  'amount',
  'sum',
  'total',
  'balancechange',
  'mebleg',
};

const Set<String> _descriptionHeaders = <String>{
  'description',
  'details',
  'detail',
  'narrative',
  'purpose',
  'transactiondetails',
  'aciklama',
  'izah',
  'teyinat',
  'emeliyyat',
};

const Set<String> _referenceHeaders = <String>{
  'reference',
  'ref',
  'referencecode',
  'invoice',
  'invoicenumber',
  'documentnumber',
  'transactionid',
  'operationid',
};

const Set<String> _typeHeaders = <String>{
  'type',
  'transactiontype',
  'crdr',
  'creditdebit',
};
