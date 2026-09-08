import 'dart:io';

import '../../domain/entities/bank_transaction_entity.dart';
import 'statement_parser.dart';

/// Parser for SWIFT MT940 exports, including bank TXT files containing :61:
/// transaction records and optional :86: narrative records.
class Mt940StatementParser implements StatementParser {
  const Mt940StatementParser();

  @override
  bool supports(String fileName) {
    final String lower = fileName.toLowerCase();
    return lower.endsWith('.mt940') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.sta');
  }

  @override
  Future<List<BankTransactionEntity>> parse(
    File file,
    String companyId,
  ) async {
    final String contents = await file.readAsString();
    final List<_PendingMt940Transaction> pending = <_PendingMt940Transaction>[];
    _PendingMt940Transaction? current;
    int index = 0;

    for (final String line in contents.split(RegExp(r'\r?\n'))) {
      if (line.startsWith(':61:')) {
        if (current != null) {
          pending.add(current);
        }
        current = _parseTransaction(line.substring(4), index++);
      } else if (line.startsWith(':86:') && current != null) {
        current.narrative.add(line.substring(4));
      } else if (current != null &&
          line.isNotEmpty &&
          !line.startsWith(':') &&
          !line.startsWith('-')) {
        current.narrative.add(line);
      }
    }
    if (current != null) {
      pending.add(current);
    }

    if (pending.isEmpty) {
      throw const StatementParserException(
        'The MT940 statement does not contain any :61: transactions.',
      );
    }

    final int importSeed = DateTime.now().toUtc().microsecondsSinceEpoch;
    return <BankTransactionEntity>[
      for (final _PendingMt940Transaction item in pending)
        BankTransactionEntity(
          id: 'mt940-bank-$importSeed-${item.index}',
          companyId: companyId,
          transactionDate: item.date,
          counterpartyName: item.counterpartyName,
          counterpartyVoen: item.counterpartyVoen,
          referenceCode: item.referenceCode,
          description: item.narrative.isEmpty
              ? item.referenceCode ?? 'MT940 transaction'
              : item.narrative.join(' ').trim(),
          amount: item.amount,
          type: item.type,
        ),
    ];
  }

  _PendingMt940Transaction _parseTransaction(String value, int index) {
    final RegExpMatch? match = RegExp(
      r'^(\d{6})(?:\d{4})?([CD])R?([0-9]+(?:[,.][0-9]+)?)(?:N([A-Z0-9]{3,4}))?(.*)$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw StatementParserException('Invalid MT940 :61: record: $value');
    }

    final DateTime date = _parseMt940Date(match.group(1)!);
    final double? amount = StatementRowMapper.parseAmount(match.group(3));
    if (amount == null) {
      throw StatementParserException('Invalid amount in MT940 :61: record.');
    }
    final String? reference = match.group(5)?.trim().isEmpty == true
        ? null
        : match.group(5)?.trim();
    final String? transactionCode = match.group(4)?.trim().isEmpty == true
        ? null
        : match.group(4)?.trim();

    return _PendingMt940Transaction(
      index: index,
      date: date,
      amount: amount.abs(),
      type: match.group(2) == 'C'
          ? BankTransactionType.credit
          : BankTransactionType.debit,
      referenceCode: reference ?? transactionCode,
    );
  }

  DateTime _parseMt940Date(String value) {
    final int twoDigitYear = int.parse(value.substring(0, 2));
    final int year = twoDigitYear >= 70 ? 1900 + twoDigitYear : 2000 + twoDigitYear;
    return DateTime.utc(
      year,
      int.parse(value.substring(2, 4)),
      int.parse(value.substring(4, 6)),
    );
  }
}

class _PendingMt940Transaction {
  _PendingMt940Transaction({
    required this.index,
    required this.date,
    required this.amount,
    required this.type,
    required this.referenceCode,
    this.counterpartyName,
    this.counterpartyVoen,
  });

  final int index;
  final DateTime date;
  final double amount;
  final BankTransactionType type;
  final String? referenceCode;
  final String? counterpartyName;
  final String? counterpartyVoen;
  final List<String> narrative = <String>[];
}
