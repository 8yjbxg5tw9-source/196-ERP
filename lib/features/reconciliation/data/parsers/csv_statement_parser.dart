import 'dart:io';

import 'package:csv/csv.dart';

import '../../domain/entities/bank_transaction_entity.dart';
import 'statement_parser.dart';

class CsvStatementParser implements StatementParser {
  const CsvStatementParser();

  @override
  bool supports(String fileName) {
    return fileName.toLowerCase().endsWith('.csv');
  }

  @override
  Future<List<BankTransactionEntity>> parse(
    File file,
    String companyId,
  ) async {
    final String contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      throw const StatementParserException('The CSV statement is empty.');
    }

    final String delimiter = _detectDelimiter(contents);
    final Csv converter = Csv(
      fieldDelimiter: delimiter,
      dynamicTyping: false,
    );
    final List<List<dynamic>> parsed = converter.decode(contents);
    final List<List<Object?>> rows = <List<Object?>>[
      for (final List<dynamic> row in parsed) row.cast<Object?>(),
    ];

    return StatementRowMapper.mapRows(
      rows,
      companyId,
      sourcePrefix: 'csv-bank',
    );
  }

  String _detectDelimiter(String contents) {
    final List<String> lines = contents
        .split(RegExp(r'\r?\n'))
        .where((String line) => line.trim().isNotEmpty)
        .take(10)
        .toList(growable: false);
    const List<String> candidates = <String>[',', ';', '\t', '|'];

    String selected = ',';
    int bestScore = 0;
    for (final String candidate in candidates) {
      final int score = lines.fold<int>(
        0,
        (int total, String line) => total + _countDelimiter(line, candidate),
      );
      if (score > bestScore) {
        bestScore = score;
        selected = candidate;
      }
    }
    return selected;
  }

  int _countDelimiter(String line, String delimiter) {
    bool quoted = false;
    int count = 0;
    for (int index = 0; index < line.length; index++) {
      final String character = line[index];
      if (character == '"') {
        quoted = !quoted;
      } else if (!quoted && character == delimiter) {
        count++;
      }
    }
    return count;
  }
}
