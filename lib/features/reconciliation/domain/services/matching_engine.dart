import '../../../document_ocr/domain/entities/document_entity.dart';
import '../entities/bank_transaction_entity.dart';

/// Confidence tiers emitted by the deterministic reconciliation engine.
class MatchingEngine {
  const MatchingEngine({
    this.amountTolerance = 0.01,
    this.dateWindow = const Duration(days: 5),
    this.fuzzyNameThreshold = 0.70,
  });

  final double amountTolerance;
  final Duration dateWindow;
  final double fuzzyNameThreshold;

  /// Matches each bank line to at most one approved document.
  ///
  /// Exact VÖEN and amount matches are preferred, followed by the high and
  /// medium confidence heuristics. Reconciled transactions are left untouched
  /// so a later auto-match run cannot undo an accountant's confirmation.
  List<BankTransactionEntity> matchTransactions(
    Iterable<BankTransactionEntity> transactions,
    Iterable<DocumentEntity> approvedDocuments,
  ) {
    final List<BankTransactionEntity> inputTransactions = transactions.toList(
      growable: false,
    );
    final List<DocumentEntity> documents = approvedDocuments
        .where((DocumentEntity document) =>
            _isMatchableDocument(document) &&
            document.totalAmount != null &&
            document.totalAmount!.isFinite)
        .toList(growable: false);
    final Set<String> usedDocumentIds = <String>{
      for (final BankTransactionEntity transaction in inputTransactions)
        if (transaction.status == MatchStatus.reconciled &&
            transaction.matchedDocumentId != null)
          transaction.matchedDocumentId!,
    };

    final List<BankTransactionEntity> matched = <BankTransactionEntity>[];
    for (final BankTransactionEntity transaction in inputTransactions) {
      if (transaction.status == MatchStatus.reconciled) {
        matched.add(transaction);
        continue;
      }

      final _MatchDecision? decision = _findDecision(
        transaction,
        documents,
        usedDocumentIds,
      );
      if (decision == null) {
        matched.add(
          transaction.copyWith(
            matchedDocumentId: null,
            matchConfidence: 0,
            status: MatchStatus.unmatched,
          ),
        );
        continue;
      }

      usedDocumentIds.add(decision.document.id);
      matched.add(
        transaction.copyWith(
          matchedDocumentId: decision.document.id,
          matchConfidence: decision.confidence,
          status: MatchStatus.suggested,
        ),
      );
    }
    return matched;
  }

  /// Alias kept small and convenient for callers that treat the engine as a
  /// pure matcher.
  List<BankTransactionEntity> match(
    Iterable<BankTransactionEntity> transactions,
    Iterable<DocumentEntity> approvedDocuments,
  ) {
    return matchTransactions(transactions, approvedDocuments);
  }

  /// Returns the normalized fuzzy similarity used by the 0.85 confidence tier.
  double nameSimilarity(String? left, String? right) {
    final String normalizedLeft = _normalizeText(left);
    final String normalizedRight = _normalizeText(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return 0;
    }
    if (normalizedLeft == normalizedRight) {
      return 1;
    }

    final Set<String> leftTokens = normalizedLeft.split(' ').toSet();
    final Set<String> rightTokens = normalizedRight.split(' ').toSet();
    final int intersection = leftTokens.intersection(rightTokens).length;
    final int union = leftTokens.union(rightTokens).length;
    final double tokenScore = union == 0 ? 0 : intersection / union;
    final double editScore = _levenshteinSimilarity(
      normalizedLeft,
      normalizedRight,
    );
    return tokenScore > editScore ? tokenScore : editScore;
  }

  _MatchDecision? _findDecision(
    BankTransactionEntity transaction,
    List<DocumentEntity> documents,
    Set<String> usedDocumentIds,
  ) {
    final Iterable<DocumentEntity> available = documents.where(
      (DocumentEntity document) => !usedDocumentIds.contains(document.id),
    );

    for (final DocumentEntity document in available) {
      if (_hasExactVoen(transaction, document) &&
          _hasExactAmount(transaction, document)) {
        return _MatchDecision(document: document, confidence: 1.0);
      }
    }

    for (final DocumentEntity document in available) {
      final DateTime? documentDate = document.issueDate ?? document.createdAt;
      if (_hasExactAmount(transaction, document) &&
          documentDate != null &&
          transaction.transactionDate
                  .difference(documentDate)
                  .abs() <=
              dateWindow &&
          nameSimilarity(transaction.counterpartyName, document.vendorName) >=
              fuzzyNameThreshold) {
        return _MatchDecision(document: document, confidence: 0.85);
      }
    }

    for (final DocumentEntity document in available) {
      if (_hasExactAmount(transaction, document) &&
          _hasReference(transaction, document)) {
        return _MatchDecision(document: document, confidence: 0.60);
      }
    }
    return null;
  }

  bool _isMatchableDocument(DocumentEntity document) {
    // Completed is the normal approved OCR state. Pending is accepted when a
    // caller supplies a pending invoice that already has reliable structured
    // fields, which keeps the engine useful during staged approval workflows.
    return document.status == DocumentStatus.completed ||
        document.status == DocumentStatus.pending;
  }

  bool _hasExactVoen(
    BankTransactionEntity transaction,
    DocumentEntity document,
  ) {
    final String transactionVoen = _normalizeVoen(transaction.counterpartyVoen);
    final String documentVoen = _normalizeVoen(document.vendorVoen);
    return transactionVoen.isNotEmpty &&
        documentVoen.isNotEmpty &&
        transactionVoen == documentVoen;
  }

  bool _hasExactAmount(
    BankTransactionEntity transaction,
    DocumentEntity document,
  ) {
    final double? documentAmount = document.totalAmount;
    if (documentAmount == null || !documentAmount.isFinite) {
      return false;
    }
    return (transaction.amount - documentAmount.abs()).abs() <=
        amountTolerance;
  }

  bool _hasReference(
    BankTransactionEntity transaction,
    DocumentEntity document,
  ) {
    final String transactionReference = _normalizeText(
      '${transaction.referenceCode ?? ''} ${transaction.description}',
    );
    if (transactionReference.isEmpty) {
      return false;
    }

    final List<String> references = <String>[
      document.id,
      document.invoiceNumber ?? '',
      document.fileName,
    ].map(_normalizeText).where((String value) => value.isNotEmpty).toList();
    return references.any(transactionReference.contains);
  }

  static String _normalizeVoen(String? value) {
    return (value ?? '').replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toLowerCase();
  }

  static String _normalizeText(String? value) {
    String normalized = (value ?? '').trim().toLowerCase();
    const Map<String, String> replacements = <String, String>{
      'ə': 'e',
      'ı': 'i',
      'ö': 'o',
      'ü': 'u',
      'ş': 's',
      'ç': 'c',
      'ğ': 'g',
    };
    replacements.forEach((String from, String to) {
      normalized = normalized.replaceAll(from, to);
    });
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static double _levenshteinSimilarity(String left, String right) {
    if (left == right) {
      return 1;
    }
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }

    final List<int> previous = List<int>.generate(
      right.length + 1,
      (int index) => index,
    );
    for (int leftIndex = 1; leftIndex <= left.length; leftIndex++) {
      final List<int> current = List<int>.filled(right.length + 1, 0);
      current[0] = leftIndex;
      for (int rightIndex = 1; rightIndex <= right.length; rightIndex++) {
        final int substitutionCost =
            left.codeUnitAt(leftIndex - 1) == right.codeUnitAt(rightIndex - 1)
                ? 0
                : 1;
        current[rightIndex] = <int>[
          current[rightIndex - 1] + 1,
          previous[rightIndex] + 1,
          previous[rightIndex - 1] + substitutionCost,
        ].reduce((int minimum, int value) =>
            value < minimum ? value : minimum);
      }
      previous.setAll(0, current);
    }
    final int distance = previous.last;
    final int longest = left.length > right.length ? left.length : right.length;
    return 1 - (distance / longest);
  }
}

class _MatchDecision {
  const _MatchDecision({
    required this.document,
    required this.confidence,
  });

  final DocumentEntity document;
  final double confidence;
}
