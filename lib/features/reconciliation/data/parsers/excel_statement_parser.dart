import 'dart:io';

import 'package:excel/excel.dart';

import '../../domain/entities/bank_transaction_entity.dart';
import 'statement_parser.dart';

class ExcelStatementParser implements StatementParser {
  const ExcelStatementParser();

  @override
  bool supports(String fileName) {
    final String lower = fileName.toLowerCase();
    return lower.endsWith('.xlsx') || lower.endsWith('.xls');
  }

  @override
  Future<List<BankTransactionEntity>> parse(
    File file,
    String companyId,
  ) async {
    final Excel workbook = Excel.decodeBytes(await file.readAsBytes());
    final List<BankTransactionEntity> transactions =
        <BankTransactionEntity>[];

    for (final String sheetName in workbook.tables.keys) {
      final Sheet? sheet = workbook.tables[sheetName];
      if (sheet == null || sheet.rows.isEmpty) {
        continue;
      }
      final List<List<Object?>> rows = <List<Object?>>[
        for (final List<Data?> row in sheet.rows)
          <Object?>[for (final Data? cell in row) _cellValue(cell)],
      ];
      transactions.addAll(
        StatementRowMapper.mapRows(
          rows,
          companyId,
          sourcePrefix: 'excel-${_safeName(sheetName)}',
          skipWhenHeaderMissing: true,
        ),
      );
    }

    if (transactions.isEmpty) {
      throw const StatementParserException(
        'No transaction sheet with recognizable headers was found.',
      );
    }
    return transactions;
  }

  String _safeName(String sheetName) {
    final String value = sheetName.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '-',
        );
    return value.isEmpty ? 'sheet' : value;
  }

  Object? _cellValue(Data? cell) {
    final CellValue? value = cell?.value;
    return switch (value) {
      null => null,
      TextCellValue text => _textSpanValue(text.value),
      IntCellValue integer => integer.value,
      DoubleCellValue decimal => decimal.value,
      BoolCellValue boolean => boolean.value,
      DateCellValue date => date.asDateTimeUtc(),
      DateTimeCellValue dateTime => dateTime.asDateTimeUtc(),
      FormulaCellValue formula => formula.formula,
      TimeCellValue time => time.toString(),
    };
  }

  String _textSpanValue(TextSpan span) {
    final String ownText = span.text ?? '';
    final String childText = (span.children ?? const <TextSpan>[])
        .map(_textSpanValue)
        .join();
    return '$ownText$childText';
  }
}
