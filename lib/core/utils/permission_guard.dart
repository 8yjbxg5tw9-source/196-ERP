import '../../features/auth/domain/entities/user_entity.dart';

/// Granular capabilities enforced across the application.
///
/// Feature widgets query the guard through [PermissionGuard] so destructive or
/// sensitive actions are hidden or disabled based on the active user's role.
enum AppPermission {
  viewDashboard,
  viewReports,
  viewLedger,
  viewDocuments,
  viewAuditLogs,
  uploadDocuments,
  createInvoice,
  editDrafts,
  approveDocuments,
  reconcile,
  exportReports,
  manageTaxSettings,
  deleteRecords,
  manageCompanies,
  manageUsers,
}

/// Static role → permission matrix.
///
/// Admin holds every capability; lower tiers are strict subsets. This keeps
/// the access rules in one auditable place rather than scattered through
/// feature code.
abstract final class PermissionMatrix {
  static const Set<AppPermission> _all = AppPermission.values;

  static const Map<UserRole, Set<AppPermission>> _matrix =
      <UserRole, Set<AppPermission>>{
    UserRole.admin: _all,
    UserRole.chiefAccountant: <AppPermission>{
      AppPermission.viewDashboard,
      AppPermission.viewReports,
      AppPermission.viewLedger,
      AppPermission.viewDocuments,
      AppPermission.viewAuditLogs,
      AppPermission.uploadDocuments,
      AppPermission.createInvoice,
      AppPermission.editDrafts,
      AppPermission.approveDocuments,
      AppPermission.reconcile,
      AppPermission.exportReports,
      AppPermission.manageTaxSettings,
      AppPermission.deleteRecords,
    },
    UserRole.juniorAccountant: <AppPermission>{
      AppPermission.viewDashboard,
      AppPermission.viewReports,
      AppPermission.viewLedger,
      AppPermission.viewDocuments,
      AppPermission.uploadDocuments,
      AppPermission.createInvoice,
      AppPermission.editDrafts,
    },
    UserRole.auditor: <AppPermission>{
      AppPermission.viewDashboard,
      AppPermission.viewReports,
      AppPermission.viewLedger,
      AppPermission.viewDocuments,
      AppPermission.viewAuditLogs,
    },
    UserRole.clientViewer: <AppPermission>{
      AppPermission.viewDashboard,
    },
  };

  /// The capabilities granted to [role].
  static Set<AppPermission> permissionsFor(UserRole role) {
    return _matrix[role] ?? const <AppPermission>{};
  }

  /// Whether [role] is allowed to perform [permission].
  static bool grants(UserRole role, AppPermission permission) {
    return permissionsFor(role).contains(permission);
  }
}

/// Central authorization predicate used by UI and BLoC layers.
abstract final class PermissionGuard {
  /// Returns `true` when [role] can execute [permission].
  static bool canExecute(UserRole role, AppPermission permission) {
    return PermissionMatrix.grants(role, permission);
  }
}
