import 'package:equatable/equatable.dart';

/// Interest compounding convention for an intercompany loan.
enum CompoundingFrequency { simple, monthly, annually }

extension CompoundingFrequencyLabel on CompoundingFrequency {
  String get label => switch (this) {
        CompoundingFrequency.simple => 'Simple',
        CompoundingFrequency.monthly => 'Monthly',
        CompoundingFrequency.annually => 'Annually',
      };
}

/// Lifecycle state of an intercompany loan agreement.
enum LoanStatus { active, settled, defaulted }

extension LoanStatusLabel on LoanStatus {
  String get label => switch (this) {
        LoanStatus.active => 'Active',
        LoanStatus.settled => 'Settled',
        LoanStatus.defaulted => 'Defaulted',
      };
}

/// An intercompany loan agreement between two group entities.
class IntercompanyLoanEntity extends Equatable {
  const IntercompanyLoanEntity({
    required this.id,
    required this.lenderCompanyId,
    required this.borrowerCompanyId,
    required this.principalAmount,
    required this.interestRate,
    required this.agreementDate,
    required this.maturityDate,
    this.compoundingFrequency = CompoundingFrequency.simple,
    this.withholdingTaxRate = 0,
    this.outstandingBalance = 0,
    this.status = LoanStatus.active,
    this.createdAt,
  });

  final String id;
  final String lenderCompanyId;
  final String borrowerCompanyId;
  final double principalAmount;

  /// Annual percentage rate (e.g. 12 = 12%).
  final double interestRate;
  final DateTime agreementDate;
  final DateTime maturityDate;
  final CompoundingFrequency compoundingFrequency;

  /// Ödəmə mənbəyində tutulan vergi (WHT), as a percentage (e.g. 10 = 10%).
  final double withholdingTaxRate;
  final double outstandingBalance;
  final LoanStatus status;
  final DateTime? createdAt;

  IntercompanyLoanEntity copyWith({
    String? id,
    String? lenderCompanyId,
    String? borrowerCompanyId,
    double? principalAmount,
    double? interestRate,
    DateTime? agreementDate,
    DateTime? maturityDate,
    CompoundingFrequency? compoundingFrequency,
    double? withholdingTaxRate,
    double? outstandingBalance,
    LoanStatus? status,
    DateTime? createdAt,
  }) {
    return IntercompanyLoanEntity(
      id: id ?? this.id,
      lenderCompanyId: lenderCompanyId ?? this.lenderCompanyId,
      borrowerCompanyId: borrowerCompanyId ?? this.borrowerCompanyId,
      principalAmount: principalAmount ?? this.principalAmount,
      interestRate: interestRate ?? this.interestRate,
      agreementDate: agreementDate ?? this.agreementDate,
      maturityDate: maturityDate ?? this.maturityDate,
      compoundingFrequency: compoundingFrequency ?? this.compoundingFrequency,
      withholdingTaxRate: withholdingTaxRate ?? this.withholdingTaxRate,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        lenderCompanyId,
        borrowerCompanyId,
        principalAmount,
        interestRate,
        agreementDate,
        maturityDate,
        compoundingFrequency,
        withholdingTaxRate,
        outstandingBalance,
        status,
        createdAt,
      ];
}
