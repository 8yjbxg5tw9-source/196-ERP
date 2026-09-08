import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../config/env/env_config.dart';
import '../../features/company/presentation/widgets/company_selector_dropdown.dart';
import '../../features/document_ocr/presentation/widgets/file_drop_zone.dart';

const double _expandedSidebarWidth = 248;
const double _collapsedSidebarWidth = 76;
const double _mobileBreakpoint = 760;
const double _compactSidebarBreakpoint = 1100;

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
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
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

    if (_nativeDesktop) {
      windowManager.addListener(this);
      unawaited(_loadWindowState());
    }
  }

  @override
  void dispose() {
    if (_nativeDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
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
                ? Row(
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
            unawaited(windowManager.close());
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
      const _FeatureOverviewView(
        icon: Icons.document_scanner_rounded,
        title: 'OCR Invoice Workspace',
        subtitle: 'Capture, validate, and route invoices with confidence.',
        status: 'Ready for intake',
      ),
      const _FeatureOverviewView(
        icon: Icons.auto_awesome,
        title: 'Tax Copilot',
        subtitle: 'Ask explainable questions about tax exposure and filings.',
        status: 'AI assistant online',
      ),
      const _FeatureOverviewView(
        icon: Icons.compare_arrows_rounded,
        title: 'Reconciliation Center',
        subtitle: 'Match ledger activity against bank and operational records.',
        status: 'All feeds connected',
      ),
      const _FeatureOverviewView(
        icon: Icons.bar_chart_rounded,
        title: 'Financial Reports',
        subtitle: 'Build controlled, audit-ready reporting packages.',
        status: 'Reporting period open',
      ),
      const _FeatureOverviewView(
        icon: Icons.settings_rounded,
        title: 'Workspace Settings',
        subtitle: 'Manage preferences, controls, roles, and integrations.',
        status: 'Configuration healthy',
      ),
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
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PageHeader(
            eyebrow: 'MONDAY, 08 SEP 2026',
            title: 'Financial overview',
            subtitle: 'A concise view of your organization’s financial health.',
            action: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New workspace task'),
            ),
          ),
          const SizedBox(height: 22),
          const FileDropZone(),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cardWidth;
              if (constraints.maxWidth >= 1000) {
                cardWidth = (constraints.maxWidth - 36) / 4;
              } else if (constraints.maxWidth >= 600) {
                cardWidth = (constraints.maxWidth - 12) / 2;
              } else {
                cardWidth = constraints.maxWidth;
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _MetricCard(
                    width: cardWidth,
                    label: 'Cash position',
                    value: r'$248,430.00',
                    delta: '+12.4%',
                    icon: Icons.account_balance_wallet_outlined,
                    positive: true,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Open receivables',
                    value: r'$84,920.50',
                    delta: '+4.8%',
                    icon: Icons.call_received_rounded,
                    positive: true,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Payables due',
                    value: r'$42,118.75',
                    delta: '-2.1%',
                    icon: Icons.call_made_rounded,
                    positive: true,
                  ),
                  _MetricCard(
                    width: cardWidth,
                    label: 'Reconciliation rate',
                    value: '96.8%',
                    delta: '+1.6%',
                    icon: Icons.verified_outlined,
                    positive: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const Widget activity = _ActivityPanel();
              const Widget health = _HealthPanel();
              if (constraints.maxWidth < 760) {
                return Column(
                  children: <Widget>[
                    activity,
                    const SizedBox(height: 12),
                    health,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: activity),
                  const SizedBox(width: 12),
                  Expanded(child: health),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.auto_awesome_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FinAI insight: operating cash flow is trending above the 30-day baseline.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Explore')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              eyebrow,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        action,
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.delta,
    required this.icon,
    required this.positive,
  });

  final double width;
  final String label;
  final String value;
  final String delta;
  final IconData icon;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color metricColor = positive
        ? theme.colorScheme.secondary
        : theme.colorScheme.error;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: metricColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: metricColor),
              ),
              const Spacer(),
              Text(
                delta,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: metricColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent activity',
      trailing: TextButton(onPressed: () {}, child: const Text('View all')),
      child: Column(
        children: <Widget>[
          _ActivityRow(
            icon: Icons.document_scanner_outlined,
            title: 'Invoice batch processed',
            subtitle: '42 documents · OCR confidence 98.2%',
            time: '09:42',
          ),
          _ActivityRow(
            icon: Icons.compare_arrows_outlined,
            title: 'Bank feed reconciled',
            subtitle: '126 transactions matched automatically',
            time: '09:18',
          ),
          _ActivityRow(
            icon: Icons.receipt_long_outlined,
            title: 'VAT return draft updated',
            subtitle: 'Tax Copilot suggested 3 adjustments',
            time: 'Yesterday',
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthPanel extends StatelessWidget {
  const _HealthPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return _Panel(
      title: 'Control health',
      trailing: Icon(
        Icons.verified_outlined,
        size: 18,
        color: theme.colorScheme.secondary,
      ),
      child: Column(
        children: <Widget>[
          _HealthRow(label: 'Bank integrations', value: '12 / 12 connected'),
          _HealthRow(label: 'OCR queue', value: '18 documents pending'),
          _HealthRow(label: 'Open exceptions', value: '4 require review'),
          _HealthRow(label: 'Last backup', value: 'Today, 08:30'),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.trailing,
    required this.child,
  });

  final String title;
  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _FeatureOverviewView extends StatelessWidget {
  const _FeatureOverviewView({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PageHeader(
            eyebrow: 'FINAI STUDIO WORKSPACE',
            title: title,
            subtitle: subtitle,
            action: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create workspace item'),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: theme.colorScheme.outline.withAlpha(90)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        status,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Chip(
                      avatar: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                      label: const Text('Healthy'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'This module is connected to the shared application shell. Its data, domain, and presentation layers can be added without changing desktop navigation or theme state.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _StatusTile(
                      icon: Icons.security_outlined,
                      label: 'Audit trail enabled',
                    ),
                    _StatusTile(
                      icon: Icons.sync_rounded,
                      label: 'Sync service connected',
                    ),
                    _StatusTile(
                      icon: Icons.insights_outlined,
                      label: 'Insights available',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 7),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}
