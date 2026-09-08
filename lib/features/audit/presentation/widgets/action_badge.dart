import 'package:flutter/material.dart';

import '../../domain/entities/audit_log_entity.dart';

/// Color-coded chip summarizing an audit action.
///
/// Green = create, blue = update, red = delete/export, amber = login/logout,
/// purple = backup/restore & tax submission.
class ActionBadge extends StatelessWidget {
  const ActionBadge({required this.action, super.key});

  final AuditAction action;

  @override
  Widget build(BuildContext context) {
    final Color color = _colorOf(action);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        action.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Color _colorOf(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return const Color(0xFF059669);
      case AuditAction.update:
        return const Color(0xFF2563EB);
      case AuditAction.delete:
      case AuditAction.export:
        return const Color(0xFFE11D48);
      case AuditAction.login:
      case AuditAction.logout:
        return const Color(0xFFD97706);
      case AuditAction.backupRestore:
      case AuditAction.taxSubmit:
        return const Color(0xFF7C3AED);
      case AuditAction.systemError:
        return const Color(0xFF6B7280);
    }
  }
}
