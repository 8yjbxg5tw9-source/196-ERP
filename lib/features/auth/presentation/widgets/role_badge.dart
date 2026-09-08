import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../domain/entities/user_entity.dart';

/// Compact color-coded chip describing a user's access tier.
class RoleBadge extends StatelessWidget {
  const RoleBadge({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final Color color = _colorFor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        border: Border.all(color: color.withAlpha(120)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  static Color _colorFor(UserRole role) {
    return switch (role) {
      UserRole.admin => AppColors.rose,
      UserRole.chiefAccountant => AppColors.primary,
      UserRole.juniorAccountant => AppColors.success,
      UserRole.auditor => AppColors.warning,
      UserRole.clientViewer => AppColors.slate,
    };
  }
}
