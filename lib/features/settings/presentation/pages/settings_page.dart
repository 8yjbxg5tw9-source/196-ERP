import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/app_directory_service.dart';
import '../../../../core/storage/app_preferences.dart';
import '../../../../injection_container.dart';
import '../../../company/domain/entities/company_entity.dart';
import '../../../diagnostics/presentation/pages/system_diagnostics_page.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../widgets/backup_management_panel.dart';
import 'windows_settings_page.dart';

/// Workspace settings: local storage layout and encrypted backup management.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        return Scaffold(
          appBar: AppBar(title: const Text('Workspace Settings')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SectionHeading(
                      icon: Icons.folder_outlined,
                      title: 'Local storage',
                      subtitle:
                          'Standardized on-disk layout for databases, '
                          'attachments, backups, and exports.',
                    ),
                    const SizedBox(height: 10),
                    const _StorageLocationsCard(),
                    const SizedBox(height: 24),
                    const _SectionHeading(
                      icon: Icons.security_rounded,
                      title: 'Encrypted backups',
                      subtitle:
                          'AES-256-GCM encrypted archives with SHA-256 '
                          'integrity verification and point-in-time restore.',
                    ),
                    const SizedBox(height: 10),
                    _Card(
                      child: BackupManagementPanel(
                        activeCompany: activeCompany,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionHeading(
                      icon: Icons.notifications_active_outlined,
                      title: 'Notifications & system',
                      subtitle:
                          'Windows system tray, tax-deadline popups, and '
                          'launch-on-startup behaviour.',
                    ),
                    const SizedBox(height: 10),
                    const _SystemTogglesCard(),
                    const SizedBox(height: 24),
                    const _SectionHeading(
                      icon: Icons.keyboard_rounded,
                      title: 'Windows integration & hotkeys',
                      subtitle:
                          'Global keyboard shortcuts, native toast '
                          'notifications, and minimize-to-tray behaviour.',
                    ),
                    const SizedBox(height: 10),
                    _Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const Icon(Icons.settings_input_antenna_rounded),
                        title: const Text('Open Windows integration settings'),
                        subtitle: const Text(
                          'Rebind Ctrl+N, Ctrl+Shift+R, Ctrl+F, and '
                          'Ctrl+Shift+A to fit your workflow.',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const WindowsSettingsPage(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionHeading(
                      icon: Icons.monitor_heart_outlined,
                      title: 'System diagnostics',
                      subtitle:
                          'Real-time database health, memory, and disk I/O '
                          'metrics with one-click maintenance tools.',
                    ),
                    const SizedBox(height: 10),
                    _Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const Icon(Icons.troubleshoot_rounded),
                        title: const Text('Open system diagnostics'),
                        subtitle: const Text(
                          'Vacuum the database, rebuild FTS5 indices, and '
                          'purge temporary OCR cache files.',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const SystemDiagnosticsPage(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: theme.colorScheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class _SystemTogglesCard extends StatefulWidget {
  const _SystemTogglesCard();

  @override
  State<_SystemTogglesCard> createState() => _SystemTogglesCardState();
}

class _SystemTogglesCardState extends State<_SystemTogglesCard> {
  bool? _systemTray;
  bool? _taxDeadlinePopups;
  bool? _launchAtStartup;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppPreferences prefs = sl<AppPreferences>();
    final bool tray = await prefs.isSystemTrayEnabled();
    final bool popups = await prefs.areTaxDeadlinePopupsEnabled();
    final bool startup = await prefs.isLaunchAtStartupEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _systemTray = tray;
      _taxDeadlinePopups = popups;
      _launchAtStartup = startup;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: _systemTray == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: <Widget>[
                _SystemToggleTile(
                  icon: Icons.widgets_outlined,
                  title: 'System tray',
                  subtitle:
                      'Keep FinAI Studio running in the Windows system tray '
                      'and minimize to tray on close.',
                  value: _systemTray!,
                  onChanged: (bool value) {
                    setState(() => _systemTray = value);
                    sl<AppPreferences>().setSystemTrayEnabled(value);
                  },
                ),
                const Divider(height: 20),
                _SystemToggleTile(
                  icon: Icons.event_available_outlined,
                  title: 'Tax deadline popups',
                  subtitle: 'Show a desktop notification before VAT and other '
                      'tax filing deadlines.',
                  value: _taxDeadlinePopups!,
                  onChanged: (bool value) {
                    setState(() => _taxDeadlinePopups = value);
                    sl<AppPreferences>().setTaxDeadlinePopupsEnabled(value);
                  },
                ),
                const Divider(height: 20),
                _SystemToggleTile(
                  icon: Icons.power_settings_new_rounded,
                  title: 'Launch at startup',
                  subtitle: 'Start FinAI Studio automatically when Windows '
                      'starts.',
                  value: _launchAtStartup!,
                  onChanged: (bool value) {
                    setState(() => _launchAtStartup = value);
                    sl<AppPreferences>().setLaunchAtStartupEnabled(value);
                  },
                ),
              ],
            ),
    );
  }
}

class _SystemToggleTile extends StatelessWidget {
  const _SystemToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 22, color: theme.colorScheme.secondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _StorageLocationsCard extends StatefulWidget {
  const _StorageLocationsCard();

  @override
  State<_StorageLocationsCard> createState() => _StorageLocationsCardState();
}

class _StorageLocationsCardState extends State<_StorageLocationsCard> {
  late final Future<Map<String, String>> _paths;

  @override
  void initState() {
    super.initState();
    _paths = _resolvePaths();
  }

  Future<Map<String, String>> _resolvePaths() async {
    final AppDirectoryService service = sl<AppDirectoryService>();
    return <String, String>{
      'Databases': (await service.databases()).path,
      'Attachments': (await service.storageRoot()).path,
      'Backups': (await service.backups()).path,
      'Exports': (await service.exports()).path,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return FutureBuilder<Map<String, String>>(
      future: _paths,
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, String>> snapshot,
      ) {
        final Map<String, String> paths = snapshot.data ?? const <String, String>{};
        return _Card(
          child: Column(
            children: <Widget>[
              for (final MapEntry<String, String> entry in paths.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 110,
                        child: Text(
                          entry.key,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          entry.value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
