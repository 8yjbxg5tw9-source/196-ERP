import 'package:equatable/equatable.dart';

/// Severity of a statutory field or schema discrepancy.
enum XmlValidationSeverity { info, warning, error }

extension XmlValidationSeverityLabel on XmlValidationSeverity {
  String get label => switch (this) {
        XmlValidationSeverity.info => 'Info',
        XmlValidationSeverity.warning => 'Warning',
        XmlValidationSeverity.error => 'Error',
      };
}

/// A single discrepancy found while validating a tax declaration or its XML.
class XmlValidationIssue extends Equatable {
  const XmlValidationIssue({
    required this.field,
    required this.message,
    this.severity = XmlValidationSeverity.error,
  });

  final String field;
  final String message;
  final XmlValidationSeverity severity;

  bool get isError => severity == XmlValidationSeverity.error;
  bool get isWarning => severity == XmlValidationSeverity.warning;
  bool get isInfo => severity == XmlValidationSeverity.info;

  @override
  List<Object?> get props => <Object?>[field, message, severity];
}
