import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../../company/domain/entities/company_entity.dart';
import '../../../document_ocr/presentation/company_context.dart';
import '../../domain/entities/tax_query_entity.dart';
import '../../domain/repositories/tax_copilot_repository.dart';
import '../bloc/tax_copilot_bloc.dart';
import '../bloc/tax_copilot_event.dart';
import '../bloc/tax_copilot_state.dart';
import '../widgets/citation_card.dart';

const List<String> _quickPrompts = <String>[
  'How to treat software license imports for VAT?',
  'Simplified tax thresholds and exemption rules',
  'Employee dividend withholding rates',
];

const List<String> _conversationFilters = <String>[
  'All',
  'Tax Code',
  'Labor Code',
  'IFRS Standards',
];

const Color _navyMessageColor = Color(0xff102a43);

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
            repository: repository,
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
    required this.repository,
  });

  final String? companyId;
  final String? companyName;
  final TaxCopilotRepository repository;

  @override
  State<_TaxCopilotWorkspace> createState() => _TaxCopilotWorkspaceState();
}

class _TaxCopilotWorkspaceState extends State<_TaxCopilotWorkspace> {
  late final TextEditingController _questionController;
  late final ScrollController _chatScrollController;
  String _selectedFilter = 'All';
  String? _attachedFileName;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController();
    _chatScrollController = ScrollController();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) {
        return;
      }
      final double maxScroll = _chatScrollController.position.maxScrollExtent;
      _chatScrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _submitQuestion([String? suggestedQuestion]) {
    final TaxCopilotBloc bloc = context.read<TaxCopilotBloc>();
    if (bloc.state is TaxCopilotThinking) {
      return;
    }

    final String question = (suggestedQuestion ?? _questionController.text)
        .trim();
    if (question.isEmpty) {
      return;
    }
    final String? companyId = widget.companyId;
    if (companyId == null || companyId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a company before asking.')),
      );
      return;
    }

    _questionController.clear();
    bloc.add(AskTaxQuestionEvent(question, companyId));
    _scheduleScrollToBottom();
  }

  void _startNewChat() {
    _questionController.clear();
    setState(() => _attachedFileName = null);
    context.read<TaxCopilotBloc>().add(const StartNewChatEvent());
  }

  void _selectThread(TaxQueryEntity query) {
    context.read<TaxCopilotBloc>().add(SelectTaxQueryEvent(query));
    _scheduleScrollToBottom();
  }

  Future<void> _attachDocument() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'png', 'jpg', 'jpeg'],
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    setState(() => _attachedFileName = result.files.first.name);
  }

  List<TaxQueryEntity> _filteredHistory(List<TaxQueryEntity> history) {
    if (_selectedFilter == 'All') {
      return history;
    }
    return history
        .where((TaxQueryEntity query) => _matchesFilter(query, _selectedFilter))
        .toList(growable: false);
  }

  bool _matchesFilter(TaxQueryEntity query, String filter) {
    final String searchable =
        '${query.question} ${query.answer} ${query.citedArticles.join(' ')}'
            .toLowerCase();
    switch (filter) {
      case 'Labor Code':
        return searchable.contains('labor') ||
            searchable.contains('employee') ||
            searchable.contains('salary') ||
            searchable.contains('withholding');
      case 'IFRS Standards':
        return searchable.contains('ifrs') ||
            searchable.contains('financial reporting') ||
            searchable.contains('standard');
      case 'Tax Code':
        return searchable.contains('tax') ||
            searchable.contains('vat') ||
            query.citedArticles.isNotEmpty;
      case 'All':
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasCompany = widget.companyId != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax & Legal AI Copilot'),
        actions: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.storage_rounded,
                  size: 15,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Local corpus grounded',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
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
      body: BlocConsumer<TaxCopilotBloc, TaxCopilotState>(
        listener: (BuildContext context, TaxCopilotState state) {
          _scheduleScrollToBottom();
        },
        builder: (BuildContext context, TaxCopilotState state) {
          final List<TaxQueryEntity> filteredHistory =
              _filteredHistory(state.history);
          return Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                if (constraints.maxWidth < 900) {
                  return Column(
                    children: <Widget>[
                      SizedBox(
                        height: 240,
                        child: _ThreadSidebar(
                          history: filteredHistory,
                          totalHistoryCount: state.history.length,
                          selectedFilter: _selectedFilter,
                          selectedQueryId: state.currentQuery?.id,
                          onFilterChanged: (String filter) =>
                              setState(() => _selectedFilter = filter),
                          onNewChat: _startNewChat,
                          onSelect: _selectThread,
                          onClear: hasCompany
                              ? () => context.read<TaxCopilotBloc>().add(
                                    ClearChatHistoryEvent(widget.companyId!),
                                  )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _ChatPanel(
                          state: state,
                          controller: _questionController,
                          chatScrollController: _chatScrollController,
                          hasCompany: hasCompany,
                          onSubmit: _submitQuestion,
                          onPromptSelected: _submitQuestion,
                          onAttach: _attachDocument,
                          attachedFileName: _attachedFileName,
                          onRemoveAttachment: () =>
                              setState(() => _attachedFileName = null),
                          onCitation: (String articleCode) =>
                              showCitationArticleDrawer(
                            context: context,
                            repository: widget.repository,
                            articleCode: articleCode,
                          ),
                          onStreamProgress: _scheduleScrollToBottom,
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: _ThreadSidebar(
                        history: filteredHistory,
                        totalHistoryCount: state.history.length,
                        selectedFilter: _selectedFilter,
                        selectedQueryId: state.currentQuery?.id,
                        onFilterChanged: (String filter) =>
                            setState(() => _selectedFilter = filter),
                        onNewChat: _startNewChat,
                        onSelect: _selectThread,
                        onClear: hasCompany
                            ? () => context.read<TaxCopilotBloc>().add(
                                  ClearChatHistoryEvent(widget.companyId!),
                                )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: _ChatPanel(
                        state: state,
                        controller: _questionController,
                        chatScrollController: _chatScrollController,
                        hasCompany: hasCompany,
                        onSubmit: _submitQuestion,
                        onPromptSelected: _submitQuestion,
                        onAttach: _attachDocument,
                        attachedFileName: _attachedFileName,
                        onRemoveAttachment: () =>
                            setState(() => _attachedFileName = null),
                        onCitation: (String articleCode) =>
                            showCitationArticleDrawer(
                          context: context,
                          repository: widget.repository,
                          articleCode: articleCode,
                        ),
                        onStreamProgress: _scheduleScrollToBottom,
                      ),
                    ),
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

class _ThreadSidebar extends StatelessWidget {
  const _ThreadSidebar({
    required this.history,
    required this.totalHistoryCount,
    required this.selectedFilter,
    required this.selectedQueryId,
    required this.onFilterChanged,
    required this.onNewChat,
    required this.onSelect,
    required this.onClear,
  });

  final List<TaxQueryEntity> history;
  final int totalHistoryCount;
  final String selectedFilter;
  final String? selectedQueryId;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onNewChat;
  final ValueChanged<TaxQueryEntity> onSelect;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withAlpha(24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.forum_outlined,
                    size: 18,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Conversations',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (onClear != null)
                  IconButton(
                    tooltip: 'Clear history',
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Chat'),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Quick filters',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _conversationFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (BuildContext context, int index) {
                  final String filter = _conversationFilters[index];
                  return ChoiceChip(
                    label: Text(filter),
                    selected: filter == selectedFilter,
                    onSelected: (_) => onFilterChanged(filter),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Text(
                  selectedFilter == 'All' ? 'Recent threads' : selectedFilter,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalHistoryCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Expanded(
              child: history.isEmpty
                  ? _ThreadEmptyState(filter: selectedFilter)
                  : ListView.builder(
                      itemCount: history.length,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final TaxQueryEntity query = history[index];
                        return _ThreadListTile(
                          query: query,
                          selected: query.id == selectedQueryId,
                          onTap: () => onSelect(query),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({
    required this.query,
    required this.selected,
    required this.onTap,
  });

  final TaxQueryEntity query;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? accent.withAlpha(20)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(45),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  query.question,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[
                    Icon(Icons.schedule_outlined, size: 13, color: accent),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat('dd MMM, HH:mm')
                            .format(query.timestamp.toLocal()),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (query.citedArticles.isNotEmpty)
                      Text(
                        '${query.citedArticles.length} cites',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadEmptyState extends StatelessWidget {
  const _ThreadEmptyState({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool filtered = filter != 'All';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              filtered ? Icons.filter_alt_off_outlined : Icons.forum_outlined,
              size: 34,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 9),
            Text(
              filtered ? 'No matching threads' : 'No previous chats',
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

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.state,
    required this.controller,
    required this.chatScrollController,
    required this.hasCompany,
    required this.onSubmit,
    required this.onPromptSelected,
    required this.onAttach,
    required this.attachedFileName,
    required this.onRemoveAttachment,
    required this.onCitation,
    required this.onStreamProgress,
  });

  final TaxCopilotState state;
  final TextEditingController controller;
  final ScrollController chatScrollController;
  final bool hasCompany;
  final VoidCallback onSubmit;
  final ValueChanged<String> onPromptSelected;
  final VoidCallback onAttach;
  final String? attachedFileName;
  final VoidCallback onRemoveAttachment;
  final ValueChanged<String> onCitation;
  final VoidCallback onStreamProgress;

  List<_ChatMessage> _messages() {
    final List<_ChatMessage> messages = <_ChatMessage>[];
    final TaxQueryEntity? query = state.currentQuery;
    if (query != null) {
      messages
        ..add(_ChatMessage.user(query.question))
        ..add(
          _ChatMessage.assistant(
            query.answer,
            query: query,
            animate: state is TaxCopilotAnswerReceived,
          ),
        );
    }

    final String? activeQuestion = state.activeQuestion;
    if (activeQuestion != null &&
        (state is TaxCopilotThinking || state is TaxCopilotFailure)) {
      if (query == null || query.question != activeQuestion) {
        messages.add(_ChatMessage.user(activeQuestion));
      }
      if (state is TaxCopilotThinking) {
        messages.add(_ChatMessage.thinking());
      }
    }

    if (state is TaxCopilotFailure) {
      final TaxCopilotFailure failure = state as TaxCopilotFailure;
      messages.add(_ChatMessage.error(failure.message));
    }
    return messages;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool thinking = state is TaxCopilotThinking;
    final List<_ChatMessage> messages = _messages();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 13),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(65),
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tax & Legal Copilot',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ask grounded questions and inspect the cited source articles.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (thinking)
                  const _StatusPill(
                    label: 'Thinking',
                    icon: Icons.bolt_rounded,
                  )
                else
                  const _StatusPill(
                    label: 'Ready',
                    icon: Icons.check_circle_outline_rounded,
                  ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const _WelcomeConversation()
                : ListView.builder(
                    controller: chatScrollController,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    itemCount: messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _ChatMessageBubble(
                        message: messages[index],
                        onCitation: onCitation,
                        onStreamProgress: onStreamProgress,
                      );
                    },
                  ),
          ),
          _Composer(
            controller: controller,
            enabled: hasCompany && !thinking,
            loading: thinking,
            onSubmit: onSubmit,
            onPromptSelected: onPromptSelected,
            onAttach: onAttach,
            attachedFileName: attachedFileName,
            onRemoveAttachment: onRemoveAttachment,
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.role,
    required this.text,
    this.query,
    this.animate = false,
  });

  const _ChatMessage.user(String text)
      : this(role: _ChatRole.user, text: text);

  const _ChatMessage.assistant(
    String text, {
    required TaxQueryEntity query,
    bool animate = false,
  }) : this(
          role: _ChatRole.assistant,
          text: text,
          query: query,
          animate: animate,
        );

  const _ChatMessage.thinking()
      : this(role: _ChatRole.thinking, text: '');

  const _ChatMessage.error(String text)
      : this(role: _ChatRole.error, text: text);

  final _ChatRole role;
  final String text;
  final TaxQueryEntity? query;
  final bool animate;
}

enum _ChatRole { user, assistant, thinking, error }

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.onCitation,
    required this.onStreamProgress,
  });

  final _ChatMessage message;
  final ValueChanged<String> onCitation;
  final VoidCallback onStreamProgress;

  @override
  Widget build(BuildContext context) {
    switch (message.role) {
      case _ChatRole.user:
        return _UserMessageBubble(text: message.text);
      case _ChatRole.assistant:
        return _AssistantMessageBubble(
          text: message.text,
          query: message.query,
          animate: message.animate,
          onCitation: onCitation,
          onStreamProgress: onStreamProgress,
        );
      case _ChatRole.thinking:
        return const _ThinkingBubble();
      case _ChatRole.error:
        return _ErrorMessageBubble(message: message.text);
    }
  }
}

class _UserMessageBubble extends StatelessWidget {
  const _UserMessageBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _navyMessageColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(5),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _navyMessageColor.withAlpha(24),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const _MessageAvatar(
                icon: Icons.person_outline_rounded,
                dark: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantMessageBubble extends StatelessWidget {
  const _AssistantMessageBubble({
    required this.text,
    required this.query,
    required this.animate,
    required this.onCitation,
    required this.onStreamProgress,
  });

  final String text;
  final TaxQueryEntity? query;
  final bool animate;
  final ValueChanged<String> onCitation;
  final VoidCallback onStreamProgress;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> citations = query?.citedArticles ?? const <String>[];
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _MessageAvatar(
                icon: Icons.auto_awesome_rounded,
                dark: false,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(75),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(60),
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(5),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _StreamingMarkdown(
                        text: text,
                        animate: animate,
                        onProgress: onStreamProgress,
                      ),
                      if (citations.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 15),
                        Text(
                          'Cited source articles',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: citations
                              .map(
                                (String articleCode) => CitationCard(
                                  articleCode: articleCode,
                                  onOpen: () => onCitation(articleCode),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamingMarkdown extends StatefulWidget {
  const _StreamingMarkdown({
    required this.text,
    required this.animate,
    required this.onProgress,
  });

  final String text;
  final bool animate;
  final VoidCallback onProgress;

  @override
  State<_StreamingMarkdown> createState() => _StreamingMarkdownState();
}

class _StreamingMarkdownState extends State<_StreamingMarkdown> {
  Timer? _timer;
  int _visibleCharacters = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _StreamingMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.animate != widget.animate) {
      _start();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    if (!widget.animate || widget.text.isEmpty) {
      _visibleCharacters = widget.text.length;
      return;
    }
    _visibleCharacters = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 18), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final int increment = math.max(1, widget.text.length ~/ 90).toInt();
      setState(() {
        _visibleCharacters =
            math.min(widget.text.length, _visibleCharacters + increment).toInt();
      });
      widget.onProgress();
      if (_visibleCharacters >= widget.text.length) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int visible = math.min(_visibleCharacters, widget.text.length).toInt();
    final String renderedText = widget.text.substring(0, visible);
    final MarkdownStyleSheet markdownStyle = MarkdownStyleSheet.fromTheme(theme)
        .copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
      h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      code: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surface,
      ),
      blockquote: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
    return MarkdownBody(
      data: renderedText,
      selectable: true,
      styleSheet: markdownStyle,
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const _MessageAvatar(
              icon: Icons.auto_awesome_rounded,
              dark: false,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 620),
                padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(75),
                  border: Border.all(
                    color: theme.colorScheme.outline.withAlpha(60),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    final double opacity = 0.35 + _controller.value * 0.65;
                    final Color shimmerColor = Color.lerp(
                      theme.colorScheme.onSurfaceVariant.withAlpha(55),
                      theme.colorScheme.secondary.withAlpha(150),
                      _controller.value,
                    )!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Reviewing the indexed articles…',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Grounding the answer before it is sent',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 13),
                        _ShimmerBar(
                          widthFactor: 0.78,
                          color: shimmerColor,
                          opacity: opacity,
                        ),
                        const SizedBox(height: 7),
                        _ShimmerBar(
                          widthFactor: 0.94,
                          color: shimmerColor,
                          opacity: opacity * 0.9,
                        ),
                        const SizedBox(height: 7),
                        _ShimmerBar(
                          widthFactor: 0.52,
                          color: shimmerColor,
                          opacity: opacity * 0.8,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({
    required this.widthFactor,
    required this.color,
    required this.opacity,
  });

  final double widthFactor;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: color.withAlpha(
            (opacity.clamp(0, 1).toDouble() * 255).round(),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _ErrorMessageBubble extends StatelessWidget {
  const _ErrorMessageBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withAlpha(15),
          border: Border.all(color: theme.colorScheme.error.withAlpha(70)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeConversation extends StatelessWidget {
  const _WelcomeConversation();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.policy_outlined,
              size: 50,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Ask a grounded tax question',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Choose a quick prompt below or describe the transaction you need to review.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.loading,
    required this.onSubmit,
    required this.onPromptSelected,
    required this.onAttach,
    required this.attachedFileName,
    required this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool loading;
  final VoidCallback onSubmit;
  final ValueChanged<String> onPromptSelected;
  final VoidCallback onAttach;
  final String? attachedFileName;
  final VoidCallback onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withAlpha(65)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Quick prompts',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.bolt_rounded,
                size: 15,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (BuildContext context, int index) {
                final String prompt = _quickPrompts[index];
                return ActionChip(
                  label: Text(prompt),
                  onPressed: enabled ? () => onPromptSelected(prompt) : null,
                  avatar: const Icon(Icons.auto_awesome_outlined, size: 15),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
          if (attachedFileName != null) ...<Widget>[
            const SizedBox(height: 8),
            InputChip(
              avatar: const Icon(Icons.attach_file_rounded, size: 16),
              label: Text(
                attachedFileName!,
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: onRemoveAttachment,
            ),
          ],
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(75),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: theme.colorScheme.outline.withAlpha(75)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                IconButton(
                  tooltip: 'Attach document',
                  onPressed: enabled ? onAttach : null,
                  icon: const Icon(Icons.attach_file_rounded),
                ),
                Expanded(
                  child: Shortcuts(
                    shortcuts: <ShortcutActivator, Intent>{
                      const SingleActivator(LogicalKeyboardKey.enter):
                          const _SendMessageIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _SendMessageIntent:
                            CallbackAction<_SendMessageIntent>(
                          onInvoke: (_SendMessageIntent intent) {
                            onSubmit();
                            return null;
                          },
                        ),
                      },
                      child: TextField(
                        controller: controller,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: enabled
                              ? 'Ask about VAT, payroll, thresholds, or an article…'
                              : 'Select a company to start a conversation',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: IconButton.filled(
                    tooltip: loading ? 'Generating response' : 'Send question',
                    onPressed: enabled ? onSubmit : null,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 19),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter to send  •  Shift + Enter for a new line  •  '
            'Responses are grounded in the local corpus',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendMessageIntent extends Intent {
  const _SendMessageIntent();
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.icon,
    required this.dark,
  });

  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: dark
            ? _navyMessageColor.withAlpha(18)
            : theme.colorScheme.secondary.withAlpha(25),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        size: 17,
        color: dark ? _navyMessageColor : theme.colorScheme.secondary,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: theme.colorScheme.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
