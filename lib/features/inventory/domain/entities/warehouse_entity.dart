import 'package:equatable/equatable.dart';

/// A physical or logical stock location belonging to a company.
class WarehouseEntity extends Equatable {
  const WarehouseEntity({
    required this.id,
    required this.companyId,
    required this.code,
    required this.name,
    this.location,
    this.isPrimary = false,
    this.createdAt,
  });

  final String id;
  final String companyId;
  final String code;
  final String name;
  final String? location;
  final bool isPrimary;
  final DateTime? createdAt;

  WarehouseEntity copyWith({
    String? id,
    String? companyId,
    String? code,
    String? name,
    Object? location = _unset,
    bool? isPrimary,
    DateTime? createdAt,
  }) {
    return WarehouseEntity(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      code: code ?? this.code,
      name: name ?? this.name,
      location: identical(location, _unset) ? this.location : location as String?,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props =>
      <Object?>[id, companyId, code, name, location, isPrimary, createdAt];
}

const Object _unset = Object();
