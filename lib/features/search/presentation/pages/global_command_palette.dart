import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../config/routes/app_navigator.dart';
import '../../../../features/diagnostics/presentation/pages/system_diagnostics_page.dart';
import '../../../../injection_container.dart';
import '../../../../shared/navigation/app_shell_controller.dart';
import '../../domain/entities/entity_type.dart';
import '../../domain/entities/search_result_item_entity.dart';
import '../bloc/global_search_bloc.dart';
import '../bloc/global_search_event.dart';
import '../bloc/global_search_state.dart';
import '../widgets/entity_lineage_drawer.dart';

/// Opens the unified Spotlight-style command palette as a modal overlay.
Future<void> showGlobalCommandPalette() async {
  final NavigatorState? navigator = AppNavigator.key.currentState;
  if (navigator == null) {
    return;
  }
  await showDialog<void>(
    context: navigator.context,
    useRootNavigator: true,
    barrierColor: Colors.black45,
    barrierDismissible: true,
    builder: (BuildContext _) => BlocProvider<GlobalSearchBloc>(
      create: (_) => sl<GlobalSearchBloc>(),
      child: const GlobalCommandPalette(),
    ),
  );
}

/// Spotlight-style palette: auto-focused, debounced FTS5 search with grouped
/// results and full keyboard navigation (`↑ ↓` move, `↵` opens, `Esc` closes).
class GlobalCommandPalette extends StatefulWidget {
  const GlobalCommandPalette({super.key});

  @override
  State<GlobalCommandPalette> createState() => _GlobalCommandPaletteState();
}

class _GlobalCommandPaletteState extends State<GlobalCommandPalette> {
  static const double _tileHeight = 52;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _activateHighlighted();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return true;
    }
    return false;
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      setState(() => _highlightedIndex = 0);
      context
          .read<GlobalSearchBloc>()
          .add(ExecuteGlobalQueryEvent(value));
    });
  }

  void _moveHighlight(int delta) {
    final List<_GlobalPaletteEntry> entries = _entries();
    if (entries.isEmpty) {
      return;
    }
    final int count = entries.length;
    final int next = (_highlightedIndex + delta) % count;
    setState(() {
      _highlightedIndex = next < 0 ? next + count : next;
    });
    final double target = (_highlightedIndex * _tileHeight) - (_tileHeight * 2);
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          target.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  void _activateHighlighted() {
    final List<_GlobalPaletteEntry> entries = _entries();
    if (entries.isEmpty ||
        _highlightedIndex < 0 ||
        _highlightedIndex >= entries.length) {
      return;
    }
    final _GlobalPaletteEntry entry = entries[_highlightedIndex];
    final _PaletteAction? action = entry.action;
    if (action != null) {
      action.onRun();
      return;
    }
    final SearchResultItemEntity? result = entry.result;
    if (result != null) {
      _openResult(result);
    }
  }

  List<_GlobalPaletteEntry> _entries() {
    final String query = _searchController.text.trim();
    final GlobalSearchState searchState = context.read<GlobalSearchBloc>().state;
    final List<SearchResultItemEntity> results =
        searchState is GlobalSearchResultsLoaded
        ? searchState.results
        : const <SearchResultItemEntity>[];
    return <_GlobalPaletteEntry>[
      if (query.isEmpty)
        ..._buildQuickActions().map(_GlobalPaletteEntry.action),
      ...results.map(_GlobalPaletteEntry.result),
    ];
  }

  List<_PaletteAction> _buildQuickActions() {
    return <_PaletteAction>[
      _PaletteAction(
        label: 'New Invoice',
        icon: Icons.note_add_outlined,
        description: 'Import a PDF or image for OCR',
        onRun: () => _goSection(AppSection.ocrInvoices),
      ),
      _PaletteAction(
        label: 'Reconcile Bank',
        icon: Icons.compare_arrows_outlined,
        description: 'Open the bank reconciliation workspace',
        onRun: () => _goSection(AppSection.reconciliation),
      ),
      _PaletteAction(
        label: 'Export Report',
        icon: Icons.picture_as_pdf_outlined,
        description: 'Open the financial reports workspace',
        onRun: () => _goSection(AppSection.financialReports),
      ),
      _PaletteAction(
        label: 'Open Tax Copilot',
        icon: Icons.auto_awesome_outlined,
        description: 'Ask the AI tax assistant',
        onRun: () => _goSection(AppSection.taxCopilot),
      ),
      _PaletteAction(
        label: 'Backup & Recovery',
        icon: Icons.settings_backup_restore_outlined,
        description: 'Encrypted backups and point-in-time restore',
        onRun: () => _goSection(AppSection.disasterRecovery),
      ),
      _PaletteAction(
        label: 'System Diagnostics',
        icon: Icons.monitor_heart_outlined,
        description: 'Database health, memory, and maintenance tools',
        onRun: _openDiagnostics,
      ),
    ];
  }

  void _goSection(AppSection section) {
    Navigator.of(context).pop();
    sl<AppShellController>().select(section);
  }

  void _openDiagnostics() {
    Navigator.of(context).pop();
    final NavigatorState? navigator = AppNavigator.key.currentState;
    if (navigator != null) {
      unawaited(
        Navigator.of(navigator.context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const SystemDiagnosticsPage(),
          ),
        ),
      );
    }
  }

  void _openResult(SearchResultItemEntity result) {
    Navigator.of(context).pop();
    final AppSection? section = _sectionFor(result.entityType);
    if (section != null) {
      sl<AppShellController>().select(section);
    }
    _openLineage(result);
  }

  void _openLineage(SearchResultItemEntity result) {
    final NavigatorState? navigator = AppNavigator.key.currentState;
    if (navigator != null) {
      unawaited(
        showEntityLineageDrawer(
          navigator.context,
          entityId: result.id,
          type: result.entityType,
        ),
      );
    }
  }

  static AppSection? _sectionFor(EntityType type) {
    return switch (type) {
      EntityType.transaction => AppSection.reconciliation,
      EntityType.invoice => AppSection.ocrInvoices,
      EntityType.asset => AppSection.assets,
      EntityType.payroll => AppSection.payroll,
      EntityType.account => AppSection.financialReports,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 96),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 560,
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildSearchField(theme),
                const Divider(height: 1),
                Flexible(
                  child: BlocBuilder<GlobalSearchBloc, GlobalSearchState>(
                    builder: (BuildContext context, GlobalSearchState state) {
                      return _buildBody(theme, state);
                    },
                  ),
                ),
                _buildFooter(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _onQueryChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search transactions, invoices, VÖENs, amounts…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                _KeyHint(label: '↑↓'),
                SizedBox(width: 4),
                _KeyHint(label: '↵'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, GlobalSearchState state) {
    final String query = _searchController.text.trim();
    if (state is GlobalSearchLoading && query.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(),
      );
    }
    if (state is GlobalSearchError) {
      return _EmptyMessage(message: state.message);
    }

    final List<SearchResultItemEntity> results =
        state is GlobalSearchResultsLoaded
        ? state.results
        : const <SearchResultItemEntity>[];

    final bool showActions = query.isEmpty;
    if (query.isNotEmpty && results.isEmpty && state is! GlobalSearchLoading) {
      return _EmptyMessage(message: 'No results for "$query"');
    }

    final Map<EntityType, List<SearchResultItemEntity>> grouped =
        <EntityType, List<SearchResultItemEntity>>{};
    for (final SearchResultItemEntity result in results) {
      grouped
          .putIfAbsent(result.entityType, () => <SearchResultItemEntity>[])
          .add(result);
    }

    int runningIndex = 0;
    final List<Widget> children = <Widget>[];
    if (showActions) {
      children.add(const _SectionHeader(label: 'App Actions'));
      for (final _PaletteAction action in _buildQuickActions()) {
        children.add(
          _PaletteTile(
            entry: _GlobalPaletteEntry.action(action),
            highlighted: _highlightedIndex == runningIndex,
            onTap: action.onRun,
            onInspect: null,
          ),
        );
        runningIndex += 1;
      }
    }

    for (final MapEntry<EntityType, List<SearchResultItemEntity>> group
        in grouped.entries) {
      children.add(_SectionHeader(label: group.key.label));
      for (final SearchResultItemEntity result in group.value) {
        children.add(
          _PaletteTile(
            entry: _GlobalPaletteEntry.result(result),
            highlighted: _highlightedIndex == runningIndex,
            onTap: () => _openResult(result),
            onInspect: () => _openLineage(result),
          ),
        );
        runningIndex += 1;
      }
    }

    if (children.isEmpty) {
      return const _EmptyMessage(message: 'Start typing to search');
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 6),
      shrinkWrap: true,
      children: children,
    );
  }

  Widget _buildFooter(ThemeData theme) {
    final List<_GlobalPaletteEntry> entries = _entries();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withAlpha(60)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.bolt_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'FTS5 instant search',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '${entries.length} item${entries.length == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalPaletteEntry {
  const _GlobalPaletteEntry.action(this.action) : result = null;
  const _GlobalPaletteEntry.result(this.result) : action = null;

  final _PaletteAction? action;
  final SearchResultItemEntity? result;
}

class _PaletteAction {
  const _PaletteAction({
    required this.label,
    required this.icon,
    required this.description,
    required this.onRun,
  });

  final String label;
  final IconData icon;
  final String description;
  final VoidCallback onRun;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.entry,
    required this.highlighted,
    required this.onTap,
    required this.onInspect,
  });

  final _GlobalPaletteEntry entry;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onInspect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SearchResultItemEntity? result = entry.result;
    final IconData icon = result == null
        ? entry.action!.icon
        : _categoryIcon(result.entityType);
    final String title = result == null
        ? entry.action!.label
        : result.title;
    final String subtitle = result == null
        ? entry.action!.description
        : result.subtitle;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: highlighted
              ? theme.colorScheme.secondary.withAlpha(20)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              width: 3,
              color: highlighted
                  ? theme.colorScheme.secondary
                  : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 17,
                color: highlighted
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (result != null && onInspect != null)
              IconButton(
                tooltip: 'View lineage',
                onPressed: onInspect,
                icon: const Icon(Icons.account_tree_outlined, size: 18),
              ),
            if (highlighted)
              Icon(
                Icons.keyboard_return_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  static IconData _categoryIcon(EntityType type) {
    return switch (type) {
      EntityType.transaction => Icons.swap_horiz_rounded,
      EntityType.invoice => Icons.description_outlined,
      EntityType.counterparty => Icons.business_outlined,
      EntityType.asset => Icons.business_center_outlined,
      EntityType.payroll => Icons.groups_outlined,
      EntityType.account => Icons.account_balance_outlined,
    };
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off_rounded,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
