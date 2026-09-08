import '../../domain/entities/employee_entity.dart';

/// SQLite mapping for the `employees` table.
class EmployeeModel extends EmployeeEntity {
  const EmployeeModel({
    required super.id,
    required super.companyId,
    required super.fullName,
    required super.pin,
    super.position = '',
    required super.baseSalary,
    required super.employmentType,
    required super.sectorType,
    super.bankAccountIban,
    required super.startDate,
    super.isActive = true,
    super.createdAt,
  });

  factory EmployeeModel.fromMap(Map<String, Object?> map) {
    return EmployeeModel(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      pin: map['pin']?.toString() ?? '',
      position: map['position']?.toString() ?? '',
      baseSalary: _doubleValue(map['base_salary']),
      employmentType: _enumValue(
        EmploymentType.values,
        map['employment_type'],
        EmploymentType.fullTime,
      ),
      sectorType: _enumValue(
        SectorType.values,
        map['sector_type'],
        SectorType.nonOilGasPrivate,
      ),
      bankAccountIban: _nullableString(map['bank_account_iban']),
      startDate:
          DateTime.tryParse(map['start_date']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isActive: (map['is_active'] ?? 1) == 1 ||
          map['is_active']?.toString() == 'true',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }

  factory EmployeeModel.fromEntity(EmployeeEntity entity) {
    return EmployeeModel(
      id: entity.id,
      companyId: entity.companyId,
      fullName: entity.fullName,
      pin: entity.pin,
      position: entity.position,
      baseSalary: entity.baseSalary,
      employmentType: entity.employmentType,
      sectorType: entity.sectorType,
      bankAccountIban: entity.bankAccountIban,
      startDate: entity.startDate,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'company_id': companyId,
      'full_name': fullName,
      'pin': pin,
      'position': position,
      'base_salary': baseSalary,
      'employment_type': employmentType.name,
      'sector_type': sectorType.name,
      'bank_account_iban': bankAccountIban,
      'start_date': startDate.toUtc().toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_at':
          createdAt?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
    };
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Object? value,
    T fallback,
  ) {
    return values.firstWhere(
      (T candidate) => candidate.name == value?.toString(),
      orElse: () => fallback,
    );
  }

  static String? _nullableString(Object? value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _doubleValue(Object? value) {
    if (value is num) {
      final double parsed = value.toDouble();
      return parsed.isFinite ? parsed : 0;
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
