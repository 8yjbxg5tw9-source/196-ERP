import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../../shared/navigation/app_shell_controller.dart';
import '../../domain/entities/entity_lineage_node.dart';
import '../../domain/entities/entity_type.dart';
import '../bloc/global_search_bloc.dart';
import '../bloc/global_search_event.dart';
import '../bloc/global_search_state.dart';

/// Opens the deep entity lineage inspector as a modal bottom sheet.
Future<void> showEntityLineageDrawer(
  BuildContext context, {
  required String entityId,
  required EntityType type,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) =>
        EntityLineageDrawer(entityId: entityId, entityType: type),
  );
}

/// Interactive node-chain diagram tracing a record's full lifecycle from its
/// source document through posting (e.g. `Invoice (OCR) → Bank Payment → GL`).
class EntityLineageDrawer extends StatefulWidget {
  const EntityLineageDrawer({
    required this.entityId,
    required this.entityType,
    super.key,
  });

  final String entityId;
  final EntityType entityType;

  @override
  State<EntityLineageDrawer> createState() => _EntityLineageDrawerState();
}

class _EntityLineageDrawerState extends State<EntityLineageDrawer> {
  late final GlobalSearchBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = sl<GlobalSearchBloc>()
      ..add(
        FetchEntityLineageEvent(
          entityId: widget.entityId,
          type: widget.entityType,
        ),
      );
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.62,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(theme),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<GlobalSearchBloc, GlobalSearchState>(
                bloc: _bloc,
                builder: (BuildContext context, GlobalSearchState state) {
                  return switch (state) {
                    GlobalSearchLoading() =>
                      const Center(child: CircularProgressIndicator()),
                    GlobalSearchError(:final message) =>
                      _ErrorView(message: message),
                    EntityLineageLoaded(
                      :final rootNode,
                      :final nodes,
                    ) =>
                      _buildChain(theme, rootNode, nodes),
                    _ => const _ErrorView(
                        message: 'No lineage information available.',
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.account_tree_outlined, color: theme.colorScheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Entity Lineage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${widget.entityType.label} · ${widget.entityId}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildChain(
    ThemeData theme,
    EntityLineageNode root,
    List<EntityLineageNode> nodes,
  ) {
    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                for (int index = 0; index < nodes.length; index++) ...<Widget>[
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  _NodeCard(
                    node: nodes[index],
                    isRoot: nodes[index].id == root.id,
                    onTap: () => _inspectNode(context, nodes[index]),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Click any node to inspect its raw metadata or open the '
                  'source record.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _inspectNode(BuildContext context, EntityLineageNode node) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => _NodeInspectorDialog(
        node: node,
        onOpen: () {
          Navigator.of(dialogContext).pop();
          _navigateToSource(node);
        },
      ),
    );
  }

  void _navigateToSource(EntityLineageNode node) {
    final AppSection? section = _sectionFor(node.entityType);
    if (section == null) {
      return;
    }
    Navigator.of(context).pop();
    sl<AppShellController>().select(section);
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
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.isRoot,
    required this.onTap,
  });

  final EntityLineageNode node;
  final bool isRoot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = isRoot
        ? theme.colorScheme.secondary
        : theme.colorScheme.primary;
    final String amount = '₼${node.amount.toStringAsFixed(2)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
          border: Border.all(color: accent.withAlpha(160), width: isRoot ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (isRoot) ...<Widget>[
                  Icon(Icons.center_focus_strong_rounded,
                      size: 14, color: accent),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    node.nodeType,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              node.description.isEmpty ? '—' : node.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    amount,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    node.status,
                    style: theme.textTheme.labelSmall?.copyWith(color: accent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeInspectorDialog extends StatelessWidget {
  const _NodeInspectorDialog({required this.node, required this.onOpen});

  final EntityLineageNode node;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String json = const JsonEncoder.withIndent('  ').convert(
      node.rawMetadata.isEmpty
          ? <String, Object?>{
              'id': node.id,
              'nodeType': node.nodeType,
              'description': node.description,
              'amount': node.amount,
              'status': node.status,
              'timestamp': node.timestamp.toIso8601String(),
            }
          : node.rawMetadata,
    );

    return AlertDialog(
      title: Row(
        children: <Widget>[
          Expanded(child: Text(node.nodeType)),
          IconButton(
            tooltip: 'Open source record',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              json,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.account_tree_outlined,
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
