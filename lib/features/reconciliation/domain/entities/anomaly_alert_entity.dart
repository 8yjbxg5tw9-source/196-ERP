import 'package:equatable/equatable.dart';

/// Severity tier shown on the fraud & anomaly inspector.
enum AnomalySeverity { red, yellow }

extension AnomalySeverityLabel on AnomalySeverity {
  String get label => switch (this) {
        AnomalySeverity.red => 'High Fraud Risk',
        AnomalySeverity.yellow => 'Unusual Variance',
      };
}

/// The heuristic that produced an alert.
enum AnomalyKind { duplicatePayment, unverifiedVoen, statisticalOutlier, offHours }

extension AnomalyKindLabel on AnomalyKind {
  String get label => switch (this) {
        AnomalyKind.duplicatePayment => 'Duplicate payment',
        AnomalyKind.unverifiedVoen => 'Unverified VÖEN',
        AnomalyKind.statisticalOutlier => 'Statistical outlier',
        AnomalyKind.offHours => 'Off-hours transaction',
      };
}

/// A flagged transaction or invoice produced by the anomaly detection engine.
class AnomalyAlertEntity extends Equatable {
  const AnomalyAlertEntity({
    required this.id,
    required this.companyId,
    required this.kind,
    required this.severity,
    required this.title,
    required this.description,
    this.transactionId,
    this.documentId,
    this.amount,
    this.detectedAt,
  });

  final String id;
  final String companyId;
  final AnomalyKind kind;
  final AnomalySeverity severity;
  final String title;
  final String description;

  /// The flagged ledger line, when the alert came from a bank transaction.
  final String? transactionId;

  /// The flagged invoice, when the alert came from an OCR document.
  final String? documentId;

  final double? amount;
  final DateTime? detectedAt;

  @override
  List<Object?> get props => <Object?>[
        id,
        companyId,
        kind,
        severity,
        title,
        description,
        transactionId,
        documentId,
        amount,
        detectedAt,
      ];
}
