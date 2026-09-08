import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/tax_query_entity.dart';
import '../../domain/repositories/tax_copilot_repository.dart';
import '../bloc/tax_copilot_bloc.dart';
import '../bloc/tax_copilot_event.dart';
import '../bloc/tax_copilot_state.dart';

/// User-facing RAG workspace for tax, labor, and financial compliance queries.
class TaxCopilotPage extends StatelessWidget {
  const TaxCopilotPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CompanyContextBuilder(
      builder: (BuildContext context, CompanyEntity? activeCompany) {
        final TaxCopilotRepository repository =
            context.read<TaxCopilotRepository>();
        final String companyId = activeCompany?.id ?? '';
        return BlocProvider<TaxCopilotBloc>(
          create: (_) => TaxCopilotBloc(repository: repository)
            ..add(LoadTaxHistoryEvent(companyId)),
          child: _TaxCopilotWorkspace(
            companyId: activeCompany?.id,
            companyName: activeCompany?.name,
          ),
        );
      },
    );
  }
}

class _TaxCopilotWorkspace extends StatefulWidget {
  const _TaxCopilotWorkspace({
    required this.companyId,
    required this.companyName,
  });

  final String? companyId;
  final String? companyName;

  @override
  State<_TaxCopilotWorkspace> createState() => _TaxCopilotWorkspaceState();
}

class _TaxCopilotWorkspaceState extends State<_TaxCopilotWorkspace> {
  late final TextEditingController _questionController;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasCompany = widget.companyId != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax & Legal AI Copilot'),
        actions: <Widget>[
          if (widget.companyName != null)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Center(
                child: Text(
                  widget.companyName!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: BlocBuilder<TaxCopilotBloc, TaxCopilotState>(
        builder: (BuildContext context, TaxCopilotState state) {
          final Widget questionPanel = _QuestionPanel(
            controller: _questionController,
            enabled: hasCompany && state is! TaxCopilotThinking,
            loading: state is TaxCopilotThinking,
            errorMessage: state is TaxCopilotFailure ? state.message : null,
            onAsk: () {
              final String? companyId = widget.companyId;
              if (companyId == null) {
                return;
              }
              context.read<TaxCopilotBloc>().add(
                    AskTaxQuestionEvent(
                      _questionController.text,
                      companyId,
                    ),
                  );
            },
          );
          final TaxQueryEntity? currentQuery = state.currentQuery;
          final Widget answerPanel = currentQuery == null
              ? const _EmptyAnswerPanel()
              : _AnswerPanel(query: currentQuery);
          final Widget historyPanel = _HistoryPanel(
            history: state.history,
            onClear: state.history.isEmpty || !hasCompany
                ? null
                : () => context.read<TaxCopilotBloc>().add(
                      ClearChatHistoryEvent(widget.companyId!),
                    ),
          );

          return Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth < 980) {
                  return ListView(
                    children: <Widget>[
                      questionPanel,
                      const SizedBox(height: 14),
                      answerPanel,
                      const SizedBox(height: 14),
                      SizedBox(height: 420, child: historyPanel),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: ListView(
                        children: <Widget>[
                          questionPanel,
                          const SizedBox(height: 14),
                          answerPanel,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(width: 330, child: historyPanel),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _QuestionPanel extends StatelessWidget {
  const _QuestionPanel({
    required this.controller,
    required this.enabled,
    required this.loading,
    required this.errorMessage,
    required this.onAsk,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ask the indexed legal corpus',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Answers are grounded in retrieved articles and include direct citations.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              enabled: enabled,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Tax, labor, or compliance question',
                hintText:
                    'For example: Which article governs the VAT treatment of this expense?',
                alignLabelWithHint: true,
              ),
              onSubmitted: enabled ? (_) => onAsk() : null,
            ),
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              _InlineError(message: errorMessage!),
            ],
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: enabled ? onAsk : null,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 17),
                label: Text(loading ? 'Retrieving…' : 'Ask Copilot'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerPanel extends StatelessWidget {
  const _AnswerPanel({required this.query});

  final TaxQueryEntity query;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.verified_outlined,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Grounded answer',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SelectableText(
              query.answer,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 18),
            Text(
              'Cited articles',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (query.citedArticles.isEmpty)
              Text(
                'No indexed article was cited for this response.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: query.citedArticles
                    .map(
                      (String article) => Chip(
                        avatar: const Icon(Icons.menu_book_outlined, size: 15),
                        label: Text('Article $article'),
                      ),
                    )
                    .toList(growable: false),
              ),
            const SizedBox(height: 12),
            Text(
              'Asked ${DateFormat('dd.MM.yyyy HH:mm').format(query.timestamp.toLocal())}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAnswerPanel extends StatelessWidget {
  const _EmptyAnswerPanel();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: SizedBox(
        height: 260,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.policy_outlined,
                  size: 44,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your cited answer will appear here.',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'The copilot retrieves relevant articles before it answers.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({
    required this.history,
    required this.onClear,
  });

  final List<TaxQueryEntity> history;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Query history',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: 'Clear chat history',
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  ),
              ],
            ),
            Text(
              'Company-scoped audit trail',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: history.isEmpty
                  ? const _HistoryMessage(
                      message: 'No questions have been asked yet.',
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(height: 18),
                      itemBuilder: (BuildContext context, int index) {
                        return _HistoryItem(query: history[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.query});

  final TaxQueryEntity query;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          query.question,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          query.citedArticles.isEmpty
              ? 'No citations'
              : query.citedArticles.map((String item) => 'Art. $item').join(' · '),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          DateFormat('dd.MM.yyyy HH:mm').format(query.timestamp.toLocal()),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withAlpha(15),
        border: Border.all(color: theme.colorScheme.error.withAlpha(80)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
