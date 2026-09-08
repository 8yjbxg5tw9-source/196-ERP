import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../company/domain/repositories/company_repository.dart';

/// Backup controls: instant backup, restore-from-file, schedule, and the list
/// of retained encrypted archives.
class BackupManagementPanel extends StatefulWidget {
  const BackupManagementPanel({required this.activeCompany, super.key});

  final CompanyEntity? activeCompany;

  @override
  State<BackupManagementPanel> createState() => _BackupManagementPanelState();
}

class _BackupManagementPanelState extends State<BackupManagementPanel> {
  List<BackupArchiveInfo> _backups = const <BackupArchiveInfo>[];
  Map<String, String> _companyNames = const <String, String>{};
  BackupFrequency _frequency = BackupFrequency.weekly;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final BackupService backupService = sl<BackupService>();
    final AutoBackupService autoBackup = sl<AutoBackupService>();
    final List<BackupArchiveInfo> backups = await backupService.listBackups();
    final Map<String, String> names = await _loadCompanyNames();
    if (!mounted) {
      return;
    }
    setState(() {
      _backups = backups;
      _companyNames = names;
      _frequency = autoBackup.frequency;
    });
  }

  Future<Map<String, String>> _loadCompanyNames() async {
    final result = await sl<CompanyRepository>().getCompanies();
    return result.fold(
      (failure) => const <String, String>{},
      (List<CompanyEntity> companies) => <String, String>{
        for (final CompanyEntity company in companies) company.id: company.name,
      },
    );
  }

  Future<void> _createInstantBackup() async {
    final CompanyEntity? company = widget.activeCompany;
    if (company == null) {
      _snack('Select an active company before creating a backup.');
      return;
    }
    setState(() => _busy = true);
    try {
      final File file = await sl<BackupService>().createBackup(company.id);
      _snack('Encrypted backup created: ${file.path}');
      await _reload();
    } on Object catch (error) {
      _snack('Backup failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreFromFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['enc'],
    );
    final String? path = result?.files.single.path;
    if (path == null) {
      return;
    }

    final bool confirmed = await _confirmRestore(File(path));
    if (!confirmed) {
      return;
    }
    setState(() => _busy = true);
    try {
      await sl<BackupService>().restoreBackup(File(path));
      _snack('Backup restored successfully. Reloading data…');
      await _reload();
    } on Object catch (error) {
      _snack('Restore failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirmRestore(File file) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, color: Colors.amber),
              SizedBox(width: 8),
              Text('Restore backup?'),
            ],
          ),
          content: Text(
            'Restoring "${file.path.split(Platform.pathSeparator).last}" will '
            'replace the current database and attachment files with the '
            'backup contents. This cannot be undone.',
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
    return confirmed ?? false;
  }

  Future<void> _deleteBackup(BackupArchiveInfo backup) async {
    try {
      await sl<BackupService>().deleteBackup(backup.fileName);
      await _reload();
    } on Object catch (error) {
      _snack('Could not delete backup: $error');
    }
  }

  Future<void> _setFrequency(BackupFrequency frequency) async {
    await sl<AutoBackupService>().setFrequency(frequency);
    setState(() => _frequency = frequency);
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            FilledButton.icon(
              onPressed: _busy ? null : _createInstantBackup,
              icon: const Icon(Icons.shield_outlined, size: 17),
              label: const Text('Create Instant Backup'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restoreFromFile,
              icon: const Icon(Icons.restore_rounded, size: 17),
              label: const Text('Restore From File'),
            ),
            const SizedBox(width: 6),
            Text(
              'Auto-backup:',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            DropdownButton<BackupFrequency>(
              value: _frequency,
              items: const <DropdownMenuItem<BackupFrequency>>[
                DropdownMenuItem<BackupFrequency>(
                  value: BackupFrequency.daily,
                  child: Text('Daily'),
                ),
                DropdownMenuItem<BackupFrequency>(
                  value: BackupFrequency.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem<BackupFrequency>(
                  value: BackupFrequency.onAppExit,
                  child: Text('On App Exit'),
                ),
              ],
              onChanged: (BackupFrequency? value) {
                if (value != null) {
                  unawaited(_setFrequency(value));
                }
              },
            ),
            Text(
              'Retention: last ${BackupServiceImpl.maxRetainedBackups} kept',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Available backups',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (_busy) const LinearProgressIndicator(),
        if (_backups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No encrypted backups yet. Create an instant backup or enable '
              'auto-backup to populate this list.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _backups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final BackupArchiveInfo backup = _backups[index];
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded, size: 18),
                  title: Text(
                    _companyNames[backup.companyId] ?? backup.companyId,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${AppFormatters.dateTime(backup.createdAt.toLocal())} · '
                    '${_formatBytes(backup.sizeBytes)}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Delete backup',
                    onPressed: () => _deleteBackup(backup),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}
