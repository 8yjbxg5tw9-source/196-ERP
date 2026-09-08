import 'package:equatable/equatable.dart';

/// Statutory employment contract type.
enum EmploymentType { fullTime, partTime, contractor }

extension EmploymentTypeLabel on EmploymentType {
  String get label => switch (this) {
        EmploymentType.fullTime => 'Full-time',
        EmploymentType.partTime => 'Part-time',
        EmploymentType.contractor => 'Contractor',
      };
}

/// Sector classification that drives the statutory tax brackets.
enum SectorType { oilGasPrivate, nonOilGasPrivate, stateBudget }

extension SectorTypeLabel on SectorType {
  String get label => switch (this) {
        SectorType.oilGasPrivate => 'Oil & gas private',
        SectorType.nonOilGasPrivate => 'Non-oil private',
        SectorType.stateBudget => 'State budget',
      };
}

/// Employee master data for the payroll engine.
class EmployeeEntity extends Equatable {
  const EmployeeEntity({
    required this.id,
    required this.companyId,
    required this.fullName,
    required this.pin,
    this.position = '',
    required this.baseSalary,
    required this.employmentType,
    required this.sectorType,
    this.bankAccountIban,
    required this.startDate,
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String fullName;
  final String pin;
  final String position;
  final double baseSalary;
  final EmploymentType employmentType;
  final SectorType sectorType;
  final String? bankAccountIban;
  final DateTime startDate;
  final bool isActive;
  final DateTime? createdAt;

  EmployeeEntity copyWith({
    String? id,
    String? companyId,
    String? fullName,
    String? pin,
    String? position,
    double? baseSalary,
    EmploymentType? employmentType,
    SectorType? sectorType,
    Object? bankAccountIban = _unset,
    DateTime? startDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return EmployeeEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      fullName: fullName ?? this.fullName,
      pin: pin ?? this.pin,
      position: position ?? this.position,
      baseSalary: baseSalary ?? this.baseSalary,
      employmentType: employmentType ?? this.employmentType,
      sectorType: sectorType ?? this.sectorType,
      bankAccountIban: identical(bankAccountIban, _unset)
          ? this.bankAccountIban
          : bankAccountIban as String?,
      startDate: startDate ?? this.startDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        fullName,
        pin,
        position,
        baseSalary,
        employmentType,
        sectorType,
        bankAccountIban,
        startDate,
        isActive,
        createdAt,
      ];
}

const Object _unset = Object();
