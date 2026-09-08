import 'dart:math' as math;

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/tax_rule_entity.dart';
import '../../domain/repositories/tax_copilot_repository.dart';

/// A compact citation badge that can expand and open the complete local article.
class CitationCard extends StatefulWidget {
  const CitationCard({
    required this.articleCode,
    required this.onOpen,
    this.articleTitle,
    super.key,
  });

  final String articleCode;
  final String? articleTitle;
  final VoidCallback onOpen;

  @override
  State<CitationCard> createState() => _CitationCardState();
}

class _CitationCardState extends State<CitationCard> {
  bool _expanded = false;

  String get _displayCode {
    final String value = widget.articleCode.trim();
    return value.toLowerCase().startsWith('article ')
        ? value
        : 'Article $value';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = theme.colorScheme.secondary;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.menu_book_outlined, size: 16, color: accent),
                const SizedBox(width: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _displayCode,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_expanded && widget.articleTitle != null)
                        Text(
                          widget.articleTitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (_expanded)
                        Text(
                          'Open full article',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Collapse citation' : 'Expand citation',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
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

/// Opens a desktop slide-over containing the raw article stored in SQLite.
Future<void> showCitationArticleDrawer({
  required BuildContext context,
  required TaxCopilotRepository repository,
  required String articleCode,
}) {
  final Future<Either<Failure, TaxRuleEntity?>> articleFuture =
      repository.getTaxRuleByArticleCode(articleCode);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close citation article',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      final Size size = MediaQuery.sizeOf(dialogContext);
      final double panelWidth = size.width < 700
          ? size.width * 0.92
          : math.min(560.0, size.width * 0.44).toDouble();
      return SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: panelWidth,
            height: double.infinity,
            child: _CitationArticlePanel(
              articleCode: articleCode,
              articleFuture: articleFuture,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<Offset> slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );
      return SlideTransition(position: slide, child: child);
    },
  );
}

class _CitationArticlePanel extends StatelessWidget {
  const _CitationArticlePanel({
    required this.articleCode,
    required this.articleFuture,
  });

  final String articleCode;
  final Future<Either<Failure, TaxRuleEntity?>> articleFuture;

  String get _displayCode {
    final String value = articleCode.trim();
    return value.toLowerCase().startsWith('article ')
        ? value
        : 'Article $value';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 14),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.menu_book_rounded,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _displayCode,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close article',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outline.withAlpha(70),
          ),
          Expanded(
            child: FutureBuilder<Either<Failure, TaxRuleEntity?>>(
              future: articleFuture,
              builder: (
                BuildContext context,
                AsyncSnapshot<Either<Failure, TaxRuleEntity?>> snapshot,
              ) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final Either<Failure, TaxRuleEntity?>? result = snapshot.data;
                if (result == null) {
                  return const _ArticlePanelMessage(
                    icon: Icons.menu_book_outlined,
                    message: 'The cited article could not be loaded.',
                  );
                }
                return result.fold<Widget>(
                  (Failure failure) => _ArticlePanelMessage(
                    icon: Icons.error_outline_rounded,
                    message: failure.message,
                  ),
                  (TaxRuleEntity? rule) {
                    if (rule == null) {
                      return const _ArticlePanelMessage(
                        icon: Icons.search_off_rounded,
                        message: 'This article is not indexed locally.',
                      );
                    }
                    return _ArticleText(rule: rule);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleText extends StatelessWidget {
  const _ArticleText({required this.rule});

  final TaxRuleEntity rule;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String rawText = rule.content.trim().isEmpty
        ? 'No full article text is available in the local corpus.'
        : rule.content;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
      children: <Widget>[
        Text(
          rule.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(
              avatar: const Icon(Icons.category_outlined, size: 15),
              label: Text(rule.category),
            ),
            Chip(
              avatar: const Icon(Icons.verified_outlined, size: 15),
              label: const Text('Indexed locally'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SelectableText(
          rawText,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
        ),
      ],
    );
  }
}

class _ArticlePanelMessage extends StatelessWidget {
  const _ArticlePanelMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 42, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
