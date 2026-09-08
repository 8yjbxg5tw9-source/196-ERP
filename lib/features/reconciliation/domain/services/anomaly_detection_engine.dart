import 'dart:math' as math;

import '../../../document_ocr/domain/entities/document_entity.dart';
import '../entities/anomaly_alert_entity.dart';
import '../entities/bank_transaction_entity.dart';

/// Deterministic financial fraud and variance scanner.
///
/// The engine applies four independent heuristics to a company's bank lines
/// and invoices: duplicate payments within a rolling window, payments to
/// counterparties with missing/invalid VÖEN numbers, per-category statistical
/// outliers (> 3σ above the 90-day mean), and large debits outside banking
/// business hours.
class AnomalyDetectionEngine {
  const AnomalyDetectionEngine({
    this.duplicateWindow = const Duration(days: 7),
    this.outlierLookbackDays = 90,
    this.outlierSigma = 3.0,
    this.largeDebitThreshold = 10000,
    this.businessStartHour = 9,
    this.businessEndHour = 18,
  });

  final Duration duplicateWindow;
  final int outlierLookbackDays;
  final double outlierSigma;
  final double largeDebitThreshold;
  final int businessStartHour;
  final int businessEndHour;

  /// Scans [transactions] and [documents] and returns all detected alerts.
  ///
  /// [categoriesByTransactionId] maps transaction id → expense category for
  /// the statistical-outlier heuristic (defaults to a single shared bucket).
  List<AnomalyAlertEntity> scan({
    required String companyId,
    required List<BankTransactionEntity> transactions,
    required List<DocumentEntity> documents,
    Map<String, String> categoriesByTransactionId = const <String, String>{},
  }) {
    final DateTime now = DateTime.now().toUtc();
    final List<AnomalyAlertEntity> alerts = <AnomalyAlertEntity>[
      ..._duplicatePayments(companyId, transactions, now),
      ..._unverifiedVoen(companyId, transactions, documents, now),
      ..._statisticalOutliers(
        companyId,
        transactions,
        categoriesByTransactionId,
        now,
      ),
      ..._offHours(companyId, transactions, now),
    ];
    return alerts;
  }

  List<AnomalyAlertEntity> _duplicatePayments(
    String companyId,
    List<BankTransactionEntity> transactions,
    DateTime now,
  ) {
    final List<BankTransactionEntity> debits = transactions
        .where(
          (BankTransactionEntity t) =>
              t.type == BankTransactionType.debit && t.amount > 0,
        )
        .toList(growable: false)
      ..sort(
        (BankTransactionEntity left, BankTransactionEntity right) =>
            left.transactionDate.compareTo(right.transactionDate),
      );

    final List<AnomalyAlertEntity> alerts = <AnomalyAlertEntity>[];
    final Set<String> flagged = <String>{};
    for (int i = 0; i < debits.length; i++) {
      final BankTransactionEntity current = debits[i];
      final String voen = _normalizeVoen(current.counterpartyVoen);
      if (voen.isEmpty || flagged.contains(current.id)) {
        continue;
      }
      for (int j = i + 1; j < debits.length; j++) {
        final BankTransactionEntity other = debits[j];
        final Duration delta =
            other.transactionDate.difference(current.transactionDate);
        if (delta > duplicateWindow) {
          break;
        }
        if (delta.isNegative ||
            flagged.contains(other.id) ||
            _normalizeVoen(other.counterpartyVoen) != voen ||
            (other.amount - current.amount).abs() > 0.01) {
          continue;
        }
        flagged.add(other.id);
        alerts.add(
          AnomalyAlertEntity(
            id: 'dup-${other.id}',
            companyId: companyId,
            kind: AnomalyKind.duplicatePayment,
            severity: AnomalySeverity.red,
            title: 'Possible duplicate payment',
            description: 'Payment of ${_money(other.amount)} to VÖEN '
                '${other.counterpartyVoen ?? '—'} repeats an earlier payment '
                'made within 7 days.',
            transactionId: other.id,
            amount: other.amount,
            detectedAt: now,
          ),
        );
        break;
      }
    }
    return alerts;
  }

  List<AnomalyAlertEntity> _unverifiedVoen(
    String companyId,
    List<BankTransactionEntity> transactions,
    List<DocumentEntity> documents,
    DateTime now,
  ) {
    final List<AnomalyAlertEntity> alerts = <AnomalyAlertEntity>[];
    for (final BankTransactionEntity transaction in transactions) {
      if (transaction.type != BankTransactionType.debit) {
        continue;
      }
      final String voen = _normalizeVoen(transaction.counterpartyVoen);
      if (voen.isEmpty) {
        alerts.add(
          AnomalyAlertEntity(
            id: 'voen-${transaction.id}',
            companyId: companyId,
            kind: AnomalyKind.unverifiedVoen,
            severity: AnomalySeverity.red,
            title: 'Unverified counterparty VÖEN',
            description: 'Debit of ${_money(transaction.amount)} to '
                '${transaction.counterpartyName ?? 'unknown'} has no tax '
                'registration number on record.',
            transactionId: transaction.id,
            amount: transaction.amount,
            detectedAt: now,
          ),
        );
      } else if (voen.length < 8) {
        alerts.add(
          AnomalyAlertEntity(
            id: 'voen-invalid-${transaction.id}',
            companyId: companyId,
            kind: AnomalyKind.unverifiedVoen,
            severity: AnomalySeverity.red,
            title: 'Invalid counterparty VÖEN',
            description: 'Debit of ${_money(transaction.amount)} references '
                'VÖEN "${transaction.counterpartyVoen}", which does not match '
                'the standard 10-digit format.',
            transactionId: transaction.id,
            amount: transaction.amount,
            detectedAt: now,
          ),
        );
      }
    }

    for (final DocumentEntity document in documents) {
      if (document.status != DocumentStatus.completed) {
        continue;
      }
      if (_normalizeVoen(document.vendorVoen).isEmpty) {
        alerts.add(
          AnomalyAlertEntity(
            id: 'voen-doc-${document.id}',
            companyId: companyId,
            kind: AnomalyKind.unverifiedVoen,
            severity: AnomalySeverity.yellow,
            title: 'Invoice without vendor VÖEN',
            description: 'Approved invoice ${document.invoiceNumber ?? document.fileName} '
                'has no vendor tax registration number.',
            documentId: document.id,
            amount: document.totalAmount,
            detectedAt: now,
          ),
        );
      }
    }
    return alerts;
  }

  List<AnomalyAlertEntity> _statisticalOutliers(
    String companyId,
    List<BankTransactionEntity> transactions,
    Map<String, String> categoriesByTransactionId,
    DateTime now,
  ) {
    final DateTime cutoff = now.subtract(Duration(days: outlierLookbackDays));
    final Map<String, List<double>> amountsByCategory = <String, List<double>>{};
    final Map<String, List<BankTransactionEntity>> txByCategory =
        <String, List<BankTransactionEntity>>{};

    for (final BankTransactionEntity transaction in transactions) {
      if (transaction.type != BankTransactionType.debit ||
          transaction.amount <= 0 ||
          transaction.transactionDate.isBefore(cutoff)) {
        continue;
      }
      final String category =
          categoriesByTransactionId[transaction.id] ?? 'expense';
      amountsByCategory.putIfAbsent(category, () => <double>[]).add(
            transaction.amount,
          );
      txByCategory.putIfAbsent(category, () => <BankTransactionEntity>[]).add(
            transaction,
          );
    }

    final List<AnomalyAlertEntity> alerts = <AnomalyAlertEntity>[];
    for (final MapEntry<String, List<double>> entry
        in amountsByCategory.entries) {
      final List<double> amounts = entry.value;
      if (amounts.length < 2) {
        continue;
      }
      final double mean =
          amounts.reduce((double a, double b) => a + b) / amounts.length;
      final double variance =
          amounts.fold<double>(0, (double sum, double value) {
            return sum + math.pow(value - mean, 2).toDouble();
          }) /
              (amounts.length - 1);
      final double std = math.sqrt(variance);
      if (std <= 0) {
        continue;
      }
      final double threshold = mean + outlierSigma * std;
      for (final BankTransactionEntity transaction
          in txByCategory[entry.key] ?? const <BankTransactionEntity>[]) {
        if (transaction.amount > threshold) {
          alerts.add(
            AnomalyAlertEntity(
              id: 'outlier-${transaction.id}',
              companyId: companyId,
              kind: AnomalyKind.statisticalOutlier,
              severity: AnomalySeverity.yellow,
              title: 'Unusual transaction amount',
              description: 'Debit of ${_money(transaction.amount)} exceeds the '
                  '${outlierLookbackDays}-day mean of ${_money(mean)} for '
                  '"${entry.key}" by more than ${outlierSigma.toStringAsFixed(1)}σ.',
              transactionId: transaction.id,
              amount: transaction.amount,
              detectedAt: now,
            ),
          );
        }
      }
    }
    return alerts;
  }

  List<AnomalyAlertEntity> _offHours(
    String companyId,
    List<BankTransactionEntity> transactions,
    DateTime now,
  ) {
    final List<AnomalyAlertEntity> alerts = <AnomalyAlertEntity>[];
    for (final BankTransactionEntity transaction in transactions) {
      if (transaction.type != BankTransactionType.debit ||
          transaction.amount < largeDebitThreshold) {
        continue;
      }
      final DateTime local = transaction.transactionDate.toLocal();
      final bool weekend = local.weekday == DateTime.saturday ||
          local.weekday == DateTime.sunday;
      final bool outsideHours = local.hour < businessStartHour ||
          local.hour >= businessEndHour;
      if (!weekend && !outsideHours) {
        continue;
      }
      final String when =
          weekend ? 'a weekend' : 'outside banking hours';
      alerts.add(
        AnomalyAlertEntity(
          id: 'hours-${transaction.id}',
          companyId: companyId,
          kind: AnomalyKind.offHours,
          severity: AnomalySeverity.yellow,
          title: 'Large off-hours debit',
          description: 'Debit of ${_money(transaction.amount)} to '
              '${transaction.counterpartyName ?? 'unknown'} was executed on '
              '$when.',
          transactionId: transaction.id,
          amount: transaction.amount,
          detectedAt: now,
        ),
      );
    }
    return alerts;
  }

  static String _money(double value) =>
      'AZN ${value.toStringAsFixed(2)}';

  static String _normalizeVoen(String? value) {
    return (value ?? '').replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toLowerCase();
  }
}
