import 'package:equatable/equatable.dart';

/// The five access tiers enforced across the application.
///
/// Ordering is deliberately from most to least privileged so role checks can
/// use direct comparisons when a hierarchy is ever required.
enum UserRole {
  admin,
  chiefAccountant,
  juniorAccountant,
  auditor,
  clientViewer,
}

extension UserRoleLabel on UserRole {
  /// Human-readable label used by the login screen, user menu, and badges.
  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.chiefAccountant => 'Chief Accountant',
        UserRole.juniorAccountant => 'Junior Accountant',
        UserRole.auditor => 'Auditor',
        UserRole.clientViewer => 'Client (View-Only)',
      };
}

/// A locally authenticated workspace member.
class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.companyIds = const <String>[],
  });

  final String id;
  final String username;
  final String email;
  final String fullName;
  final UserRole role;
  final List<String> companyIds;
  final DateTime createdAt;

  UserEntity copyWith({
    String? id,
    String? username,
    String? email,
    String? fullName,
    UserRole? role,
    List<String>? companyIds,
    DateTime? createdAt,
  }) {
    return UserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      companyIds: companyIds ?? this.companyIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        username,
        email,
        fullName,
        role,
        companyIds,
        createdAt,
      ];
}
