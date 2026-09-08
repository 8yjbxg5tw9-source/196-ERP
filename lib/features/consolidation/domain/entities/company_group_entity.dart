import 'package:equatable/equatable.dart';

/// A group of companies whose books are consolidated into one report.
class CompanyGroupEntity extends Equatable {
  const CompanyGroupEntity({
    required this.id,
    required this.groupName,
    required this.parentCompanyId,
    this.subsidiaryCompanyIds = const <String>[],
    this.createdAt,
  });

  final String id;
  final String groupName;
  final String parentCompanyId;
  final List<String> subsidiaryCompanyIds;
  final DateTime? createdAt;

  /// Every company participating in the consolidation, parent first.
  List<String> get memberCompanyIds =>
      <String>[parentCompanyId, ...subsidiaryCompanyIds];

  CompanyGroupEntity copyWith({
    String? id,
    String? groupName,
    String? parentCompanyId,
    List<String>? subsidiaryCompanyIds,
    DateTime? createdAt,
  }) {
    return CompanyGroupEntity(
      id: id ?? this.id,
      groupName: groupName ?? this.groupName,
      parentCompanyId: parentCompanyId ?? this.parentCompanyId,
      subsidiaryCompanyIds: subsidiaryCompanyIds ?? this.subsidiaryCompanyIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        groupName,
        parentCompanyId,
        subsidiaryCompanyIds,
        createdAt,
      ];
}
