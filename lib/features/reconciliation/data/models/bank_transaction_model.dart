import '../../domain/entities/bank_transaction_entity.dart';

class BankTransactionModel extends BankTransactionEntity {
  const BankTransactionModel({
    required super.id,
    required super.companyId,
    required super.transactionDate,
    required super.description,
    required super.amount,
    required super.type,
    super.counterpartyName,
    super.counterpartyVoen,
    super.referenceCode,
    super.matchedDocumentId,
    super.matchConfidence,
    super.status,
    this.category = 'bank_statement',
  });

  final String category;

  factory BankTransactionModel.fromEntity(
    BankTransactionEntity entity, {
    String category = 'bank_statement',
  }) {
    return BankTransactionModel(
      id: entity.id,
      companyId: entity.companyId,
      transactionDate: entity.transactionDate,
      counterpartyName: entity.counterpartyName,
      counterpartyVoen: entity.counterpartyVoen,
      referenceCode: entity.referenceCode,
      description: entity.description,
      amount: entity.amount,
      type: entity.type,
      matchedDocumentId: entity.matchedDocumentId,
      matchConfidence: entity.matchConfidence,
      status: entity.status,
      category: category,
    );
  }

  factory BankTransactionModel.fromMap(Map<String, Object?> map) {
    final String dateValue = _stringValue(map['date']);
    final DateTime? date = DateTime.tryParse(dateValue);
    if (date == null) {
      throw FormatException('Invalid transaction date for ${map['id']}.');
    }

    final double rawConfidence = _numberValue(map['match_confidence']) ?? 0;
    final double confidence = rawConfidence.isFinite
        ? rawConfidence.clamp(0, 1).toDouble()
        : 0;
    final String? matchedDocumentId = _nullableString(map['document_id']);
    final bool reconciled = _boolValue(map['reconciled']);
    final String statusValue = _stringValue(map['match_status']).toLowerCase();
    final MatchStatus status = statusValue == MatchStatus.reconciled.name ||
            reconciled
        ? MatchStatus.reconciled
        : statusValue == MatchStatus.suggested.name
            ? MatchStatus.suggested
            : MatchStatus.unmatched;

    return BankTransactionModel(
      id: _stringValue(map['id']),
      companyId: _stringValue(map['company_id']),
      transactionDate: date.toUtc(),
      counterpartyName: _nullableString(map['counterparty_name']),
      counterpartyVoen: _nullableString(map['counterparty_voen']),
      referenceCode: _nullableString(map['reference_code']),
      description: _stringValue(map['description']),
      amount: (_numberValue(map['amount']) ?? 0).abs(),
      type: _typeFromValue(map['transaction_type']),
      matchedDocumentId: matchedDocumentId,
      matchConfidence: confidence,
      status: status,
      category: _stringValue(map['category'], fallback: 'bank_statement'),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'document_id': matchedDocumentId,
      'date': transactionDate.toUtc().toIso8601String(),
      'description': description,
      'amount': amount,
      'category': category,
      'counterparty_name': counterpartyName,
      'counterparty_voen': counterpartyVoen,
      'reference_code': referenceCode,
      'transaction_type': type.name,
      'match_confidence': matchConfidence,
      'match_status': status.name,
      'reconciled': status == MatchStatus.reconciled ? 1 : 0,
    };
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    return value?.toString() ?? fallback;
  }

  static String? _nullableString(Object? value) {
    final String text = _stringValue(value).trim();
    return text.isEmpty ? null : text;
  }

  static double? _numberValue(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  static bool _boolValue(Object? value) {
    return value == 1 || value == true || value?.toString() == 'true';
  }

  static BankTransactionType _typeFromValue(Object? value) {
    return value?.toString().toLowerCase() == BankTransactionType.credit.name
        ? BankTransactionType.credit
        : BankTransactionType.debit;
  }
}
