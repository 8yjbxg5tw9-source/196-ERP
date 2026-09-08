import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/env/env_config.dart';
import '../../core/services/auto_backup_service.dart';
import '../../core/storage/app_preferences.dart';
import '../../features/analytics/presentation/pages/analytics_dashboard_page.dart';
import '../../features/analytics/presentation/pages/financial_reports_page.dart';
import '../../features/analytics/presentation/pages/kpi_dashboard_page.dart';
import '../../features/assets/presentation/pages/asset_register_page.dart';
import '../../features/audit/presentation/pages/audit_inspector_page.dart';
import '../../features/cash_flow/presentation/pages/cash_flow_page.dart';
import '../../features/auth/presentation/widgets/user_menu_button.dart';
import '../../features/company/presentation/widgets/company_selector_dropdown.dart';
import '../../features/consolidation/presentation/pages/consolidation_page.dart';
import '../../features/currency/presentation/pages/fx_revaluation_page.dart';
import '../../features/currency/presentation/widgets/currency_rate_ticker.dart';
import '../../features/intercompany/presentation/pages/intercompany_page.dart';
import '../../features/inventory/presentation/pages/inventory_page.dart';
import '../../features/payroll/presentation/pages/payroll_page.dart';
import '../../features/document_ocr/domain/entities/document_entity.dart';
import '../../features/document_ocr/presentation/pages/document_verification_page.dart';
import '../../features/document_ocr/presentation/widgets/file_drop_zone.dart';
import '../../features/reconciliation/presentation/pages/reconciliation_page.dart';
import '../../features/settings/settings.dart';
import '../../features/tax_copilot/presentation/pages/tax_copilot_page.dart';
import '../../features/disaster_recovery/presentation/pages/disaster_recovery_page.dart';
import '../../features/tax_declaration/presentation/pages/tax_declaration_page.dart';
import '../../features/tax_deferred/presentation/pages/deferred_tax_page.dart';
import '../../features/search/presentation/pages/global_command_palette.dart';
import '../../injection_container.dart';
import '../navigation/app_shell_controller.dart';

const double _expandedSidebarWidth = 248;
const double _collapsedSidebarWidth = 76;
const double _mobileBreakpoint = 760;
const double _compactSidebarBreakpoint = 1100;

Future<void> _openDocumentVerification(
  BuildContext context,
  String documentId,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DocumentVerificationPage(documentId: documentId),
    ),
  );
}

const List<_NavigationDestination> _navigationDestinations =
    <_NavigationDestination>[
  _NavigationDestination(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
  ),
  _NavigationDestination(
    label: 'OCR Invoices',
    icon: Icons.document_scanner_outlined,
    selectedIcon: Icons.document_scanner_rounded,
  ),
  _NavigationDestination(
    label: 'Tax Copilot',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
  ),
  _NavigationDestination(
    label: 'Reconciliation',
    icon: Icons.compare_arrows_outlined,
    selectedIcon: Icons.compare_arrows_rounded,
  ),
  _NavigationDestination(
    label: 'Financial Reports',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart_rounded,
  ),
  _NavigationDestination(
    label: 'Cash Flow',
    icon: Icons.waterfall_chart_outlined,
    selectedIcon: Icons.waterfall_chart_rounded,
  ),
  _NavigationDestination(
    label: 'Inventory',
    icon: Icons.warehouse_outlined,
    selectedIcon: Icons.warehouse_rounded,
  ),
  _NavigationDestination(
    label: 'Intercompany',
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance_rounded,
  ),
  _NavigationDestination(
    label: 'FX Revaluation',
    icon: Icons.currency_exchange_outlined,
    selectedIcon: Icons.currency_exchange_rounded,
  ),
  _NavigationDestination(
    label: 'Assets',
    icon: Icons.business_outlined,
    selectedIcon: Icons.business_rounded,
  ),
  _NavigationDestination(
    label: 'Payroll',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  ),
  _NavigationDestination(
    label: 'Audit Log',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history_rounded,
  ),
  _NavigationDestination(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
  ),
  _NavigationDestination(
    label: 'Consolidation',
    icon: Icons.account_tree_outlined,
    selectedIcon: Icons.account_tree_rounded,
  ),
  _NavigationDestination(
    label: 'Deferred Tax',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
  ),
  _NavigationDestination(
    label: 'KPIs',
    icon: Icons.query_stats_outlined,
    selectedIcon: Icons.query_stats_rounded,
  ),
  _NavigationDestination(
    label: 'Tax Filing',
    icon: Icons.upload_file_outlined,
    selectedIcon: Icons.upload_file_rounded,
  ),
  _NavigationDestination(
    label: 'Backup & Recovery',
    icon: Icons.settings_backup_restore_outlined,
    selectedIcon: Icons.settings_backup_restore_rounded,
  ),
];

/// The primary responsive application shell.
///
/// Desktop uses a persistent, collapsible sidebar and a custom title/action
/// bar. Smaller surfaces switch to a bottom navigation bar while retaining the
/// same [IndexedStack], so switching modules never destroys feature state.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.config,
    required this.themeMode,
    required this.onToggleTheme,
    super.key,
  });

  final EnvConfig config;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  int _selectedIndex = 0;
  bool _sidebarExpanded = true;
  bool _isWindowMaximized = false;
  late final bool _nativeDesktop;
  late final List<Widget> _views;

  @override
  void initState() {
    super.initState();
    _nativeDesktop = _isNativeDesktop;
    _views = _buildDefaultViews();
    _selectedIndex = sl<AppShellController>().index;

    sl<AppShellController>().addListener(_onSectionChanged);

    if (_nativeDesktop) {
      windowManager.addListener(this);
      unawaited(_loadWindowState());
    }
  }

  @override
  void dispose() {
    sl<AppShellController>().removeListener(_onSectionChanged);
    if (_nativeDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  void _onSectionChanged() {
    final int index = sl<AppShellController>().index;
    if (mounted && index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  void onWindowMaximize() {
    _setWindowMaximized(true);
  }

  @override
  void onWindowUnmaximize() {
    _setWindowMaximized(false);
  }

  Future<void> _loadWindowState() async {
    final bool isMaximized = await windowManager.isMaximized();
    if (mounted) {
      _setWindowMaximized(isMaximized);
    }
  }

  void _setWindowMaximized(bool value) {
    if (mounted && _isWindowMaximized != value) {
      setState(() => _isWindowMaximized = value);
    }
  }

  void _selectDestination(int index) {
    if (index < 0 || index >= AppSection.values.length) {
      return;
    }
    sl<AppShellController>().select(AppSection.values[index]);
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  void _toggleSidebar() {
    setState(() => _sidebarExpanded = !_sidebarExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < _mobileBreakpoint) {
          return _buildMobileLayout(context);
        }

        final bool isCompact = constraints.maxWidth < _compactSidebarBreakpoint;
        final bool sidebarExpanded = _sidebarExpanded && !isCompact;

        return Scaffold(
          body: SafeArea(
            top: false,
            child: Row(
              children: <Widget>[
                _buildSidebar(context, expanded: sidebarExpanded),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _buildTopActionBar(context, compact: false),
                      Expanded(child: _buildMainView()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          _buildTopActionBar(context, compact: true),
          Expanded(child: _buildMainView()),
          NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectDestination,
            destinations: _navigationDestinations
                .map(
                  (_NavigationDestination destination) => NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: IndexedStack(
        index: _selectedIndex,
        children: _views,
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool expanded}) {
    final ThemeData theme = Theme.of(context);
    final Color borderColor = theme.colorScheme.outline.withAlpha(90);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: expanded ? _expandedSidebarWidth : _collapsedSidebarWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 64,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? 16 : 12,
              ),
              child: expanded
                  ? Row(
                      children: <Widget>[
                        const _BrandMark(),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'FinAI Studio',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        _SidebarIconButton(
                          tooltip: 'Collapse sidebar',
                          icon: Icons.chevron_left_rounded,
                          onPressed: _toggleSidebar,
                        ),
                      ],
                    )
                  : Center(
                      child: _SidebarIconButton(
                        tooltip: 'Expand sidebar',
                        icon: Icons.chevron_right_rounded,
                        onPressed: _toggleSidebar,
                      ),
                    ),
            ),
          ),
          Divider(height: 1, color: borderColor),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              itemCount: _navigationDestinations.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildSidebarDestination(
                  context,
                  destination: _navigationDestinations[index],
                  index: index,
                  expanded: expanded,
                );
              },
            ),
          ),
          if (expanded)
            _EnvironmentCard(
              config: widget.config,
              borderColor: borderColor,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 8, 10, expanded ? 14 : 12),
            child: expanded
                ? InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => unawaited(showGlobalCommandPalette()),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.keyboard_command_key_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ctrl + K to search',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Tooltip(
                    message: 'Keyboard shortcuts',
                    child: Icon(
                      Icons.keyboard_command_key_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarDestination(
    BuildContext context, {
    required _NavigationDestination destination,
    required int index,
    required bool expanded,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool selected = index == _selectedIndex;
    final Color foregroundColor = selected
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurfaceVariant;

    final Widget item = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 4),
      height: 42,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.secondary.withAlpha(24)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _selectDestination(index),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 3,
                height: selected ? 24 : 0,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(
                width: expanded ? 44 : 100,
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: foregroundColor,
                ),
              ),
              if (expanded)
                Expanded(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (expanded) {
      return item;
    }

    return Tooltip(
      message: destination.label,
      preferBelow: false,
      child: item,
    );
  }

  Widget _buildTopActionBar(BuildContext context, {required bool compact}) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkTheme = theme.brightness == Brightness.dark;
    final String pageName = _navigationDestinations[_selectedIndex].label;
    final Color borderColor = theme.colorScheme.outline.withAlpha(90);

    return Container(
      height: compact ? 64 : 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: compact,
        bottom: false,
        child: Row(
          children: <Widget>[
            if (compact)
              IconButton(
                tooltip: 'Open navigation',
                onPressed: () => _showMobileNavigation(context),
                icon: const Icon(Icons.menu_rounded),
              ),
            Expanded(
              child: _dragToMoveArea(
                Padding(
                  padding: EdgeInsets.only(left: compact ? 4 : 18),
                  child: Row(
                    children: <Widget>[
                      if (!compact) const _BrandMark(size: 28),
                      if (!compact) const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              compact ? 'FinAI Studio' : pageName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (!compact)
                              Text(
                                'Enterprise Accounting Copilot',
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!compact) const CompanySelectorDropdown(),
            if (!compact) const UserMenuButton(),
            if (!compact) const CurrencyRateTicker(),
            _buildSyncStatus(context, compact: compact),
            _buildNotificationButton(context),
            IconButton(
              tooltip: isDarkTheme
                  ? 'Switch to light theme'
                  : 'Switch to dark theme',
              onPressed: widget.onToggleTheme,
              icon: Icon(
                isDarkTheme
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            if (_nativeDesktop) _buildWindowControls(context),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatus(BuildContext context, {required bool compact}) {
    final ThemeData theme = Theme.of(context);

    return Tooltip(
      message: 'Database synchronized 2 minutes ago',
      child: Padding(
        padding: EdgeInsets.only(left: compact ? 0 : 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.cloud_done_outlined,
              size: 17,
              color: theme.colorScheme.secondary,
            ),
            if (!compact) ...<Widget>[
              const SizedBox(width: 5),
              Text(
                'Synced',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        Positioned(
          top: 11,
          right: 10,
          child: IgnorePointer(
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWindowControls(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _WindowActionButton(
          tooltip: 'Minimize',
          icon: Icons.remove_rounded,
          foregroundColor: foreground,
          onPressed: () {
            unawaited(windowManager.minimize());
          },
        ),
        _WindowActionButton(
          tooltip: _isWindowMaximized ? 'Restore' : 'Maximize',
          icon: _isWindowMaximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          foregroundColor: foreground,
          onPressed: () {
            unawaited(_toggleMaximize());
          },
        ),
        _WindowActionButton(
          tooltip: 'Close',
          icon: Icons.close_rounded,
          foregroundColor: foreground,
          closeButton: true,
          onPressed: () {
            unawaited(_closeApplication());
          },
        ),
      ],
    );
  }

  Future<void> _toggleMaximize() async {
    if (_isWindowMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  /// Handles the custom close button: minimize-to-tray when the system tray is
  /// enabled, otherwise run the on-exit backup and close the window.
  Future<void> _closeApplication() async {
    final AppPreferences preferences = sl<AppPreferences>();
    if (_nativeDesktop && await preferences.isSystemTrayEnabled()) {
      await windowManager.hide();
      return;
    }
    try {
      await sl<AutoBackupService>().backupOnAppExit();
    } on Object {
      // Never block an explicit user close on a backup failure.
    }
    await windowManager.close();
  }

  void _showMobileNavigation(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (BuildContext context) {
          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _navigationDestinations.length,
              itemBuilder: (BuildContext context, int index) {
                final _NavigationDestination destination =
                    _navigationDestinations[index];
                return ListTile(
                  leading: Icon(
                    index == _selectedIndex
                        ? destination.selectedIcon
                        : destination.icon,
                  ),
                  title: Text(destination.label),
                  selected: index == _selectedIndex,
                  onTap: () {
                    _selectDestination(index);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _dragToMoveArea(Widget child) {
    if (!_nativeDesktop) {
      return child;
    }
    return DragToMoveArea(child: child);
  }

  List<Widget> _buildDefaultViews() {
    return <Widget>[
      const _DashboardView(),
      const DocumentVerificationPage(),
      const TaxCopilotPage(),
      const ReconciliationPage(),
      const FinancialReportsPage(),
      const CashFlowPage(),
      const InventoryPage(),
      const IntercompanyPage(),
      const FxRevaluationPage(),
      const AssetRegisterPage(),
      const PayrollPage(),
      const AuditInspectorPage(),
      const SettingsPage(),
      const ConsolidationPage(),
      const DeferredTaxPage(),
      const KpiDashboardPage(),
      const TaxDeclarationPage(),
      const DisasterRecoveryPage(),
    ];
  }
}

bool get _isNativeDesktop {
  if (kIsWeb) {
    return false;
  }

  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

class _NavigationDestination {
  const _NavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.secondary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        Icons.account_balance_rounded,
        size: size * 0.58,
        color: Colors.white,
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  const _SidebarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
      padding: EdgeInsets.zero,
    );
  }
}

class _WindowActionButton extends StatelessWidget {
  const _WindowActionButton({
    required this.tooltip,
    required this.icon,
    required this.foregroundColor,
    required this.onPressed,
    this.closeButton = false,
  });

  final String tooltip;
  final IconData icon;
  final Color foregroundColor;
  final VoidCallback onPressed;
  final bool closeButton;

  @override
  Widget build(BuildContext context) {
    final Color errorColor = Theme.of(context).colorScheme.error;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      color: foregroundColor,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        hoverColor: closeButton ? errorColor : foregroundColor.withAlpha(20),
        foregroundColor: closeButton ? errorColor : foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard({required this.config, required this.borderColor});

  final EnvConfig config;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isProduction = config.environment == AppEnvironment.production;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isProduction ? Icons.lock_outline_rounded : Icons.developer_mode,
            size: 16,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isProduction ? 'Production' : 'Development',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Secure workspace',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: FileDropZone(
            onDocumentProcessed: (DocumentEntity document) {
              unawaited(
                _openDocumentVerification(context, document.id),
              );
            },
          ),
        ),
        const Expanded(child: AnalyticsDashboardPage()),
      ],
    );
  }
}

