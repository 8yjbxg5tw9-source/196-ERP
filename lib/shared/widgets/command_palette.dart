import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/routes/app_navigator.dart';
import '../../features/company/presentation/bloc/company_bloc.dart';
import '../../features/company/presentation/bloc/company_event.dart';
import '../../features/document_ocr/presentation/pages/document_verification_page.dart';
import '../../features/search/domain/entities/search_result_entity.dart';
import '../../features/search/presentation/pages/global_command_palette.dart';
import '../../injection_container.dart';
import '../bloc/search_bloc.dart';
import '../navigation/app_shell_controller.dart';

/// Opens the global command palette via `Ctrl+K` / `Cmd+K`.
class ShowCommandPaletteIntent extends Intent {
  const ShowCommandPaletteIntent();
}

/// Wraps the whole application so the palette can be summoned from any screen.
class CommandPaletteShortcuts extends StatelessWidget {
  const CommandPaletteShortcuts({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            ShowCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            ShowCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ShowCommandPaletteIntent: CallbackAction<ShowCommandPaletteIntent>(
            onInvoke: (ShowCommandPaletteIntent intent) {
              unawaited(showGlobalCommandPalette());
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

/// Shows the palette as a floating modal overlay above the root navigator.
Future<void> showCommandPalette() async {
  final NavigatorState? navigator = AppNavigator.key.currentState;
  if (navigator == null) {
    return;
  }
  await showDialog<void>(
    context: navigator.context,
    useRootNavigator: true,
    barrierColor: Colors.black45,
    barrierDismissible: true,
    builder: (BuildContext _) => BlocProvider<SearchBloc>(
      create: (_) => sl<SearchBloc>(),
      child: const CommandPalette(),
    ),
  );
}

/// The command palette modal: an auto-focused, debounced search bar with
/// categorized results and full keyboard navigation.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  static const double _tileHeight = 46;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  int _highlightedIndex = 0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SearchBloc>().add(const ExecuteGlobalSearchEvent(''));
      }
    });
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
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
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
      context.read<SearchBloc>().add(ExecuteGlobalSearchEvent(value));
    });
  }

  void _moveHighlight(int delta) {
    final List<_PaletteEntry> entries = _entries();
    if (entries.isEmpty) {
      return;
    }
    final int count = entries.length;
    final int next = (_highlightedIndex + delta) % count;
    setState(() {
      _highlightedIndex = next < 0 ? next + count : next;
    });
    final double target =
        (_highlightedIndex * _tileHeight) - (_tileHeight * 2);
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
    final List<_PaletteEntry> entries = _entries();
    if (entries.isEmpty ||
        _highlightedIndex < 0 ||
        _highlightedIndex >= entries.length) {
      return;
    }
    final _PaletteEntry entry = entries[_highlightedIndex];
    final _PaletteAction? action = entry.action;
    if (action != null) {
      action.onRun();
      return;
    }
    final SearchResultEntity? result = entry.result;
    if (result != null) {
      _openResult(result);
    }
  }

  List<_PaletteEntry> _entries() {
    final String query = _searchController.text.trim();
    final SearchState searchState = context.read<SearchBloc>().state;
    final List<SearchResultEntity> results =
        searchState is SearchResultsLoaded
        ? searchState.results
        : const <SearchResultEntity>[];
    return <_PaletteEntry>[
      if (query.isEmpty)
        ..._buildQuickActions().map(_PaletteEntry.action),
      ...results.map(_PaletteEntry.result),
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
        label: 'Open Settings',
        icon: Icons.settings_outlined,
        description: 'Backups, storage, and notifications',
        onRun: () => _goSection(AppSection.settings),
      ),
    ];
  }

  void _goSection(AppSection section) {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    sl<AppShellController>().select(section);
  }

  void _openResult(SearchResultEntity result) {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    final CompanyBloc? companyBloc = context.read<CompanyBloc>();
    navigator.pop();
    switch (result.category) {
      case SearchCategory.document:
        final String documentId = result.entityId ?? result.id;
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => DocumentVerificationPage(documentId: documentId),
            ),
          ),
        );
        break;
      case SearchCategory.company:
        final String companyId = result.entityId ?? result.id;
        companyBloc?.add(SelectActiveCompanyEvent(companyId));
        sl<AppShellController>().select(AppSection.dashboard);
        break;
      case SearchCategory.transaction:
        sl<AppShellController>().select(AppSection.reconciliation);
        break;
      case SearchCategory.taxRule:
        sl<AppShellController>().select(AppSection.taxCopilot);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SearchState searchState = context.watch<SearchBloc>().state;
    final String query = _searchController.text.trim();
    final List<SearchResultEntity> results =
        searchState is SearchResultsLoaded
        ? searchState.results
        : const <SearchResultEntity>[];
    final bool loading = searchState is SearchLoading;
    final bool empty = searchState is SearchEmpty;

    final List<_PaletteEntry> entries = _entries();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 24,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 620,
              maxHeight: 480,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _buildSearchField(theme),
                const Divider(height: 1),
                Flexible(child: _buildBody(theme, query, results, loading, empty)),
                _buildFooter(theme, entries),
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
          hintText: 'Search invoices, transactions, companies…',
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
              children: <Widget>[
                _KeyHint(label: '↑↓'),
                const SizedBox(width: 4),
                _KeyHint(label: '↵'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    String query,
    List<SearchResultEntity> results,
    bool loading,
    bool empty,
  ) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(),
      );
    }
    if (query.isNotEmpty && empty) {
      return _EmptyMessage(query: query);
    }

    final List<_PaletteEntry> entries = _entries();
    final bool showActions = query.isEmpty;
    final Map<SearchCategory, List<SearchResultEntity>> grouped =
        <SearchCategory, List<SearchResultEntity>>{};
    for (final SearchResultEntity result in results) {
      grouped.putIfAbsent(result.category, () => <SearchResultEntity>[]).add(
            result,
          );
    }

    int runningIndex = showActions ? _buildQuickActions().length : 0;
    final List<Widget> children = <Widget>[];
    if (showActions) {
      children.add(const _SectionHeader(label: 'Quick actions'));
      for (final _PaletteAction action in _buildQuickActions()) {
        children.add(
          _PaletteTile(
            entry: _PaletteEntry.action(action),
            highlighted: _highlightedIndex == runningIndex,
            onTap: action.onRun,
          ),
        );
        runningIndex += 1;
      }
    }

    for (final MapEntry<SearchCategory, List<SearchResultEntity>> group
        in grouped.entries) {
      children.add(_SectionHeader(label: group.key.label));
      for (final SearchResultEntity result in group.value) {
        children.add(
          _PaletteTile(
            entry: _PaletteEntry.result(result),
            highlighted: _highlightedIndex == runningIndex,
            onTap: () => _openResult(result),
          ),
        );
        runningIndex += 1;
      }
    }

    if (children.isEmpty) {
      return const _EmptyMessage(query: null);
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 6),
      shrinkWrap: true,
      children: children,
    );
  }

  Widget _buildFooter(ThemeData theme, List<_PaletteEntry> entries) {
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
            Icons.keyboard_command_key_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'K to open',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '${entries.length} result${entries.length == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteEntry {
  const _PaletteEntry.action(this.action) : result = null;
  const _PaletteEntry.result(this.result) : action = null;

  final _PaletteAction? action;
  final SearchResultEntity? result;
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
  });

  final _PaletteEntry entry;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final IconData icon = entry.action?.icon ?? _categoryIcon(entry.result!);
    final String title = entry.action?.label ?? entry.result!.title;
    final String subtitle =
        entry.action?.description ?? entry.result!.subtitle;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
              width: 30,
              height: 30,
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

  static IconData _categoryIcon(SearchResultEntity result) {
    return switch (result.category) {
      SearchCategory.document => Icons.description_outlined,
      SearchCategory.company => Icons.business_outlined,
      SearchCategory.transaction => Icons.swap_horiz_rounded,
      SearchCategory.taxRule => Icons.gavel_outlined,
    };
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({this.query});

  final String? query;

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
            query == null
                ? 'Start typing to search'
                : 'No results for "$query"',
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
