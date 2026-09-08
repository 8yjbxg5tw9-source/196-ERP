import 'package:equatable/equatable.dart';

/// A legal entity managed inside the active accounting workspace.
class CompanyEntity extends Equatable {
  const CompanyEntity({
    required this.id,
    required this.name,
    required this.voenTin,
    required this.taxType,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String voenTin;
  final String taxType;
  final DateTime createdAt;

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        voenTin,
        taxType,
        createdAt,
      ];
}
