import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/services/app_directory_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/backup_config_entity.dart';
import '../../domain/entities/backup_snapshot_entity.dart';
import '../bloc/backup_bloc.dart';
import '../bloc/backup_event.dart';
import '../bloc/backup_state.dart';

/// Disaster-recovery workspace: encrypted snapshots, schedule policy, and
/// point-in-time restore.
class DisasterRecoveryPage extends StatelessWidget {
  const DisasterRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return BlocProvider<BackupBloc>(
          create: (_) => sl<BackupBloc>()
            ..add(const LoadBackupHistoryEvent()),
          child: _DisasterRecoveryView(company: activeCompany),
        );
      },
    );
  }
}

class _DisasterRecoveryView extends StatefulWidget {
  const _DisasterRecoveryView({required this.company});

  final CompanyEntity? company;

  @override
  State<_DisasterRecoveryView> createState() => _DisasterRecoveryViewState();
}

class _DisasterRecoveryViewState extends State<_DisasterRecoveryView> {
  bool _busy = false;

  @override
  void didUpdateWidget(covariant _DisasterRecoveryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.company?.id != widget.company?.id) {
      context.read<BackupBloc>().add(const LoadBackupHistoryEvent());
    }
  }

  Future<void> _createBackup() async {
    final String? companyId = widget.company?.id;
    if (companyId == null) {
      return;
    }
    setState(() => _busy = true);
    context.read<BackupBloc>().add(CreateBackupEvent(companyId: companyId));
  }

  Future<void> _restoreFromFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select a FinAI Studio backup archive',
      type: FileType.any,
    );
    final String? path = picked?.files.single.path;
    if (path == null) {
      return;
    }
    final bool? confirmed = await _confirmRestore(context, path);
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.read<BackupBloc>().add(RestoreBackupEvent(path));
  }

  Future<bool?> _confirmRestore(BuildContext context, String path) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Restore from backup?'),
          content: Text(
            'The active database will be replaced by the snapshot at:\n\n$path\n\n'
            'This cannot be undone. Consider creating a fresh backup first.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disaster Recovery')),
      body: BlocConsumer<BackupBloc, BackupState>(
        listenWhen: (BackupState previous, BackupState current) =>
            current is BackupCreationSuccess ||
            current is RestoreSuccess ||
            current is BackupError ||
            (current is BackupHistoryLoaded && current.message != null),
        listener: (BuildContext context, BackupState state) {
          if (state is BackupCreationSuccess) {
            _busy = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Encrypted backup created: ${state.snapshot.fileName}',
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<BackupBloc>().add(const LoadBackupHistoryEvent());
          } else if (state is RestoreSuccess) {
            _busy = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Database restored successfully.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<BackupBloc>().add(const LoadBackupHistoryEvent());
          } else if (state is BackupError) {
            _busy = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is BackupHistoryLoaded && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (BuildContext context, BackupState state) {
          if (state is BackupLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is BackupError) {
            return _WorkspaceMessage(
              icon: Icons.error_outline_rounded,
              title: 'Backup unavailable',
              message: state.message,
            );
          }
          final BackupHistoryLoaded loaded = state is BackupHistoryLoaded
              ? state
              : const BackupHistoryLoaded(
                  snapshots: <BackupSnapshotEntity>[],
                  config: BackupConfigEntity(),
                );
          return _BackupBody(
            company: widget.company,
            snapshots: loaded.snapshots,
            config: loaded.config,
            busy: _busy,
            onCreate: _createBackup,
            onRestore: _restoreFromFile,
          );
        },
      ),
    );
  }
}

class _BackupBody extends StatelessWidget {
  const _BackupBody({
    required this.company,
    required this.snapshots,
    required this.config,
    required this.busy,
    required this.onCreate,
    required this.onRestore,
  });

  final CompanyEntity? company;
  final List<BackupSnapshotEntity> snapshots;
  final BackupConfigEntity config;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ControlsCard(
            company: company,
            busy: busy,
            onCreate: onCreate,
            onRestore: onRestore,
          ),
          const SizedBox(height: 12),
          _SnapshotGrid(
            snapshots: snapshots,
            onVerify: (String path) =>
                context.read<BackupBloc>().add(VerifySnapshotEvent(path)),
            onDelete: (String fileName) =>
                context.read<BackupBloc>().add(DeleteSnapshotEvent(fileName)),
          ),
          const SizedBox(height: 12),
          _ScheduleCard(config: config),
        ],
      ),
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({
    required this.company,
    required this.busy,
    required this.onCreate,
    required this.onRestore,
  });

  final CompanyEntity? company;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool enabled = company != null && !busy;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.shield_outlined, color: theme.colorScheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Encrypted backups',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AES-256-GCM archives with SHA-256 integrity verification '
                    'and point-in-time restore.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: enabled ? onRestore : null,
              icon: const Icon(Icons.settings_backup_restore_rounded, size: 17),
              label: const Text('Restore from file'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: enabled ? onCreate : null,
              icon: const Icon(Icons.lock_outline_rounded, size: 17),
              label: const Text('Create Encrypted Backup Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotGrid extends StatelessWidget {
  const _SnapshotGrid({
    required this.snapshots,
    required this.onVerify,
    required this.onDelete,
  });

  final List<BackupSnapshotEntity> snapshots;
  final ValueChanged<String> onVerify;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Snapshot History',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (snapshots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'No snapshots yet — create your first encrypted backup.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Snapshot')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Size'), numeric: true),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Integrity')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: <DataRow>[
                  for (final BackupSnapshotEntity snapshot in snapshots)
                    _snapshotRow(theme, snapshot, onVerify, onDelete),
                ],
              ),
            ),
        ],
      ),
    );
  }

  DataRow _snapshotRow(
    ThemeData theme,
    BackupSnapshotEntity snapshot,
    ValueChanged<String> onVerify,
    ValueChanged<String> onDelete,
  ) {
    return DataRow(
      cells: <DataCell>[
        DataCell(Text(snapshot.fileName)),
        DataCell(
          Text(AppFormatters.dateTime(snapshot.createdAt.toLocal())),
        ),
        DataCell(Text(_size(snapshot.fileSizeBytes))),
        DataCell(_TypeBadge(type: snapshot.backupType)),
        DataCell(_IntegrityBadge(snapshot: snapshot)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Verify SHA-256 integrity',
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                onPressed: () => onVerify(snapshot.filePath),
              ),
              IconButton(
                tooltip: 'Delete snapshot',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () => onDelete(snapshot.fileName),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final BackupType type;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = type == BackupType.scheduledAuto
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        type.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IntegrityBadge extends StatelessWidget {
  const _IntegrityBadge({required this.snapshot});

  final BackupSnapshotEntity snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (!snapshot.isVerified) {
      return Text(
        'Not checked',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.verified_rounded, size: 15, color: AppColors.success),
        const SizedBox(width: 4),
        Text(
          'Verified',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard({required this.config});

  final BackupConfigEntity config;

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  late bool _enabled = widget.config.autoBackupEnabled;
  late BackupSchedule _schedule = widget.config.schedule;
  late int _retention = widget.config.retentionCount;
  late final TextEditingController _retentionController = TextEditingController(
    text: '${widget.config.retentionCount}',
  );

  @override
  void didUpdateWidget(covariant _ScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      _enabled = widget.config.autoBackupEnabled;
      _schedule = widget.config.schedule;
      _retention = widget.config.retentionCount;
      _retentionController.text = '${widget.config.retentionCount}';
    }
  }

  @override
  void dispose() {
    _retentionController.dispose();
    super.dispose();
  }

  void _save() {
    context.read<BackupBloc>().add(
          UpdateBackupConfigEvent(
            BackupConfigEntity(
              autoBackupEnabled: _enabled,
              schedule: _schedule,
              retentionCount: _retention,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outline.withAlpha(90)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Automated Backup Schedule',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save schedule'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable automatic backups'),
              value: _enabled,
              onChanged: (bool value) => setState(() => _enabled = value),
            ),
            DropdownButtonFormField<BackupSchedule>(
              value: _schedule,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: <DropdownMenuItem<BackupSchedule>>[
                for (final BackupSchedule value in BackupSchedule.values)
                  DropdownMenuItem<BackupSchedule>(
                    value: value,
                    child: Text(value.label),
                  ),
              ],
              onChanged: (BackupSchedule? value) {
                if (value != null) {
                  setState(() => _schedule = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _retentionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Retention count (keep newest N)',
              ),
              onChanged: (String value) {
                final int? parsed = int.tryParse(value.trim());
                if (parsed != null && parsed > 0) {
                  setState(() => _retention = parsed);
                }
              },
            ),
            const SizedBox(height: 8),
            FutureBuilder<Directory>(
              future: sl<AppDirectoryService>().backups(),
              builder: (BuildContext context, AsyncSnapshot<Directory> snap) {
                return Text(
                  'Target directory: ${snap.data?.path ?? '…'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceMessage extends StatelessWidget {
  const _WorkspaceMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
