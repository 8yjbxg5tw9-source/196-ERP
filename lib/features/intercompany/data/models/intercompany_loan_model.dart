import '../../domain/entities/intercompany_loan_entity.dart';

/// SQLite mapping for the `intercompany_loans` table.
class IntercompanyLoanModel extends IntercompanyLoanEntity {
  const IntercompanyLoanModel({
    required super.id,
    required super.lenderCompanyId,
    required super.borrowerCompanyId,
    required super.principalAmount,
    required super.interestRate,
    required super.agreementDate,
    required super.maturityDate,
    super.compoundingFrequency,
    super.withholdingTaxRate,
    super.outstandingBalance,
    super.status,
    super.createdAt,
  });

  factory IntercompanyLoanModel.fromMap(Map<String, Object?> map) {
    return IntercompanyLoanModel(
      id: map['id']?.toString() ?? '',
      lenderCompanyId: map['lender_company_id']?.toString() ?? '',
      borrowerCompanyId: map['borrower_company_id']?.toString() ?? '',
      principalAmount: _double(map['principal_amount']),
      interestRate: _double(map['interest_rate']),
      agreementDate: _date(map['agreement_date']),
      maturityDate: _date(map['maturity_date']),
      compoundingFrequency: _frequency(map['compounding_frequency']),
      withholdingTaxRate: _double(map['withholding_tax_rate']),
      outstandingBalance: _double(map['outstanding_balance']),
      status: _status(map['status']),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'lender_company_id': lenderCompanyId,
      'borrower_company_id': borrowerCompanyId,
      'principal_amount': principalAmount,
      'interest_rate': interestRate,
      'agreement_date': agreementDate.toUtc().toIso8601String(),
      'maturity_date': maturityDate.toUtc().toIso8601String(),
      'compounding_frequency': compoundingFrequency.name,
      'withholding_tax_rate': withholdingTaxRate,
      'outstanding_balance': outstandingBalance,
      'status': status.name,
      'created_at': (createdAt ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
    };
  }

  static double _double(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _date(Object? value) =>
      DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now().toUtc();

  static CompoundingFrequency _frequency(Object? value) {
    for (final CompoundingFrequency frequency
        in CompoundingFrequency.values) {
      if (frequency.name == value?.toString()) {
        return frequency;
      }
    }
    return CompoundingFrequency.simple;
  }

  static LoanStatus _status(Object? value) {
    for (final LoanStatus status in LoanStatus.values) {
      if (status.name == value?.toString()) {
        return status;
      }
    }
    return LoanStatus.active;
  }
}
